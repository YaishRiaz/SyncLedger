import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/parsers/hnb_parser.dart';
import 'package:sync_ledger/domain/parsers/ndb_parser.dart';
import 'package:sync_ledger/domain/models/enums.dart';

void main() {
  group('Transfer Matching Logic', () {
    late HnbParser hnbParser;
    late NdbParser ndbParser;

    setUp(() {
      hnbParser = HnbParser();
      ndbParser = NdbParser();
    });

    test('NDB outward + HNB CEFT credit have matching amounts', () {
      const ndbBody =
          'LKR 4,000.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Outward Transfer';
      const hnbBody =
          'HNB LKR 4,000.00 credited to Ac No:02702XXXXX71 on 22/02/26 '
          '20:23:11 Reason:CEFT-YAISH Bal:LKR 5,255.27';
      final now = DateTime(2026, 2, 22, 20, 23).millisecondsSinceEpoch;

      final ndbResult = ndbParser.parse('NDB ALERT', ndbBody, now);
      final hnbResult = hnbParser.parse('HNB', hnbBody, now);

      final outTxn = ndbResult.transactions.first;
      final inTxn = hnbResult.transactions.first;

      // Same amount
      expect(outTxn.amount, inTxn.amount);
      // Out is expense, in is income
      expect(outTxn.direction, TransactionDirection.expense);
      expect(inTxn.direction, TransactionDirection.income);
      // Both are transfer type
      expect(outTxn.type, TransactionType.transfer);
      expect(inTxn.type, TransactionType.transfer);
    });

    test('NDB transfer fee is separate and should not match as transfer amount', () {
      const feeBody =
          'LKR 25.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Transfer Charges';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = ndbParser.parse('NDB ALERT', feeBody, now);
      final feeTxn = result.transactions.first;

      expect(feeTxn.amount, 25.00);
      expect(feeTxn.type, TransactionType.fee);
      // Fee is NOT a transfer type, so it should not be matched as a transfer
      expect(feeTxn.type, isNot(TransactionType.transfer));
    });

    test('different amounts should not produce a match', () {
      const ndbBody =
          'LKR 5,000.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Outward Transfer';
      const hnbBody =
          'HNB LKR 4,000.00 credited to Ac No:02702XXXXX71 on 22/02/26 '
          '20:23:11 Reason:CEFT-YAISH Bal:LKR 5,255.27';
      final now = DateTime.now().millisecondsSinceEpoch;

      final ndbResult = ndbParser.parse('NDB ALERT', ndbBody, now);
      final hnbResult = hnbParser.parse('HNB', hnbBody, now);

      expect(ndbResult.transactions.first.amount,
          isNot(hnbResult.transactions.first.amount),);
    });

    test('CEFT keyword present in both transfer directions', () {
      const ndbBody =
          'LKR 4,000.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 '
          '20:23 as CEFTS Outward Transfer';
      const hnbBody =
          'HNB LKR 4,000.00 credited to Ac No:02702XXXXX71 on 22/02/26 '
          '20:23:11 Reason:CEFT-YAISH Bal:LKR 5,255.27';
      final now = DateTime.now().millisecondsSinceEpoch;

      final ndbResult = ndbParser.parse('NDB ALERT', ndbBody, now);
      final hnbResult = hnbParser.parse('HNB', hnbBody, now);

      final outRef = ndbResult.transactions.first.reference?.toUpperCase() ?? '';
      final inRef = hnbResult.transactions.first.reference?.toUpperCase() ?? '';

      expect(outRef.contains('CEFT'), true);
      expect(inRef.contains('CEFT'), true);
    });
  });
}
