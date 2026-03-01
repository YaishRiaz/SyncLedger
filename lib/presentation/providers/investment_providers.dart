import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/portfolio_calculator_service.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

final holdingsProvider = FutureProvider<List<Position>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Filter by active profile so other profiles' holdings don't bleed in
  final activeId = await ref.watch(activeProfileIdProvider.future);
  return db.getPositionsForProfile(activeId);
});

final familyHoldingsProvider = FutureProvider<List<Position>>((ref) async {
  final db = ref.watch(databaseProvider);
  final all = await db.getAllFamilyPositions();
  return all.where((p) => p.qty > 0).toList();
});

final investmentEventsProvider =
    FutureProvider<List<InvestmentEvent>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllInvestmentEvents();
});

/// Portfolio value history for the active profile
/// Used for charting portfolio value over time
final portfolioValueHistoryProvider =
    FutureProvider.family<List<PortfolioValueData>, int>((ref, days) async {
  final db = ref.watch(databaseProvider);
  final activeId = await ref.watch(activeProfileIdProvider.future);
  return db.getPortfolioValueHistory(activeId, days);
});

/// Portfolio calculator service for this profile
final portfolioCalculatorProvider =
    Provider<PortfolioCalculatorService>((ref) {
  final db = ref.watch(databaseProvider);
  final cseService = ref.watch(cseScraperServiceProvider);
  return PortfolioCalculatorService(
    db: db,
    cseService: cseService,
  );
});

/// CSE scraper service
final cseScraperServiceProvider = Provider<CseScraperService>((ref) {
  return CseScraperService();
});

/// Stock details for a specific stock symbol
/// Shows price history, current value, gain/loss, etc.
final stockDetailsProvider =
    FutureProvider.family<StockDetails?, String>((ref, symbol) async {
  final calculator = ref.watch(portfolioCalculatorProvider);
  final activeId = await ref.watch(activeProfileIdProvider.future);
  return calculator.getStockDetails(activeId, symbol, 30);
});

/// Latest portfolio value for the active profile
final latestPortfolioValueProvider = FutureProvider<PortfolioValueData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final activeId = await ref.watch(activeProfileIdProvider.future);
  return db.getLatestPortfolioValue(activeId);
});

/// Total current portfolio value calculated from all holdings
final totalPortfolioValueProvider = FutureProvider<double>((ref) async {
  final holdings = await ref.watch(holdingsProvider.future);
  final db = ref.watch(databaseProvider);

  double totalValue = 0.0;
  for (final holding in holdings) {
    final latestPrice = await db.getLatestStockPrice(holding.symbol);
    if (latestPrice != null) {
      totalValue += holding.qty * latestPrice.closePrice;
    }
  }
  return totalValue;
});

