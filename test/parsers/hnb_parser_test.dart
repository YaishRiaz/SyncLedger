import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/parsers/hnb_parser.dart';

void main() {
  late HnbParser parser;

  setUp(() {
    parser = HnbParser();
  });

  group('HnbParser.canParse', () {
    test('matches HNB sender', () {
      expect(parser.canParse('HNB', ''), true);
    });

    test('does not match NDB sender', () {
      expect(parser.canParse('NDB ALERT', ''), false);
    });
  });

  group('HnbParser - Credit (CEFT)', () {
    test('parses CEFT credit with balance', () {
      const body =
          'HNB LKR 4,000.00 credited to Ac No:02702XXXXX71 on 22/02/26 '
          '20:23:11 Reason:CEFT-YAISH Bal:LKR 5,255.27';
      final now = DateTime(2026, 2, 22, 20, 23).millisecondsSinceEpoch;

      final result = parser.parse('HNB', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 4000.00);
      expect(txn.direction, TransactionDirection.income);
      expect(txn.type, TransactionType.transfer);
      expect(txn.accountHint, '4971');
      expect(txn.reference, contains('CEFT'));
      expect(txn.balance, 5255.27);
      expect(txn.confidence, greaterThan(0.8));
    });

    test('extracts correct timestamp from CEFT credit', () {
      const body =
          'HNB LKR 1,500.00 credited to Ac No:02702XXXXX71 on 15/01/26 '
          '09:30:00 Reason:CEFT-SALARY Bal:LKR 10,000.00';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('HNB', body, now);
      final txn = result.transactions.first;
      final dt = txn.occurredAt;
      expect(dt.year, 2026);
      expect(dt.month, 1);
      expect(dt.day, 15);
      expect(dt.hour, 9);
      expect(dt.minute, 30);
    });
  });

  group('HnbParser - Debit Alert (Card/Online)', () {
    test('parses internet purchase', () {
      const body =
          'HNB SMS ALERT:INTERNET, Account:0270***4971,Location:UBER, LK,'
          'Amount(Approx.):279.00 LKR,Av.Bal:1848.91';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('HNB', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 279.00);
      expect(txn.direction, TransactionDirection.expense);
      expect(txn.type, TransactionType.expense);
      expect(txn.merchant, 'UBER');
      expect(txn.accountHint, '4971');
      expect(txn.balance, 1848.91);
    });
  });

  group('HnbParser - Fee/Charges', () {
    test('parses fee debit with remarks', () {
      const body =
          'A Transaction for LKR 25.00 has been debit ed from your '
          'Account Number XXXXX4971 Remarks :Finacle Alert Charges';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('HNB', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 25.00);
      expect(txn.direction, TransactionDirection.expense);
      expect(txn.type, TransactionType.fee);
      expect(txn.reference, contains('Finacle'));
    });
  });

  group('HnbParser - Reversal', () {
    test('parses transaction reversal', () {
      const body =
          'HNB TRANSACTION REVERSAL for your account. Amount:548.69 LKR';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('HNB', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 548.69);
      expect(txn.direction, TransactionDirection.income);
      expect(txn.type, TransactionType.reversal);
    });
  });
}
