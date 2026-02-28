import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/models/sms_message.dart' as raw_sms;
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/parsers/parser_registry.dart';
import 'package:sync_ledger/domain/services/auto_tagger.dart';
import 'package:sync_ledger/core/logger.dart';

class SmsIngestionService {
  SmsIngestionService({
    required this.db,
    required this.registry,
    required this.debugMode,
  });

  final AppDatabase db;
  final ParserRegistry registry;
  final bool debugMode;

  /// Returns true if parsed successfully, false if needs review, null if duplicate.
  Future<bool?> ingestSms(raw_sms.SmsMessage sms, {required String profileId}) async {
    final hash = sms.hash;

    // Exact-hash dedup: same sender+body always means the same message,
    // regardless of received timestamp (catches re-broadcasts and archive re-imports).
    final exists = await db.smsExists(hash);
    if (exists) {
      AppLogger.d('Duplicate SMS detected (same hash): ${sms.sender}');
      return null;
    }

    await db.insertSmsMessage(
      sender: sms.sender,
      bodyEncrypted: debugMode ? sms.body : null,
      receivedAtMs: sms.receivedAtMs,
      hash: hash,
      parsedStatus: ParsedStatus.needsReview.name,
    );

    final smsRecord = await db.getSmsByHash(hash);
    if (smsRecord == null) {
      AppLogger.w('Failed to retrieve SMS after insert');
      return false;
    }

    final result = registry.tryParse(sms.sender, sms.body, sms.receivedAtMs);
    if (result == null) {
      AppLogger.w('Unparsed SMS from ${sms.sender}');
      return false;
    }

    for (final txn in result.transactions) {
      // Dedup: skip if a transaction with same direction/amount/merchant already exists today.
      // Handles cases like HNB sending both authorization and settlement SMS for the same spend.
      final isDuplicate = await db.transactionExistsForDay(
        profileId: profileId,
        occurredAtMs: txn.occurredAtMs,
        direction: txn.direction.name,
        amount: txn.amount,
        merchant: txn.merchant,
      );
      if (isDuplicate) {
        AppLogger.d(
          'Skipping duplicate txn: ${txn.direction.name} ${txn.currency} ${txn.amount} ${txn.merchant ?? ''}',
        );
        continue;
      }

      final category = AutoTagger.categorize(txn);
      await db.insertTransaction(
        profileId: profileId,
        accountId: null,
        occurredAtMs: txn.occurredAtMs,
        direction: txn.direction.name,
        amount: txn.amount,
        currency: txn.currency,
        merchant: txn.merchant,
        reference: txn.reference,
        type: txn.type.name,
        category: category.name,
        tagsJson: null,
        sourceSmsId: smsRecord.id,
        transferGroupId: null,
        confidence: txn.confidence,
        scope: DataScope.personal.name,
      );

      // Persist the available LKR balance from the SMS.
      // Av.Bal is always reported in LKR even for foreign-currency transactions.
      if (txn.balance != null &&
          txn.accountHint != null &&
          txn.sourceSmsSender != null) {
        await db.upsertAccount(
          institution: txn.sourceSmsSender!,
          last4: txn.accountHint!,
          balance: txn.balance!,
          updatedAtMs: txn.occurredAtMs,
        );
      }
    }

    for (final ev in result.investmentEvents) {
      await db.insertInvestmentEvent(
        profileId: profileId,
        occurredAtMs: ev.occurredAtMs,
        eventType: ev.eventType.name,
        symbol: ev.symbol,
        qty: ev.qty,
        sourceSmsId: smsRecord.id,
        scope: DataScope.personal.name,
      );

      await db.upsertPosition(
        profileId: profileId,
        symbol: ev.symbol,
        qtyDelta: ev.eventType == InvestmentEventType.buy ||
                ev.eventType == InvestmentEventType.deposit
            ? ev.qty
            : -ev.qty,
      );
    }

    await db.updateSmsStatus(smsRecord.id, ParsedStatus.parsed.name);
    return true;
  }
}
