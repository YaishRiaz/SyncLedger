import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

// ─── Period selector ─────────────────────────────────────────────────────────

enum AnalyticsPeriod {
  week('Week'),
  thirtyDays('30D'),
  month('Month'),
  ytd('YTD'),
  last365('1Y');

  const AnalyticsPeriod(this.label);
  final String label;

  DateTime startDate(DateTime now) {
    switch (this) {
      case AnalyticsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case AnalyticsPeriod.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case AnalyticsPeriod.ytd:
        return DateTime(now.year, 1, 1);
      case AnalyticsPeriod.last365:
        return now.subtract(const Duration(days: 365));
    }
  }
}

final analyticsSelectedPeriodProvider =
    StateProvider<AnalyticsPeriod>((ref) => AnalyticsPeriod.month);

// ─── Data classes ─────────────────────────────────────────────────────────────

class MonthlyStats {
  const MonthlyStats({this.income = 0, this.expense = 0});
  final double income;
  final double expense;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final monthlyAnalyticsProvider =
    FutureProvider<Map<int, MonthlyStats>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(analyticsSelectedPeriodProvider);
  final now = DateTime.now();
  final startMs = period.startDate(now).millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final result = <int, MonthlyStats>{};

  for (final t in txns) {
    if (t.transferGroupId != null) continue;
    if (t.currency != 'LKR') continue; // Only count LKR in cashflow totals
    final dt = DateTime.fromMillisecondsSinceEpoch(t.occurredAtMs);

    // For short periods (week/30d) group by day; for longer periods, group by month
    final key = (period == AnalyticsPeriod.week ||
            period == AnalyticsPeriod.thirtyDays)
        ? dt.day + dt.month * 100 // unique key per calendar day
        : dt.month;

    final existing = result[key] ?? const MonthlyStats();
    result[key] = MonthlyStats(
      income: existing.income + (t.direction == 'income' ? t.amount : 0),
      expense: existing.expense + (t.direction == 'expense' ? t.amount : 0),
    );
  }

  return result;
});

final topMerchantsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(analyticsSelectedPeriodProvider);
  final now = DateTime.now();
  final startMs = period.startDate(now).millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final merchants = <String, double>{};

  for (final t in txns) {
    if (t.merchant == null || t.merchant!.isEmpty) continue;
    if (t.direction != 'expense') continue;
    if (t.currency != 'LKR') continue;
    merchants[t.merchant!] = (merchants[t.merchant!] ?? 0) + t.amount;
  }

  final sorted = merchants.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sorted);
});

final categoryBreakdownProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(analyticsSelectedPeriodProvider);
  final now = DateTime.now();
  final startMs = period.startDate(now).millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final cats = <String, double>{};

  for (final t in txns) {
    if (t.direction != 'expense') continue;
    if (t.currency != 'LKR') continue;
    final cat = t.category ?? 'Other';
    cats[cat] = (cats[cat] ?? 0) + t.amount;
  }

  // Sort by amount descending
  final sorted = cats.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
});
