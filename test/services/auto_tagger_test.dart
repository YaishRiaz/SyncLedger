import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/models/parsed_transaction.dart';
import 'package:sync_ledger/domain/services/auto_tagger.dart';

void main() {
  group('AutoTagger', () {
    test('tags Uber as transport', () {
      final txn = ParsedTransaction(
        amount: 279.00,
        direction: TransactionDirection.expense,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.expense,
        merchant: 'UBER',
      );
      expect(AutoTagger.categorize(txn), CategoryTag.transport);
    });

    test('tags CFC HEALTH CARE as healthcare', () {
      final txn = ParsedTransaction(
        amount: 722.40,
        direction: TransactionDirection.expense,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.expense,
        merchant: 'CFC HEALTH CARE PVT LTD',
      );
      expect(AutoTagger.categorize(txn), CategoryTag.healthcare);
    });

    test('tags fee type as fees', () {
      final txn = ParsedTransaction(
        amount: 25.00,
        direction: TransactionDirection.expense,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.fee,
      );
      expect(AutoTagger.categorize(txn), CategoryTag.fees);
    });

    test('tags transfer type as transfers', () {
      final txn = ParsedTransaction(
        amount: 4000.00,
        direction: TransactionDirection.expense,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.transfer,
      );
      expect(AutoTagger.categorize(txn), CategoryTag.transfers);
    });

    test('tags unknown merchant as other', () {
      final txn = ParsedTransaction(
        amount: 500.00,
        direction: TransactionDirection.expense,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.expense,
        merchant: 'RANDOM SHOP',
      );
      expect(AutoTagger.categorize(txn), CategoryTag.other);
    });
  });
}
