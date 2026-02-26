import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/parsers/ndb_parser.dart';

void main() {
  late NdbParser parser;

  setUp(() {
    parser = NdbParser();
  });

  group('NdbParser.canParse', () {
    test('matches NDB ALERT sender', () {
      expect(parser.canParse('NDB ALERT', ''), true);
    });

    test('matches NDB sender', () {
      expect(parser.canParse('NDB', ''), true);
    });

    test('does not match HNB sender', () {
      expect(parser.canParse('HNB', ''), false);
    });
  });

  group('NdbParser - Transfer OUT (CEFTS Outward)', () {
    test('parses CEFTS outward transfer', () {
      const body =
          'LKR 4,000.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Outward Transfer';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('NDB ALERT', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 4000.00);
      expect(txn.direction, TransactionDirection.expense);
      expect(txn.type, TransactionType.transfer);
      expect(txn.accountHint, '8484');
    });

    test('extracts correct date from NDB format', () {
      const body =
          'LKR 1,000.00 debited from AC XXXXXXXX8484 on 15 Jan 2026 '
          '09:30 as CEFTS Outward Transfer';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('NDB ALERT', body, now);
      final txn = result.transactions.first;
      final dt = txn.occurredAt;
      expect(dt.year, 2026);
      expect(dt.month, 1);
      expect(dt.day, 15);
      expect(dt.hour, 9);
      expect(dt.minute, 30);
    });
  });

  group('NdbParser - Transfer Fee', () {
    test('parses CEFTS transfer charges', () {
      const body =
          'LKR 25.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Transfer Charges';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('NDB ALERT', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 25.00);
      expect(txn.direction, TransactionDirection.expense);
      expect(txn.type, TransactionType.fee);
    });
  });

  group('NdbParser - POS Transaction', () {
    test('parses POS debit with merchant', () {
      const body =
          'LKR 722.40 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '10:15 as POS TXN at CFC HEALTH CARE PVT LTD';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('NDB ALERT', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 722.40);
      expect(txn.direction, TransactionDirection.expense);
      expect(txn.type, TransactionType.expense);
      expect(txn.merchant, contains('CFC HEALTH CARE'));
    });
  });

  group('NdbParser - Credit', () {
    test('parses mobile banking credit', () {
      const body =
          'LKR 100,000.00 credited to AC XXXXXXXX8484 on 22 Feb 2026 '
          '09:00 as Mobile Banking TXN';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('NDB ALERT', body, now);

      expect(result.transactions.length, 1);
      final txn = result.transactions.first;
      expect(txn.amount, 100000.00);
      expect(txn.direction, TransactionDirection.income);
      expect(txn.type, TransactionType.income);
      expect(txn.accountHint, '8484');
    });
  });
}
