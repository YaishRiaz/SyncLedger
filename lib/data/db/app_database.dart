import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sync_ledger/data/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Profiles,
  SmsMessages,
  Transactions,
  TransferGroups,
  TransferLinks,
  InvestmentEvents,
  Positions,
  StockPrices,
  PortfolioValue,
  Changes,
  AutoTagRules,
  StockInfo,
],)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(accounts, accounts.balance);
          await migrator.addColumn(accounts, accounts.balanceUpdatedAtMs);
        }
        if (from < 3) {
          await migrator.addColumn(accounts, accounts.profileId);
        }
        if (from < 4) {
          // Create StockPrices table
          await migrator.create(stockPrices);
          // Create PortfolioValue table
          await migrator.create(portfolioValue);
        }
        if (from < 5) {
          // Create StockInfo table for cached company info (logo, suffix)
          await migrator.create(stockInfo);
        }
      },
    );
  }

  // --- SMS ---
  Future<bool> smsExists(String hash) async {
    final query = select(smsMessages)
      ..where((t) => t.hash.equals(hash));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Check if SMS exists with same hash within ±2 minutes (dedup window)
  Future<bool> smsExistsWithinWindow(String hash, int receivedAtMs) async {
    const twoMinutes = 2 * 60 * 1000;
    final windowStart = receivedAtMs - twoMinutes;
    final windowEnd = receivedAtMs + twoMinutes;

    final query = select(smsMessages)
      ..where((t) =>
          t.hash.equals(hash) &
          t.receivedAtMs.isBetweenValues(windowStart, windowEnd),);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  Future<void> insertSmsMessage({
    required String sender,
    required String? bodyEncrypted,
    required int receivedAtMs,
    required String hash,
    required String parsedStatus,
  }) async {
    await into(smsMessages).insert(SmsMessagesCompanion.insert(
      sender: sender,
      bodyEncryptedOrNull: Value(bodyEncrypted),
      receivedAtMs: receivedAtMs,
      hash: hash,
      parsedStatus: parsedStatus,
    ),);
  }

  Future<SmsMessage?> getSmsByHash(String hash) async {
    final query = select(smsMessages)
      ..where((t) => t.hash.equals(hash));
    return query.getSingleOrNull();
  }

  Future<void> updateSmsStatus(int id, String status) async {
    await (update(smsMessages)..where((t) => t.id.equals(id)))
        .write(SmsMessagesCompanion(parsedStatus: Value(status)));
  }

  // --- Transactions ---
  Future<void> insertTransaction({
    required String profileId,
    required int? accountId,
    required int occurredAtMs,
    required String direction,
    required double amount,
    required String currency,
    required String? merchant,
    required String? reference,
    required String type,
    required String? category,
    required String? tagsJson,
    required int? sourceSmsId,
    required int? transferGroupId,
    required double confidence,
    required String scope,
    String? accountHint,
    String? institution,
  }) async {
    // If accountHint is provided and accountId is null, try to find/create the account
    int? finalAccountId = accountId;
    if (finalAccountId == null && accountHint != null && accountHint.isNotEmpty && institution != null && institution.isNotEmpty) {
      finalAccountId = await findOrCreateAccount(
        profileId: profileId,
        institution: institution,
        last4: accountHint,
      );
    }

    await into(transactions).insert(TransactionsCompanion.insert(
      profileId: profileId,
      accountId: Value(finalAccountId),
      occurredAtMs: occurredAtMs,
      direction: direction,
      amount: amount,
      currency: Value(currency),
      merchant: Value(merchant),
      reference: Value(reference),
      type: type,
      category: Value(category),
      tagsJson: Value(tagsJson),
      sourceSmsId: Value(sourceSmsId),
      transferGroupId: Value(transferGroupId),
      confidence: Value(confidence),
      scope: Value(scope),
    ),);
  }

  Future<List<Transaction>> getTransactionsSince(int sinceMs, {String? profileId}) async {
    final query = select(transactions)
      ..where((t) => t.occurredAtMs.isBiggerOrEqualValue(sinceMs))
      ..where((t) => t.scope.equals('personal'));
    if (profileId != null) {
      query.where((t) => t.profileId.equals(profileId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  Future<List<Transaction>> getFamilyTransactionsSince(int sinceMs) async {
    final query = select(transactions)
      ..where((t) => t.occurredAtMs.isBiggerOrEqualValue(sinceMs))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  Future<List<Transaction>> getAllTransactions() async {
    final query = select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  Future<List<Transaction>> getFilteredTransactions({
    String? type,
    String query = '',
  }) async {
    final q = select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);

    if (type != null) {
      // 'income' and 'expense' filter by direction (the actual money flow),
      // not by type — a transfer fee has type='fee' but direction='expense'.
      if (type == 'income' || type == 'expense') {
        q.where((t) => t.direction.equals(type));
      } else {
        q.where((t) => t.type.equals(type));
      }
    }

    final results = await q.get();

    if (query.isEmpty) return results;
    final lower = query.toLowerCase();
    return results.where((t) {
      final merchant = (t.merchant ?? '').toLowerCase();
      final ref = (t.reference ?? '').toLowerCase();
      final cat = (t.category ?? '').toLowerCase();
      return merchant.contains(lower) ||
          ref.contains(lower) ||
          cat.contains(lower);
    }).toList();
  }

  Future<void> updateTransactionCategory(int id, String category) async {
    await (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(category: Value(category)));
  }

  Future<List<Transaction>> getUnmatchedTransfers() async {
    final query = select(transactions)
      ..where((t) => t.type.isIn(['transfer', 'fee']))
      ..where((t) => t.transferGroupId.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  Future<void> setTransferGroup(int txnId, int groupId) async {
    await (update(transactions)..where((t) => t.id.equals(txnId)))
        .write(TransactionsCompanion(transferGroupId: Value(groupId)));
  }

  /// Get transactions for a specific profile within a date range
  /// Used for PDF report generation
  Future<List<Transaction>> getTransactionsByDateRange(
    String profileId,
    int startTimeMs,
    int endTimeMs,
  ) async {
    final query = select(transactions)
      ..where((t) =>
          t.profileId.equals(profileId) &
          t.occurredAtMs.isBiggerOrEqualValue(startTimeMs) &
          t.occurredAtMs.isSmallerThanValue(endTimeMs))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  // --- Transfer Groups ---
  Future<int> createTransferGroup(double matchScore) async {
    return into(transferGroups).insert(TransferGroupsCompanion.insert(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      matchScore: matchScore,
    ),);
  }

  Future<void> insertTransferLink({
    required int transferGroupId,
    required int fromTransactionId,
    required int toTransactionId,
  }) async {
    await into(transferLinks).insert(TransferLinksCompanion.insert(
      transferGroupId: transferGroupId,
      fromTransactionId: fromTransactionId,
      toTransactionId: toTransactionId,
    ),);
  }

  // --- Investment Events ---
  Future<void> insertInvestmentEvent({
    required String profileId,
    required int occurredAtMs,
    required String eventType,
    required String symbol,
    required int qty,
    required int? sourceSmsId,
    required String scope,
  }) async {
    await into(investmentEvents).insert(InvestmentEventsCompanion.insert(
      profileId: profileId,
      occurredAtMs: occurredAtMs,
      eventType: eventType,
      symbol: symbol,
      qty: qty,
      sourceSmsId: Value(sourceSmsId),
      scope: Value(scope),
    ),);
  }

  Future<List<InvestmentEvent>> getAllInvestmentEvents() async {
    final query = select(investmentEvents)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  /// Get investment events for a specific profile
  Future<List<InvestmentEvent>> getInvestmentEventsForProfile(
    String profileId,
  ) async {
    final query = select(investmentEvents)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
    return query.get();
  }

  // --- Positions ---
  Future<List<Position>> getAllPositions() async {
    return (select(positions)
          ..where((t) => t.qty.isBiggerThanValue(0)))
        .get();
  }

  Future<List<Position>> getPositionsForProfile(String profileId) async {
    return (select(positions)
          ..where((t) =>
              t.profileId.equals(profileId) & t.qty.isBiggerThanValue(0)))
        .get();
  }

  Future<List<Position>> getAllFamilyPositions() async {
    final all = await (select(positions)
          ..where((t) => t.qty.isBiggerThanValue(0)))
        .get();

    final combined = <String, int>{};
    for (final p in all) {
      combined[p.symbol] = (combined[p.symbol] ?? 0) + p.qty;
    }
    return combined.entries
        .map((e) => Position(
              profileId: 'family',
              symbol: e.key,
              qty: e.value,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),)
        .toList();
  }

  Future<void> upsertPosition({
    required String profileId,
    required String symbol,
    required int qtyDelta,
  }) async {
    final existing = await (select(positions)
          ..where((t) =>
              t.profileId.equals(profileId) & t.symbol.equals(symbol),))
        .getSingleOrNull();

    if (existing != null) {
      await (update(positions)
            ..where((t) =>
                t.profileId.equals(profileId) & t.symbol.equals(symbol),))
          .write(PositionsCompanion(
        qty: Value(existing.qty + qtyDelta),
        updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),);
    } else {
      await into(positions).insert(PositionsCompanion.insert(
        profileId: profileId,
        symbol: symbol,
        qty: qtyDelta,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),);
    }
  }

  // --- Changes (sync) ---
  Future<List<Change>> getChangesSince(String deviceId, int sinceSeq) async {
    final query = select(changes)
      ..where(
          (t) => t.deviceId.equals(deviceId) & t.seq.isBiggerThanValue(sinceSeq),)
      ..orderBy([(t) => OrderingTerm.asc(t.seq)]);
    return query.get();
  }

  Future<void> insertChange({
    required String deviceId,
    required int seq,
    required int createdAtMs,
    required String entityType,
    required String entityId,
    required String opType,
    required String? payloadCiphertext,
    required String? payloadNonce,
    required String? payloadMac,
  }) async {
    await into(changes).insert(ChangesCompanion.insert(
      deviceId: deviceId,
      seq: seq,
      createdAtMs: createdAtMs,
      entityType: entityType,
      entityId: entityId,
      opType: opType,
      payloadCiphertext: Value(payloadCiphertext),
      payloadNonce: Value(payloadNonce),
      payloadMac: Value(payloadMac),
    ),);
  }

  Future<void> applyRemoteChanges(List<Change> remoteChanges) async {
    for (final change in remoteChanges) {
      final exists = await (select(changes)
            ..where((t) =>
                t.deviceId.equals(change.deviceId) &
                t.seq.equals(change.seq),))
          .getSingleOrNull();
      if (exists != null) continue;

      await insertChange(
        deviceId: change.deviceId,
        seq: change.seq,
        createdAtMs: change.createdAtMs,
        entityType: change.entityType,
        entityId: change.entityId,
        opType: change.opType,
        payloadCiphertext: change.payloadCiphertext,
        payloadNonce: change.payloadNonce,
        payloadMac: change.payloadMac,
      );
    }
  }

  // --- Accounts ---
  Future<List<Account>> getAllAccounts() async {
    return select(accounts).get();
  }

  /// Returns unique accounts by (institution + last4) for UI display.
  /// When same account is assigned to multiple profiles, returns only one entry.
  /// Used in settings to show distinct bank accounts regardless of profile assignments.
  Future<List<Account>> getUniqueAccountsAcrossProfiles() async {
    final all = await select(accounts).get();

    // Deduplicate by (institution + last4)
    final seen = <String>{};
    final unique = <Account>[];

    for (final account in all) {
      final key = '${account.institution}::${account.last4}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(account);
      }
    }

    return unique;
  }

  /// Finds or creates an account by (profileId + institution + last4) combination.
  /// Returns the account ID.
  /// If account exists for (profileId, institution, last4), returns its ID.
  /// If not, creates a new account and returns its ID.
  Future<int> findOrCreateAccount({
    required String? profileId,
    required String institution,
    required String? last4,
  }) async {
    if (last4 == null || last4.isEmpty) {
      // Fallback: if no last4, match by (profileId + institution) only
      final existing = await (select(accounts)
            ..where((t) =>
                t.institution.equals(institution) &
                (profileId == null ? t.profileId.isNull() : t.profileId.equals(profileId))))
          .getSingleOrNull();
      if (existing != null) {
        return existing.id;
      }
      // Create new account with institution only
      return await into(accounts).insert(AccountsCompanion.insert(
        profileId: profileId != null ? Value(profileId) : const Value.absent(),
        name: institution,
        institution: institution,
        type: 'bank',
      ));
    }

    // Match by (profileId + institution + last4)
    final existing = await (select(accounts)
          ..where((t) =>
              t.institution.equals(institution) &
              t.last4.equals(last4) &
              (profileId == null ? t.profileId.isNull() : t.profileId.equals(profileId))))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    // Create new account
    return await into(accounts).insert(AccountsCompanion.insert(
      profileId: profileId != null ? Value(profileId) : const Value.absent(),
      name: '$institution ···$last4',
      institution: institution,
      type: 'bank',
      last4: Value(last4),
    ));
  }

  /// Get all accounts for a specific profile
  Future<List<Account>> getAccountsByProfile(String profileId) async {
    final query = select(accounts)
      ..where((t) => t.profileId.equals(profileId));
    return query.get();
  }

  /// Update which profile an account belongs to
  Future<void> updateAccountProfile(int accountId, String? profileId) async {
    await (update(accounts)..where((t) => t.id.equals(accountId)))
        .write(AccountsCompanion(
          profileId: profileId != null ? Value(profileId) : const Value(null),
        ));
  }

  Future<List<SmsMessage>> getAllSmsMessages() async {
    return (select(smsMessages)
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAtMs)]))
        .get();
  }

  /// Returns IDs of SMS messages whose sender contains [institution] (case-insensitive).
  /// Used to filter cashflow stats by bank.
  Future<Set<int>> getSmsIdsByInstitution(String institution) async {
    final all = await (select(smsMessages)
          ..where((t) => t.sender.like('%$institution%')))
        .get();
    return {for (final s in all) s.id};
  }

  /// Returns true if a transaction with same profile/direction/amount/merchant already
  /// exists on the same calendar day. Used to prevent double-importing HNB auth+settle SMS.
  Future<bool> transactionExistsForDay({
    required String profileId,
    required int occurredAtMs,
    required String direction,
    required double amount,
    String? merchant,
  }) async {
    final dt = DateTime.fromMillisecondsSinceEpoch(occurredAtMs);
    final dayStart = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + 86400000;

    final q = select(transactions)
      ..where((t) =>
          t.profileId.equals(profileId) &
          t.direction.equals(direction) &
          t.occurredAtMs.isBetweenValues(dayStart, dayEnd) &
          t.amount.isBetweenValues(amount - 0.01, amount + 0.01));

    if (merchant != null && merchant.isNotEmpty) {
      q.where((t) => t.merchant.equals(merchant));
    }

    return (await q.get()).isNotEmpty;
  }

  Future<void> upsertAccount({
    required String institution,
    required String last4,
    required double balance,
    required int updatedAtMs,
    String? profileId,
  }) async {
    // Match by (profileId + institution + last4) to handle same account in different profiles
    final existing = await (select(accounts)
          ..where((t) =>
              t.institution.equals(institution) &
              t.last4.equals(last4) &
              (profileId == null ? t.profileId.isNull() : t.profileId.equals(profileId))))
        .getSingleOrNull();

    if (existing != null) {
      // Only update if this balance is newer
      if (existing.balanceUpdatedAtMs == null ||
          updatedAtMs >= existing.balanceUpdatedAtMs!) {
        await (update(accounts)..where((t) => t.id.equals(existing.id))).write(
          AccountsCompanion(
            balance: Value(balance),
            balanceUpdatedAtMs: Value(updatedAtMs),
          ),
        );
      }
    } else {
      await into(accounts).insert(AccountsCompanion.insert(
        profileId: profileId != null ? Value(profileId) : const Value.absent(),
        name: '$institution-****$last4',
        institution: institution,
        type: 'bank',
        last4: Value(last4),
        balance: Value(balance),
        balanceUpdatedAtMs: Value(updatedAtMs),
      ));
    }
  }

  // --- Delete positions for a specific profile (used by recalculatePositions) ---
  Future<void> deletePositionsForProfile(String profileId) async {
    await (delete(positions)..where((t) => t.profileId.equals(profileId))).go();
  }

  // --- Delete All Data ---
  Future<void> deleteAllData() async {
    await delete(smsMessages).go();
    await delete(transactions).go();
    await delete(transferLinks).go();
    await delete(transferGroups).go();
    await delete(investmentEvents).go();
    await delete(positions).go();
    await delete(stockPrices).go();
    await delete(portfolioValue).go();
    await delete(stockInfo).go();
    await delete(changes).go();
    await delete(autoTagRules).go();
    await delete(accounts).go();
  }

  // --- Stock Prices ---
  Future<void> insertStockPrice({
    required String symbol,
    required int priceDate,
    required double closePrice,
    double? highPrice,
    double? lowPrice,
    double? openPrice,
    int? volume,
  }) async {
    await into(stockPrices).insert(
      StockPricesCompanion.insert(
        symbol: symbol,
        priceDate: priceDate,
        closePrice: closePrice,
        highPrice: highPrice != null ? Value(highPrice) : const Value.absent(),
        lowPrice: lowPrice != null ? Value(lowPrice) : const Value.absent(),
        openPrice: openPrice != null ? Value(openPrice) : const Value.absent(),
        volume: volume != null ? Value(volume) : const Value.absent(),
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<StockPrice?> getLatestStockPrice(String symbol) async {
    final result = await (select(stockPrices)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm(expression: t.priceDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    return result;
  }

  Future<List<StockPrice>> getStockPriceHistory(String symbol, int days) async {
    final cutoffDate = _subtractDays(DateTime.now(), days);
    final cutoffYyyymmdd = int.parse(
      '${cutoffDate.year}${cutoffDate.month.toString().padLeft(2, '0')}${cutoffDate.day.toString().padLeft(2, '0')}',
    );

    return (select(stockPrices)
          ..where((t) => t.symbol.equals(symbol) & t.priceDate.isBiggerOrEqualValue(cutoffYyyymmdd))
          ..orderBy([(t) => OrderingTerm(expression: t.priceDate, mode: OrderingMode.asc)]))
        .get();
  }

  // --- Portfolio Value ---
  Future<void> insertPortfolioValue({
    required String profileId,
    required int valueDate,
    required double totalValue,
    double? dayChangeAmount,
    double? dayChangePercent,
  }) async {
    await into(portfolioValue).insert(
      PortfolioValueCompanion.insert(
        profileId: profileId,
        valueDate: valueDate,
        totalValue: totalValue,
        dayChangeAmount: dayChangeAmount != null ? Value(dayChangeAmount) : const Value.absent(),
        dayChangePercent: dayChangePercent != null ? Value(dayChangePercent) : const Value.absent(),
        calculatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<PortfolioValueData>> getPortfolioValueHistory(String profileId, int days) async {
    final cutoffDate = _subtractDays(DateTime.now(), days);
    final cutoffYyyymmdd = int.parse(
      '${cutoffDate.year}${cutoffDate.month.toString().padLeft(2, '0')}${cutoffDate.day.toString().padLeft(2, '0')}',
    );

    return (select(portfolioValue)
          ..where((t) => t.profileId.equals(profileId) & t.valueDate.isBiggerOrEqualValue(cutoffYyyymmdd))
          ..orderBy([(t) => OrderingTerm(expression: t.valueDate, mode: OrderingMode.asc)]))
        .get();
  }

  Future<PortfolioValueData?> getLatestPortfolioValue(String profileId) async {
    final result = await (select(portfolioValue)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm(expression: t.valueDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    return result;
  }

  /// Helper method to subtract days from a date
  DateTime _subtractDays(DateTime date, int days) {
    return date.subtract(Duration(days: days));
  }

  // --- Stock Info (company name, logo, symbol suffix) ---
  Future<void> upsertStockInfo({
    required String symbol,
    String? companyName,
    String? logoPath,
    String? symbolSuffix,
  }) async {
    await into(stockInfo).insert(
      StockInfoCompanion.insert(
        symbol: symbol,
        companyName: companyName != null ? Value(companyName) : const Value.absent(),
        logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
        symbolSuffix: symbolSuffix != null ? Value(symbolSuffix) : const Value.absent(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<StockInfoData?> getStockInfo(String symbol) async {
    return (select(stockInfo)..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  /// Delete [StockPrice] rows whose [priceDate] is older than [keepDays]
  /// calendar days from today. Called after each daily refresh to keep
  /// the database lean (default window: 90 days).
  Future<void> pruneOldStockPrices(int keepDays) async {
    final cutoff = _subtractDays(DateTime.now(), keepDays);
    final cutoffYyyymmdd = int.parse(
      '${cutoff.year}${cutoff.month.toString().padLeft(2, '0')}${cutoff.day.toString().padLeft(2, '0')}',
    );
    await (delete(stockPrices)
          ..where((t) => t.priceDate.isSmallerThanValue(cutoffYyyymmdd)))
        .go();
  }

  /// Bulk-upsert stock price rows inside a single transaction for performance.
  /// Each row map must contain: symbol, priceDate, closePrice.
  /// Optional: openPrice, highPrice, lowPrice, volume (all nullable).
  Future<void> batchInsertStockPrices(
    List<Map<String, dynamic>> rows,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      for (final row in rows) {
        final hp = row['highPrice'] as double?;
        final lp = row['lowPrice'] as double?;
        final op = row['openPrice'] as double?;
        final vol = row['volume'] as int?;
        b.insert(
          stockPrices,
          StockPricesCompanion.insert(
            symbol: row['symbol'] as String,
            priceDate: row['priceDate'] as int,
            closePrice: row['closePrice'] as double,
            highPrice: hp != null ? Value(hp) : const Value.absent(),
            lowPrice: lp != null ? Value(lp) : const Value.absent(),
            openPrice: op != null ? Value(op) : const Value.absent(),
            volume: vol != null ? Value(vol) : const Value.absent(),
            fetchedAtMs: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  // --- Auto-tag rules ---
  Future<void> insertAutoTagRule(String merchantKeyword, String category) async {
    await into(autoTagRules).insert(AutoTagRulesCompanion.insert(
      merchantKeyword: merchantKeyword,
      category: category,
    ),);
  }

  Future<List<AutoTagRule>> getAllAutoTagRules() async {
    return select(autoTagRules).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    return driftDatabase(
      name: 'sync_ledger',
      native: const DriftNativeOptions(
        // default is fine; uses sqlite3_flutter_libs under the hood
      ),
    );
  });
} 
