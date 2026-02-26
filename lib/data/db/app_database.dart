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
  Changes,
  AutoTagRules,
],)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

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
  }) async {
    await into(transactions).insert(TransactionsCompanion.insert(
      profileId: profileId,
      accountId: Value(accountId),
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

  Future<List<Transaction>> getTransactionsSince(int sinceMs) async {
    final query = select(transactions)
      ..where((t) => t.occurredAtMs.isBiggerOrEqualValue(sinceMs))
      ..where((t) => t.scope.equals('personal'))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtMs)]);
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
      q.where((t) => t.type.equals(type));
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

  // --- Positions ---
  Future<List<Position>> getAllPositions() async {
    return (select(positions)
          ..where((t) => t.qty.isBiggerThanValue(0)))
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
