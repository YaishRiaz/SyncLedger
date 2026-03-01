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

  StockPriceData({
    required this.symbol,
    required this.priceDate,
    required this.closePrice,
    this.change,
    this.changePercent,
    this.companyName,
  });
}

/// Service to fetch stock prices from CSE (Colombo Stock Exchange) API
///
/// Uses the official CSE API: https://www.cse.lk/api/companyInfoSummery
///
/// Trading hours: Mon-Fri, 10:30am-2:30pm Colombo time
/// Fetch prices after 2:30pm (3pm recommended) for EOD data
///
/// Symbol format: TICKER.N0000 (e.g., HHL.N0000, LOLC.N0000)
/// - .N0000: Ordinary shares
/// - .X0000 or .Y0000: Preferential shares
class CseScraperService {
  static const String CSE_API_BASE = 'https://www.cse.lk/api';
  static const String CSE_API_ENDPOINT = 'companyInfoSummery';
  static const Duration TIMEOUT = Duration(seconds: 10);

  // CSE symbol suffix for ordinary shares
  static const String SYMBOL_SUFFIX = '.N0000';

  /// Fetch stock prices from CSE API for given symbols
  ///
  /// [symbols] List of stock symbols without suffix (e.g., ['HHL', 'LOLC'])
  /// Returns list of StockPriceData or empty list if fetch fails
  ///
  /// Example:
  /// ```
  /// final prices = await service.fetchStockPrices(['HHL', 'LOLC']);
  /// ```
  Future<List<StockPriceData>> fetchStockPrices(List<String> symbols) async {
    if (symbols.isEmpty) {
      return [];
    }

    final prices = <StockPriceData>[];

    for (final symbol in symbols) {
      try {
        final data = await _fetchSingleStockPrice(symbol);
        if (data != null) {
          prices.add(data);
        }
      } catch (e) {
        AppLogger.w('CseScraperService: Failed to fetch $symbol: $e');
        // Continue with next symbol
      }
    }

    return prices;
  }

  /// Fetch price for a single stock from CSE API
  Future<StockPriceData?> _fetchSingleStockPrice(String symbol) async {
    try {
      AppLogger.d('CseScraperService: Fetching price for $symbol');

      final cseSymbol = '$symbol$SYMBOL_SUFFIX';
      final url = Uri.parse('$CSE_API_BASE/$CSE_API_ENDPOINT');

      final response = await http
          .post(
            url,
            body: {'symbol': cseSymbol},
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          )
          .timeout(TIMEOUT);

      if (response.statusCode != 200) {
        AppLogger.w(
          'CseScraperService: API returned status ${response.statusCode} for $symbol',
        );
        return null;
      }

      return _parseApiResponse(symbol, response.body);
    } catch (e) {
      AppLogger.e('CseScraperService: Error fetching $symbol: $e');
      return null;
    }
  }

  /// Parse JSON response from CSE API
  ///
  /// Expected response format:
  /// ```json
  /// {
  ///   "reqSymbolInfo": {
  ///     "name": "Company Name",
  ///     "lastTradedPrice": 100.50,
  ///     "change": 2.50,
  ///     "changePercentage": 2.55,
  ///     "marketCap": 1000000000
  ///   }
  /// }
  /// ```
  StockPriceData? _parseApiResponse(String symbol, String jsonBody) {
    try {
      final json = jsonDecode(jsonBody) as Map<String, dynamic>;
      final reqInfo = json['reqSymbolInfo'] as Map<String, dynamic>?;

      if (reqInfo == null) {
        AppLogger.w('CseScraperService: No reqSymbolInfo in response for $symbol');
        return null;
      }

      final lastPrice = parseDouble(reqInfo['lastTradedPrice']?.toString());
      if (lastPrice == null) {
        AppLogger.w('CseScraperService: Could not parse lastTradedPrice for $symbol');
        return null;
      }

      final change = parseDouble(reqInfo['change']?.toString());
      final changePercent = parseDouble(reqInfo['changePercentage']?.toString());
      final companyName = reqInfo['name'] as String?;

      return StockPriceData(
        symbol: symbol,
        priceDate: dateToYyyymmdd(DateTime.now()),
        closePrice: lastPrice,
        change: change,
        changePercent: changePercent,
        companyName: companyName,
      );
    } catch (e) {
      AppLogger.e('CseScraperService: Error parsing response for $symbol: $e');
      return null;
    }
  }

  /// Helper: Convert date to YYYYMMDD format
  static int dateToYyyymmdd(DateTime date) {
    return int.parse(
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
    );
  }

  /// Helper: Convert YYYYMMDD format to DateTime
  static DateTime yyyymmddToDate(int dateValue) {
    final dateStr = dateValue.toString();
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
  }

  /// Helper: Parse double safely
  static double? parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    // Remove common currency symbols and formatting
    final cleaned = value
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned);
  }

  /// Helper: Parse int safely
  static int? parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '').trim();
    return int.tryParse(cleaned);
  }
}
