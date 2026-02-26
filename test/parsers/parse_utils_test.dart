import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/parsers/parse_utils.dart';

void main() {
  group('ParseUtils.parseAmount', () {
    test('parses amount with commas and decimals', () {
      expect(ParseUtils.parseAmount('4,000.00'), 4000.00);
    });

    test('parses large amount', () {
      expect(ParseUtils.parseAmount('100,000.00'), 100000.00);
    });

    test('parses amount without commas', () {
      expect(ParseUtils.parseAmount('279.00'), 279.00);
    });

    test('parses integer amount', () {
      expect(ParseUtils.parseAmount('25'), 25.0);
    });
  });

  group('ParseUtils.extractLast4', () {
    test('extracts last 4 digits from masked account', () {
      expect(ParseUtils.extractLast4('0270***4971'), '4971');
    });

    test('extracts last 4 from full account with Xs', () {
      expect(ParseUtils.extractLast4('02702XXXXX71'), '0271');
    });

    test('extracts from NDB format', () {
      expect(ParseUtils.extractLast4('XXXXXXXX8484'), '8484');
    });

    test('returns null for empty input', () {
      expect(ParseUtils.extractLast4(null), null);
      expect(ParseUtils.extractLast4(''), null);
    });
  });

  group('ParseUtils.parseDateTimeSL', () {
    test('parses HNB date/time format', () {
      final dt = ParseUtils.parseDateTimeSL('22/02/26', '20:23:11');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 22);
      expect(dt.hour, 20);
      expect(dt.minute, 23);
      expect(dt.second, 11);
    });
  });

  group('ParseUtils.parseDateTimeNdb', () {
    test('parses NDB date/time format', () {
      final dt = ParseUtils.parseDateTimeNdb('22 Feb 2026', '20:23');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 22);
      expect(dt.hour, 20);
      expect(dt.minute, 23);
    });
  });

  group('ParseUtils.parseCdsDate', () {
    test('parses CDS date format', () {
      final dt = ParseUtils.parseCdsDate('11', 'FEB', '26');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 11);
    });

    test('parses December date', () {
      final dt = ParseUtils.parseCdsDate('24', 'DEC', '25');
      expect(dt, isNotNull);
      expect(dt!.year, 2025);
      expect(dt.month, 12);
      expect(dt.day, 24);
    });
  });
}
