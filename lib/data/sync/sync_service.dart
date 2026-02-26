import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/core/logger.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/data/sync/e2ee_crypto.dart';
import 'package:sync_ledger/data/sync/sync_client.dart';

class SyncService {
  SyncService({
    required this.db,
    required this.client,
    required this.crypto,
  });

  final AppDatabase db;
  final SyncClient client;
  final E2eeCrypto crypto;

  /// Record a local mutation to the change log, encrypting the payload.
  Future<void> recordChange({
    required String deviceId,
    required String entityType,
    required String entityId,
    required String opType,
    required Map<String, dynamic> payload,
  }) async {
    final plaintext = jsonEncode(payload);
    final encrypted = await crypto.encrypt(plaintext);

    final prefs = await SharedPreferences.getInstance();
    final lastSeq = prefs.getInt('${PrefKeys.lastSyncSeq}_$deviceId') ?? 0;
    final newSeq = lastSeq + 1;

    await db.insertChange(
      deviceId: deviceId,
      seq: newSeq,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      entityType: entityType,
      entityId: entityId,
      opType: opType,
      payloadCiphertext: encrypted.ciphertext,
      payloadNonce: encrypted.nonce,
      payloadMac: encrypted.mac,
    );

    await prefs.setInt('${PrefKeys.lastSyncSeq}_$deviceId', newSeq);
  }

  /// Push local changes to server, pull remote changes, decrypt & apply.
  Future<SyncResult> sync() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(PrefKeys.deviceId);
    final groupId = prefs.getString(PrefKeys.familyGroupId);

    if (deviceId == null || groupId == null) {
      return const SyncResult(pushed: 0, pulled: 0, errors: ['Not paired']);
    }

    int pushed = 0;
    int pulled = 0;
    final errors = <String>[];

    try {
      // Push local changes
      final lastAckSeq = prefs.getInt(PrefKeys.lastSyncSeq) ?? 0;
      final localChanges = await db.getChangesSince(deviceId, lastAckSeq);
      if (localChanges.isNotEmpty) {
        await client.pushChanges(groupId, deviceId, localChanges);
        pushed = localChanges.length;
      }

      // Pull remote changes
      final remoteChanges =
          await client.pullChanges(groupId, deviceId, lastAckSeq);
      if (remoteChanges.isNotEmpty) {
        for (final change in remoteChanges) {
          try {
            await _applyRemoteChange(change);
            pulled++;
          } catch (e) {
            errors.add('Failed to apply change ${change.id}: $e');
            AppLogger.e('Sync apply error', e);
          }
        }

        final maxSeq = remoteChanges
            .map((c) => c.seq)
            .reduce((a, b) => a > b ? a : b);
        await prefs.setInt(PrefKeys.lastSyncSeq, maxSeq);
      }
    } catch (e) {
      errors.add('Sync failed: $e');
      AppLogger.e('Sync error', e);
    }

    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  Future<void> _applyRemoteChange(Change change) async {
    if (change.payloadCiphertext == null ||
        change.payloadNonce == null ||
        change.payloadMac == null) {
      return;
    }

    final decrypted = await crypto.decrypt(EncryptedPayload(
      ciphertext: change.payloadCiphertext!,
      nonce: change.payloadNonce!,
      mac: change.payloadMac!,
    ),);

    final payload = jsonDecode(decrypted) as Map<String, dynamic>;

    switch (change.entityType) {
      case 'transaction':
        await _applyTransactionChange(change.opType, payload);
      case 'investment_event':
        await _applyInvestmentChange(change.opType, payload);
    }

    // Record the remote change locally for dedup
    await db.insertChange(
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

  Future<void> _applyTransactionChange(
    String opType,
    Map<String, dynamic> payload,
  ) async {
    if (opType == 'insert') {
      await db.insertTransaction(
        profileId: payload['profileId'] as String,
        accountId: payload['accountId'] as int?,
        occurredAtMs: payload['occurredAtMs'] as int,
        direction: payload['direction'] as String,
        amount: (payload['amount'] as num).toDouble(),
        currency: payload['currency'] as String? ?? 'LKR',
        merchant: payload['merchant'] as String?,
        reference: payload['reference'] as String?,
        type: payload['type'] as String,
        category: payload['category'] as String?,
        tagsJson: payload['tagsJson'] as String?,
        sourceSmsId: null,
        transferGroupId: null,
        confidence: (payload['confidence'] as num?)?.toDouble() ?? 1.0,
        scope: 'family',
      );
    }
  }

  Future<void> _applyInvestmentChange(
    String opType,
    Map<String, dynamic> payload,
  ) async {
    if (opType == 'insert') {
      await db.insertInvestmentEvent(
        profileId: payload['profileId'] as String,
        occurredAtMs: payload['occurredAtMs'] as int,
        eventType: payload['eventType'] as String,
        symbol: payload['symbol'] as String,
        qty: payload['qty'] as int,
        sourceSmsId: null,
        scope: 'family',
      );
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    this.errors = const [],
  });

  final int pushed;
  final int pulled;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}
