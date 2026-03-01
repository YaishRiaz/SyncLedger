import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sync_ledger/core/logger.dart';

class StockPriceData {
  final String symbol;
  final int priceDate; // YYYYMMDD format
  final double closePrice;
  final double? change;
  final double? changePercent;
  final String? companyName;
  final String? logoPath;     // e.g., "upload_logo/378_1601611239.jpeg"
  final String? symbolSuffix; // e.g., "N", "X", "Y"

  StockPriceData({
    required this.symbol,
    required this.priceDate,
    required this.closePrice,
    this.change,
    this.changePercent,
    this.companyName,
    this.logoPath,
    this.symbolSuffix,
  });
}

/// Service to fetch stock prices from CSE (Colombo Stock Exchange) API
///
/// Uses: https://www.cse.lk/api/companyInfoSummery
///       https://www.cse.lk/api/todaySharePrice  (for symbol discovery)
///
/// Trading hours: Mon-Fri, 10:30am-2:30pm Colombo time
/// Fetch prices after 2:30pm (3pm recommended) for EOD data
///
/// Symbol format: TICKER.N0000 (ordinary) | .X0000 / .Y0000 (preference)
class CseScraperService {
  static const String CSE_API_BASE = 'https://www.cse.lk/api';
  static const String CSE_API_ENDPOINT = 'companyInfoSummery';
  static const Duration TIMEOUT = Duration(seconds: 15);

  // Fallback suffix when the symbol isn't found in todaySharePrice
  static const String SYMBOL_SUFFIX = '.N0000';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetch stock prices for the given bare symbols (e.g., ['HHL', 'LOLC']).
  ///
  /// First queries `todaySharePrice` to get the correct full symbol for each
  /// ticker (e.g., HHL → HHL.N0000, TKYO → TKYO.X0000). Falls back to
  /// [SYMBOL_SUFFIX] when a symbol is not found in the live list.
  Future<List<StockPriceData>> fetchStockPrices(List<String> symbols) async {
    if (symbols.isEmpty) return [];

    // Resolve bare tickers → full CSE symbols (e.g., "HHL" → "HHL.N0000")
    final symbolMap = await _fetchSymbolMap();

    final prices = <StockPriceData>[];
    for (final symbol in symbols) {
      try {
        final fullSymbol = symbolMap[symbol] ?? '$symbol$SYMBOL_SUFFIX';
        final data = await _fetchSingleStockPrice(symbol, fullSymbol);
        if (data != null) prices.add(data);
      } catch (e) {
        AppLogger.w('CseScraperService: Failed to fetch $symbol: $e');
      }
    }
    return prices;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetch all listed stocks from `todaySharePrice` and return a map of
  /// bare ticker → full CSE symbol, e.g. {"HHL" → "HHL.N0000"}.
  Future<Map<String, String>> _fetchSymbolMap() async {
    try {
      final url = Uri.parse('$CSE_API_BASE/todaySharePrice');
      final response = await http
          .post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'})
          .timeout(TIMEOUT);

      if (response.statusCode != 200) {
        AppLogger.w('CseScraperService: todaySharePrice returned ${response.statusCode}');
        return {};
      }

      final data = jsonDecode(response.body);
      if (data is! List) return {};

      final map = <String, String>{};
      for (final item in data) {
        final full = item['symbol'] as String?;
        if (full != null && full.contains('.')) {
          final bare = full.split('.').first;
          map[bare] = full;
        }
      }

      AppLogger.d('CseScraperService: Loaded ${map.length} symbols from todaySharePrice');
      return map;
    } catch (e) {
      AppLogger.w('CseScraperService: Failed to fetch symbol map: $e');
      return {};
    }
  }

  /// Fetch price + company info for a single stock from `companyInfoSummery`.
  ///
  /// [bareSymbol] — stored ticker (e.g., "HHL")
  /// [fullSymbol] — the CSE full symbol to POST (e.g., "HHL.N0000")
  Future<StockPriceData?> _fetchSingleStockPrice(
    String bareSymbol,
    String fullSymbol,
  ) async {
    try {
      AppLogger.d('CseScraperService: Fetching $bareSymbol as $fullSymbol');

      final url = Uri.parse('$CSE_API_BASE/$CSE_API_ENDPOINT');
      final response = await http
          .post(
            url,
            body: {'symbol': fullSymbol},
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          )
          .timeout(TIMEOUT);

      if (response.statusCode != 200) {
        AppLogger.w(
          'CseScraperService: HTTP ${response.statusCode} for $bareSymbol ($fullSymbol)',
        );
        return null;
      }

      return _parseApiResponse(bareSymbol, fullSymbol, response.body);
    } catch (e) {
      AppLogger.e('CseScraperService: Error fetching $bareSymbol: $e');
      return null;
    }
  }

  /// Parse the JSON body from `companyInfoSummery`.
  StockPriceData? _parseApiResponse(
    String bareSymbol,
    String fullSymbol,
    String jsonBody,
  ) {
    try {
      final json = jsonDecode(jsonBody) as Map<String, dynamic>;
      final reqInfo = json['reqSymbolInfo'] as Map<String, dynamic>?;

      if (reqInfo == null) {
        AppLogger.w('CseScraperService: No reqSymbolInfo for $bareSymbol');
        return null;
      }

      final lastPrice = parseDouble(reqInfo['lastTradedPrice']?.toString());
      if (lastPrice == null || lastPrice == 0) {
        AppLogger.w(
          'CseScraperService: No lastTradedPrice for $bareSymbol ($fullSymbol)',
        );
        return null;
      }

      final change = parseDouble(reqInfo['change']?.toString());
      final changePercent = parseDouble(reqInfo['changePercentage']?.toString());
      final companyName = (reqInfo['name'] as String?)?.trim();

      // Logo path: "upload_logo/378_1601611239.jpeg"
      final reqLogo = json['reqLogo'] as Map<String, dynamic>?;
      final rawLogoPath = (reqLogo?['path'] as String?)?.trim();
      final logoPath = (rawLogoPath?.isNotEmpty == true) ? rawLogoPath : null;

      AppLogger.d(
        'CseScraperService: $bareSymbol → price=$lastPrice '
        'logo=${logoPath ?? "none"} company=${companyName ?? "unknown"}',
      );

      // Extract suffix letter from fullSymbol: "HHL.N0000" → "N", "TKYO.X0000" → "X"
      String? symbolSuffix;
      if (fullSymbol.contains('.')) {
        final suffixPart = fullSymbol.split('.').last;
        if (suffixPart.isNotEmpty) symbolSuffix = suffixPart[0];
      }

      return StockPriceData(
        symbol: bareSymbol,
        priceDate: dateToYyyymmdd(DateTime.now()),
        closePrice: lastPrice,
        change: change,
        changePercent: changePercent,
        companyName: companyName,
        logoPath: logoPath,
        symbolSuffix: symbolSuffix,
      );
    } catch (e) {
      AppLogger.e('CseScraperService: Error parsing response for $bareSymbol: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Static utilities
  // ---------------------------------------------------------------------------

  static int dateToYyyymmdd(DateTime date) {
    return int.parse(
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
    );
  }

  static DateTime yyyymmddToDate(int dateValue) {
    final dateStr = dateValue.toString();
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
  }

  static double? parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return double.tryParse(cleaned);
  }

  static int? parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '').trim();
    return int.tryParse(cleaned);
  }
}
