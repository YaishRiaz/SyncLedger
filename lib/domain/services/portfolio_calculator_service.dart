import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';
import 'package:sync_ledger/core/logger.dart';

/// Service to calculate and track portfolio value
/// Updates daily with latest stock prices from CSE
class PortfolioCalculatorService {
  final AppDatabase db;
  final CseScraperService cseService;

  PortfolioCalculatorService({
    required this.db,
    required this.cseService,
  });

  /// Calculate portfolio value for a profile based on current holdings
  ///
  /// Returns the total portfolio value in LKR, or null if calculation fails
  /// Logic:
  /// 1. Get all positions for profile where qty > 0
  /// 2. For each position, get latest stock price
  /// 3. Calculate value = qty × closePrice
  /// 4. Sum all values
  /// 5. Calculate day-over-day change
  /// 6. Store in PortfolioValue table
  Future<double?> calculateAndStorePortfolioValue(String profileId) async {
    try {
      AppLogger.d('PortfolioCalculator: Calculating portfolio for $profileId');

      // Get all current positions
      final positions = await db.getPositionsForProfile(profileId);

      if (positions.isEmpty) {
        AppLogger.d('PortfolioCalculator: No positions found for $profileId');
        return 0.0;
      }

      double totalValue = 0.0;

      // Calculate value for each position
      for (final position in positions) {
        final latestPrice = await db.getLatestStockPrice(position.symbol);

        if (latestPrice == null) {
          AppLogger.w(
            'PortfolioCalculator: No price found for ${position.symbol}',
          );
          continue;
        }

        final positionValue = position.qty * latestPrice.closePrice;
        totalValue += positionValue;

        AppLogger.d(
          'PortfolioCalculator: ${position.symbol} - '
          'qty=${position.qty} price=${latestPrice.closePrice} value=$positionValue',
        );
      }

      // Get yesterday's portfolio value to calculate change
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      final todayYyyymmdd = CseScraperService.dateToYyyymmdd(today);

      final yesterdayValue = await db.getPortfolioValueHistory(profileId, 1);
      final previousValue = yesterdayValue.isNotEmpty ? yesterdayValue.first : null;

      double? dayChangeAmount;
      double? dayChangePercent;

      if (previousValue != null && previousValue.totalValue > 0) {
        dayChangeAmount = totalValue - previousValue.totalValue;
        dayChangePercent = (dayChangeAmount / previousValue.totalValue) * 100;
      }

      // Store in database
      await db.insertPortfolioValue(
        profileId: profileId,
        valueDate: todayYyyymmdd,
        totalValue: totalValue,
        dayChangeAmount: dayChangeAmount,
        dayChangePercent: dayChangePercent,
      );

      AppLogger.d(
        'PortfolioCalculator: Portfolio value calculated - '
        'total=$totalValue change=$dayChangeAmount ${dayChangePercent?.toStringAsFixed(2)}%',
      );

      return totalValue;
    } catch (e) {
      AppLogger.e('PortfolioCalculator: Error calculating portfolio: $e');
      return null;
    }
  }

  /// Update stock prices from CSE and recalculate portfolio
  ///
  /// This is called daily at market close (4:30 PM)
  /// Process:
  /// 1. Get all unique stock symbols from current holdings
  /// 2. Fetch prices from CSE API for those symbols
  /// 3. Store in StockPrices table
  /// 4. Recalculate portfolio value for each profile
  Future<void> updatePricesAndRecalculatePortfolio(
    List<String> profileIds,
  ) async {
    try {
      AppLogger.d('PortfolioCalculator: Updating prices and recalculating');

      // Collect all unique symbols from all profiles
      final allSymbols = <String>{};
      for (final profileId in profileIds) {
        final positions = await db.getPositionsForProfile(profileId);
        allSymbols.addAll(positions.map((p) => p.symbol));
      }

      if (allSymbols.isEmpty) {
        AppLogger.d('PortfolioCalculator: No symbols to fetch');
        return;
      }

      AppLogger.d('PortfolioCalculator: Fetching prices for ${allSymbols.length} symbols');

      // Fetch latest prices from CSE API
      final prices = await cseService.fetchStockPrices(allSymbols.toList());

      if (prices.isEmpty) {
        AppLogger.w('PortfolioCalculator: No prices fetched from CSE');
        return;
      }

      // Store prices in database
      for (final price in prices) {
        await db.insertStockPrice(
          symbol: price.symbol,
          priceDate: price.priceDate,
          closePrice: price.closePrice,
        );
      }

      AppLogger.d('PortfolioCalculator: Stored ${prices.length} stock prices');

      // Recalculate portfolio for each profile
      for (final profileId in profileIds) {
        await calculateAndStorePortfolioValue(profileId);
      }

      AppLogger.d('PortfolioCalculator: Portfolio update complete');
    } catch (e) {
      AppLogger.e('PortfolioCalculator: Error updating prices: $e');
    }
  }

  /// Get portfolio value history for charting
  Future<List<PortfolioValueData>> getPortfolioHistory(
    String profileId,
    int days,
  ) async {
    return db.getPortfolioValueHistory(profileId, days);
  }

  /// Get individual stock details for the detail screen
  Future<StockDetails?> getStockDetails(
    String profileId,
    String symbol,
    int historyDays,
  ) async {
    try {
      // Get position
      final positions = await db.getPositionsForProfile(profileId);
      Position? position;
      try {
        position = positions.firstWhere((p) => p.symbol == symbol);
      } catch (e) {
        // No matching position found
        position = null;
      }

      if (position == null) {
        return null;
      }

      // Get latest price
      final latestPrice = await db.getLatestStockPrice(symbol);

      if (latestPrice == null) {
        return null;
      }

      // Get price history
      final priceHistory = await db.getStockPriceHistory(symbol, historyDays);

      // Get investment events for this stock
      final stockEvents = await db.getInvestmentEventsForProfile(profileId);
      final symbolEvents = stockEvents.where((e) => e.symbol == symbol).toList();

      // Calculate metrics
      final currentValue = position.qty * latestPrice.closePrice;

      // Investment events don't carry purchase price, so cost basis is unknown.
      // Show 0 gain/loss rather than a fake estimate.
      const double gainLoss = 0.0;
      const double gainLossPercent = 0.0;
      final costBasis = currentValue;

      return StockDetails(
        symbol: symbol,
        currentPrice: latestPrice.closePrice,
        quantity: position.qty,
        currentValue: currentValue,
        costBasis: costBasis,
        gainLoss: gainLoss,
        gainLossPercent: gainLossPercent,
        priceHistory: priceHistory,
        transactionHistory: symbolEvents,
      );
    } catch (e) {
      AppLogger.e('PortfolioCalculator: Error getting stock details: $e');
      return null;
    }
  }
}

/// Data class for stock detail information
class StockDetails {
  final String symbol;
  final double currentPrice;
  final int quantity;
  final double currentValue;
  final double costBasis;
  final double gainLoss;
  final double gainLossPercent;
  final List<StockPrice> priceHistory;
  final List<InvestmentEvent> transactionHistory;

  StockDetails({
    required this.symbol,
    required this.currentPrice,
    required this.quantity,
    required this.currentValue,
    required this.costBasis,
    required this.gainLoss,
    required this.gainLossPercent,
    required this.priceHistory,
    required this.transactionHistory,
  });

  bool get isPositive => gainLoss > 0;
  bool get isNegative => gainLoss < 0;
  bool get isBreakeven => gainLoss == 0;
}
