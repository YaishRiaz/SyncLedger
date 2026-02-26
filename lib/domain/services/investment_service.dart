import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/models/enums.dart';

class StockSummary {
  const StockSummary({
    required this.symbol,
    this.totalBought = 0,
    this.totalSold = 0,
    this.totalDeposited = 0,
    this.totalWithdrawn = 0,
    this.currentQty = 0,
  });

  final String symbol;
  final int totalBought;
  final int totalSold;
  final int totalDeposited;
  final int totalWithdrawn;
  final int currentQty;
}

class MonthlyStockActivity {
  const MonthlyStockActivity({
    required this.month,
    this.buyCount = 0,
    this.sellCount = 0,
    this.buyQty = 0,
    this.sellQty = 0,
    this.topSymbols = const [],
  });

  final DateTime month;
  final int buyCount;
  final int sellCount;
  final int buyQty;
  final int sellQty;
  final List<String> topSymbols;
}

class InvestmentService {
  InvestmentService(this._db);

  final AppDatabase _db;

  Future<List<StockSummary>> getStockSummaries() async {
    final events = await _db.getAllInvestmentEvents();
    final positions = await _db.getAllPositions();

    final summaries = <String, StockSummary>{};

    for (final e in events) {
      final existing = summaries[e.symbol] ??
          StockSummary(symbol: e.symbol);

      summaries[e.symbol] = StockSummary(
        symbol: e.symbol,
        totalBought: existing.totalBought +
            (e.eventType == 'buy' ? e.qty : 0),
        totalSold: existing.totalSold +
            (e.eventType == 'sell' ? e.qty : 0),
        totalDeposited: existing.totalDeposited +
            (e.eventType == 'deposit' ? e.qty : 0),
        totalWithdrawn: existing.totalWithdrawn +
            (e.eventType == 'withdrawal' ? e.qty : 0),
      );
    }

    for (final p in positions) {
      final existing = summaries[p.symbol];
      if (existing != null) {
        summaries[p.symbol] = StockSummary(
          symbol: p.symbol,
          totalBought: existing.totalBought,
          totalSold: existing.totalSold,
          totalDeposited: existing.totalDeposited,
          totalWithdrawn: existing.totalWithdrawn,
          currentQty: p.qty,
        );
      }
    }

    return summaries.values.toList()
      ..sort((a, b) => b.currentQty.compareTo(a.currentQty));
  }

  Future<List<MonthlyStockActivity>> getMonthlyActivity({
    int months = 6,
  }) async {
    final now = DateTime.now();
    final events = await _db.getAllInvestmentEvents();
    final results = <MonthlyStockActivity>[];

    for (var i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final monthEvents = events.where((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.occurredAtMs);
        return dt.isAfter(month) && dt.isBefore(nextMonth);
      }).toList();

      int buyCount = 0, sellCount = 0, buyQty = 0, sellQty = 0;
      final symbolCounts = <String, int>{};

      for (final e in monthEvents) {
        if (e.eventType == 'buy' || e.eventType == 'deposit') {
          buyCount++;
          buyQty += e.qty;
        } else {
          sellCount++;
          sellQty += e.qty;
        }
        symbolCounts[e.symbol] = (symbolCounts[e.symbol] ?? 0) + e.qty;
      }

      final topSymbols = (symbolCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList();

      results.add(MonthlyStockActivity(
        month: month,
        buyCount: buyCount,
        sellCount: sellCount,
        buyQty: buyQty,
        sellQty: sellQty,
        topSymbols: topSymbols,
      ),);
    }

    return results;
  }

  Future<void> recalculatePositions(String profileId) async {
    final events = await _db.getAllInvestmentEvents();
    final positions = <String, int>{};

    for (final e in events) {
      if (e.profileId != profileId) continue;
      final delta = (e.eventType == 'buy' || e.eventType == 'deposit')
          ? e.qty
          : -e.qty;
      positions[e.symbol] = (positions[e.symbol] ?? 0) + delta;
    }

    for (final entry in positions.entries) {
      await _db.upsertPosition(  // ← use absolute setter, not delta
        profileId: profileId,
        symbol: entry.key,
        qty: entry.value,               // ← the calculated total
      );
    }
  }
}
