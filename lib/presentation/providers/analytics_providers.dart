import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

class MonthlyStats {
  const MonthlyStats({this.income = 0, this.expense = 0});
  final double income;
  final double expense;
}

final monthlyAnalyticsProvider =
    FutureProvider<Map<int, MonthlyStats>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
  final startMs = sixMonthsAgo.millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final result = <int, MonthlyStats>{};

  for (final t in txns) {
    if (t.transferGroupId != null) continue;
    final dt = DateTime.fromMillisecondsSinceEpoch(t.occurredAtMs);
    final monthKey = dt.month;
    final existing = result[monthKey] ?? const MonthlyStats();
    result[monthKey] = MonthlyStats(
      income:
          existing.income + (t.direction == 'income' ? t.amount : 0),
      expense:
          existing.expense + (t.direction == 'expense' ? t.amount : 0),
    );
  }

  return result;
});

final topMerchantsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startMs = startOfMonth.millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final merchants = <String, double>{};

  for (final t in txns) {
    if (t.merchant == null || t.merchant!.isEmpty) continue;
    if (t.direction != 'expense') continue;
    merchants[t.merchant!] = (merchants[t.merchant!] ?? 0) + t.amount;
  }

  final sorted = merchants.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sorted);
});

final categoryBreakdownProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startMs = startOfMonth.millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);
  final cats = <String, double>{};

  for (final t in txns) {
    if (t.direction != 'expense') continue;
    final cat = t.category ?? 'Other';
    cats[cat] = (cats[cat] ?? 0) + t.amount;
  }

  return cats;
});
