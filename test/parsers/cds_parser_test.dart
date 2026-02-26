import 'package:flutter_test/flutter_test.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/parsers/cds_parser.dart';

void main() {
  late CdsParser parser;

  setUp(() {
    parser = CdsParser();
  });

  group('CdsParser.canParse', () {
    test('matches CDS-Alerts sender', () {
      expect(parser.canParse('CDS-Alerts', ''), true);
    });

    test('matches body starting with CDS-Alerts', () {
      expect(parser.canParse('12345', 'CDS-Alerts 11-FEB-26 PURCHASES BFL 180'), true);
    });
  });

  group('CdsParser - Purchases and Sales', () {
    test('parses single purchase and sale', () {
      const body =
          'CDS-Alerts 11-FEB-26 PURCHASES BFL 180 SALES HELA 1250';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('CDS-Alerts', body, now);

      expect(result.investmentEvents.length, 2);

      final purchase = result.investmentEvents
          .firstWhere((e) => e.eventType == InvestmentEventType.buy);
      expect(purchase.symbol, 'BFL');
      expect(purchase.qty, 180);

      final sale = result.investmentEvents
          .firstWhere((e) => e.eventType == InvestmentEventType.sell);
      expect(sale.symbol, 'HELA');
      expect(sale.qty, 1250);
    });

    test('parses multiple purchases and sales', () {
      const body =
          'CDS-Alerts 11-FEB-26 PURCHASES APLA 270 TKYO 2195 '
          'SALES RCL 12595';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('CDS-Alerts', body, now);

      expect(result.investmentEvents.length, 3);

      final buys = result.investmentEvents
          .where((e) => e.eventType == InvestmentEventType.buy)
          .toList();
      expect(buys.length, 2);
      expect(buys[0].symbol, 'APLA');
      expect(buys[0].qty, 270);
      expect(buys[1].symbol, 'TKYO');
      expect(buys[1].qty, 2195);

      final sells = result.investmentEvents
          .where((e) => e.eventType == InvestmentEventType.sell)
          .toList();
      expect(sells.length, 1);
      expect(sells[0].symbol, 'RCL');
      expect(sells[0].qty, 12595);
    });

    test('parses correct date from CDS format', () {
      const body = 'CDS-Alerts 11-FEB-26 PURCHASES BFL 180';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('CDS-Alerts', body, now);
      final event = result.investmentEvents.first;
      final dt = event.occurredAt;
      expect(dt.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 11);
    });
  });

  group('CdsParser - Deposits', () {
    test('parses deposit event', () {
      const body = 'CDS-Alerts 24-DEC-25 DEPOSITS BFL 6950';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('CDS-Alerts', body, now);

      expect(result.investmentEvents.length, 1);
      final event = result.investmentEvents.first;
      expect(event.eventType, InvestmentEventType.deposit);
      expect(event.symbol, 'BFL');
      expect(event.qty, 6950);

      final dt = event.occurredAt;
      expect(dt.year, 2025);
      expect(dt.month, 12);
      expect(dt.day, 24);
    });
  });

  group('CdsParser - Withdrawals', () {
    test('parses withdrawal event', () {
      const body = 'CDS-Alerts 24-DEC-25 WITHDRAWALS BFL 1390';
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = parser.parse('CDS-Alerts', body, now);

      expect(result.investmentEvents.length, 1);
      final event = result.investmentEvents.first;
      expect(event.eventType, InvestmentEventType.withdrawal);
      expect(event.symbol, 'BFL');
      expect(event.qty, 1390);
    });
  });
}
