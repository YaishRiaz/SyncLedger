import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/logger.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';

/// Manages bulk historical stock price data:
///
/// - **One-time CSV seed**: imports the bundled `assets/data/cse_history_seed.csv`
///   into [StockPrices] on first run (checked via SharedPreferences).
/// - **API history fetch**: calls CSE `companyChartDataByStock` (period=5, ~1 year)
///   to keep per-symbol history up-to-date, storing the last [kMaxHistoryDays].
/// - **Storage management**: prunes rows older than [kMaxHistoryDays] after each
///   update so the database stays lean.
class StockHistoryService {
  final AppDatabase db;

  /// Number of calendar days of price history to retain in the database.
  static const int kMaxHistoryDays = 90;

  static const String _seedKey = 'stock_history_seed_v1';
  static const String _apiBase = 'https://www.cse.lk/api';
  static const Duration _timeout = Duration(seconds: 15);

  StockHistoryService({required this.db});

  // ---------------------------------------------------------------------------
  // CSV Seed Import (one-time, fast on subsequent launches)
  // ---------------------------------------------------------------------------

  /// Import the bundled CSV asset into [StockPrices] if it has not already
  /// been done on this device. Safe to call on every app start.
  Future<void> importSeedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seedKey) == true) return;

    try {
      AppLogger.d('StockHistoryService: importing CSV seed...');
      final csv = await rootBundle.loadString('assets/data/cse_history_seed.csv');
      final imported = await _importCsvString(csv);
      await prefs.setBool(_seedKey, true);
      AppLogger.d('StockHistoryService: seed import done – $imported rows');
    } catch (e) {
      // Non-fatal: the API fetch path will backfill the data.
      AppLogger.w('StockHistoryService: seed import failed – $e');
    }
  }

  Future<int> _importCsvString(String csv) async {
    final cutoff = DateTime.now().subtract(const Duration(days: kMaxHistoryDays));
    final cutoffInt = CseScraperService.dateToYyyymmdd(cutoff);

    final rows = <Map<String, dynamic>>[];
    final lines = const LineSplitter().convert(csv);

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final p = line.split(',');
      if (p.length < 6) continue;

      final symbol = p[0].trim();
      final dateStr = p[1].trim(); // YYYY-MM-DD
      final open = double.tryParse(p[2].trim());
      final high = double.tryParse(p[3].trim());
      final low = double.tryParse(p[4].trim());
      final close = double.tryParse(p[5].trim());
      final volume = p.length > 6 ? int.tryParse(p[6].trim()) : null;

      if (symbol.isEmpty || close == null) continue;

      final dp = dateStr.split('-');
      if (dp.length != 3) continue;
      final priceDate = int.tryParse('${dp[0]}${dp[1]}${dp[2]}');
      if (priceDate == null || priceDate < cutoffInt) continue;

      rows.add({
        'symbol': symbol,
        'priceDate': priceDate,
        'closePrice': close,
        'openPrice': open,
        'highPrice': high,
        'lowPrice': low,
        'volume': volume,
      });
    }

    if (rows.isNotEmpty) await db.batchInsertStockPrices(rows);
    return rows.length;
  }

  // ---------------------------------------------------------------------------
  // API History Fetch (called after each daily price refresh)
  // ---------------------------------------------------------------------------

  /// Fetch ~1 year of OHLCV history from the CSE chart API for [bareSymbol],
  /// store rows from the last [kMaxHistoryDays] days, and replace any
  /// stale data via InsertOrReplace.
  ///
  /// [symbolSuffix] – single letter from StockInfo (e.g. "N", "X", "Y").
  /// Defaults to "N" when null.
  Future<void> fetchAndStoreHistory(
    String bareSymbol,
    String? symbolSuffix,
  ) async {
    try {
      final suffix = symbolSuffix ?? 'N';
      final fullSymbol = '$bareSymbol.${suffix}0000';

      final stockId = await _resolveStockId(fullSymbol);
      if (stockId == null) {
        AppLogger.w('StockHistoryService: could not resolve id for $bareSymbol');
        return;
      }

      final rows = await _fetchChartRows(bareSymbol, stockId);
      if (rows.isEmpty) {
        AppLogger.w('StockHistoryService: no chart data for $bareSymbol');
        return;
      }

      await db.batchInsertStockPrices(rows);
      AppLogger.d(
          'StockHistoryService: stored ${rows.length} rows for $bareSymbol');
    } catch (e) {
      AppLogger.e('StockHistoryService: error fetching history for $bareSymbol – $e');
    }
  }

  Future<int?> _resolveStockId(String fullSymbol) async {
    final url = Uri.parse('$_apiBase/companyInfoSummery');
    final res = await http
        .post(url,
            body: {'symbol': fullSymbol},
            headers: {'Content-Type': 'application/x-www-form-urlencoded'})
        .timeout(_timeout);

    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final info = json['reqSymbolInfo'] as Map<String, dynamic>?;
    final idVal = info?['id'];
    if (idVal == null) return null;
    return idVal is int ? idVal : int.tryParse(idVal.toString());
  }

  Future<List<Map<String, dynamic>>> _fetchChartRows(
    String bareSymbol,
    int stockId,
  ) async {
    final cutoff = DateTime.now().subtract(const Duration(days: kMaxHistoryDays));
    final cutoffInt = CseScraperService.dateToYyyymmdd(cutoff);

    final url = Uri.parse('$_apiBase/companyChartDataByStock');
    final res = await http
        .post(url,
            body: {'stockId': stockId.toString(), 'period': '5'},
            headers: {'Content-Type': 'application/x-www-form-urlencoded'})
        .timeout(_timeout);

    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final chartData = json['chartData'] as List<dynamic>?;
    if (chartData == null || chartData.isEmpty) return [];

    final rows = <Map<String, dynamic>>[];
    for (final bar in chartData) {
      try {
        final t = bar['t'] as int;
        final barDate = DateTime.fromMillisecondsSinceEpoch(t);
        final priceDate = CseScraperService.dateToYyyymmdd(barDate);
        if (priceDate < cutoffInt) continue;

        final close = _num(bar['p']);
        if (close == null) continue;

        rows.add({
          'symbol': bareSymbol,
          'priceDate': priceDate,
          'closePrice': close,
          'openPrice': _num(bar['o']),
          'highPrice': _num(bar['h']),
          'lowPrice': _num(bar['l']),
          'volume': bar['q'] is int
              ? bar['q'] as int
              : int.tryParse(bar['q'].toString()),
        });
      } catch (_) {}
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // Storage management
  // ---------------------------------------------------------------------------

  /// Delete all [StockPrice] rows older than [kMaxHistoryDays] calendar days.
  Future<void> pruneOldPrices() async {
    await db.pruneOldStockPrices(kMaxHistoryDays);
    AppLogger.d(
        'StockHistoryService: pruned prices older than $kMaxHistoryDays days');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
