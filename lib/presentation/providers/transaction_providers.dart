import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

class CashflowData {
  const CashflowData({
    this.income = 0,
    this.expense = 0,
    this.transfers = 0,
  });
  final double income;
  final double expense;
  final double transfers;
}

final monthlyCashflowProvider = FutureProvider<CashflowData>((ref) async {
  final db = ref.watch(databaseProvider);
  final selectedBank = ref.watch(selectedBankProvider); // null = All Banks
  final profileAccounts = await ref.watch(profileAccountsProvider.future);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startMs = startOfMonth.millisecondsSinceEpoch;

  final txns = await db.getTransactionsSince(startMs);

  // When a specific bank is selected, only include transactions sourced from
  // SMS messages whose sender contains that institution name.
  Set<int>? allowedSmsIds;
  if (selectedBank != null) {
    allowedSmsIds = await db.getSmsIdsByInstitution(selectedBank);
  }

  // Build set of account IDs assigned to active profile
  final profileAccountIds = {for (final a in profileAccounts) a.id};

  double income = 0;
  double expense = 0;
  double transfers = 0;

  for (final t in txns) {
    if (t.currency != 'LKR') continue;

    // Filter by profile's assigned accounts
    if (t.accountId == null || !profileAccountIds.contains(t.accountId)) {
      continue;
    }

    // Filter by bank if selected
    if (allowedSmsIds != null &&
        (t.sourceSmsId == null || !allowedSmsIds.contains(t.sourceSmsId))) {
      continue;
    }

    if (t.transferGroupId != null) {
      transfers += t.amount;
      continue;
    }
    switch (t.direction) {
      case 'income':
        income += t.amount;
      case 'expense':
        expense += t.amount;
    }
  }

  return CashflowData(income: income, expense: expense, transfers: transfers);
});

/// Period in days for the family overview. 30 = last 30 days, etc.
final familySelectedPeriodDaysProvider = StateProvider<int>((ref) => 30);

final familyCashflowProvider = FutureProvider<CashflowData>((ref) async {
  final db = ref.watch(databaseProvider);
  final days = ref.watch(familySelectedPeriodDaysProvider);
  final startMs = DateTime.now()
      .subtract(Duration(days: days))
      .millisecondsSinceEpoch;

  final txns = await db.getFamilyTransactionsSince(startMs);

  double income = 0;
  double expense = 0;

  for (final t in txns) {
    if (t.currency != 'LKR') continue;
    if (t.transferGroupId != null) continue;
    switch (t.direction) {
      case 'income':
        income += t.amount;
      case 'expense':
        expense += t.amount;
    }
  }

  return CashflowData(income: income, expense: expense);
});

class FilterParams {
  const FilterParams({this.type, this.query = ''});
  final TransactionType? type;
  final String query;
}

final filteredTransactionsProvider = FutureProvider.family<
    List<Transaction>, ({TransactionType? type, String query})>(
  (ref, params) async {
    final db = ref.watch(databaseProvider);
    final profileAccounts = await ref.watch(profileAccountsProvider.future);

    final allTransactions = await db.getFilteredTransactions(
      type: params.type?.name,
      query: params.query,
    );

    // Build set of account IDs assigned to active profile
    final profileAccountIds = {for (final a in profileAccounts) a.id};

    // Filter to show only transactions from profile's assigned accounts
    return allTransactions
        .where((t) => t.accountId != null && profileAccountIds.contains(t.accountId))
        .toList();
  },
);

final transactionActionsProvider = Provider<TransactionActions>((ref) {
  return TransactionActions(ref.watch(databaseProvider));
});

class TransactionActions {
  TransactionActions(this._db);
  final AppDatabase _db;

  Future<void> updateCategory(
    int transactionId,
    CategoryTag category, {
    bool learnRule = false,
    String? merchant,
  }) async {
    await _db.updateTransactionCategory(transactionId, category.name);
    if (learnRule && merchant != null) {
      await _db.insertAutoTagRule(merchant, category.name);
    }
  }
}
