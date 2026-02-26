import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/models/parsed_investment_event.dart';
import 'package:sync_ledger/domain/parsers/sms_parser.dart';
import 'package:sync_ledger/domain/parsers/parse_utils.dart';

class CdsParser implements SmsParser {
  // "CDS-Alerts ... 11-FEB-26 PURCHASES BFL 180 SALES HELA 1250"
  // "CDS-Alerts ... PURCHASES APLA 270 TKYO 2195 ... SALES RCL 12595"
  // "CDS-Alerts 24-DEC-25 DEPOSITS ... BFL 6950"
  // "CDS-Alerts 24-DEC-25 WITHDRAWALS ... BFL 1390"

  static final _datePattern = RegExp(
    r'(\d{1,2})-(\w{3})-(\d{2})',
    caseSensitive: false,
  );

  static final _purchasesSection = RegExp(
    r'PURCHASES\s+(.+?)(?=SALES|DEPOSITS|WITHDRAWALS|$)',
    caseSensitive: false,
  );

  static final _salesSection = RegExp(
    r'SALES\s+(.+?)(?=PURCHASES|DEPOSITS|WITHDRAWALS|$)',
    caseSensitive: false,
  );

  static final _depositsSection = RegExp(
    r'DEPOSITS\s+(.+?)(?=PURCHASES|SALES|WITHDRAWALS|$)',
    caseSensitive: false,
  );

  static final _withdrawalsSection = RegExp(
    r'WITHDRAWALS\s+(.+?)(?=PURCHASES|SALES|DEPOSITS|$)',
    caseSensitive: false,
  );

  // Matches pairs of SYMBOL QTY (e.g., "BFL 180", "APLA 270")
  static final _symbolQtyPattern = RegExp(
    r'([A-Z]{2,6})\s+(\d+)',
    caseSensitive: false,
  );

  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase().replaceAll('+', ' ').replaceAll('-', ' ').trim();
    final b = body.toUpperCase();
    return s.contains('CDS') || b.startsWith('CDS-ALERTS') || b.startsWith('CDS ALERTS');
  }

  @override
  ParseResult parse(String sender, String body, int receivedAtMs) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final events = <ParsedInvestmentEvent>[];

    final dateMatch = _datePattern.firstMatch(normalized);
    int occurredAtMs = receivedAtMs;
    if (dateMatch != null) {
      final dt = ParseUtils.parseCdsDate(
        dateMatch.group(1)!,
        dateMatch.group(2)!,
        dateMatch.group(3)!,
      );
      if (dt != null) occurredAtMs = dt.millisecondsSinceEpoch;
    }

    // Parse PURCHASES
    final purchaseMatch = _purchasesSection.firstMatch(normalized);
    if (purchaseMatch != null) {
      events.addAll(
        _extractSymbolQty(
          purchaseMatch.group(1)!,
          InvestmentEventType.buy,
          occurredAtMs,
        ),
      );
    }

    // Parse SALES
    final salesMatch = _salesSection.firstMatch(normalized);
    if (salesMatch != null) {
      events.addAll(
        _extractSymbolQty(
          salesMatch.group(1)!,
          InvestmentEventType.sell,
          occurredAtMs,
        ),
      );
    }

    // Parse DEPOSITS
    final depositMatch = _depositsSection.firstMatch(normalized);
    if (depositMatch != null) {
      events.addAll(
        _extractSymbolQty(
          depositMatch.group(1)!,
          InvestmentEventType.deposit,
          occurredAtMs,
        ),
      );
    }

    // Parse WITHDRAWALS
    final withdrawalMatch = _withdrawalsSection.firstMatch(normalized);
    if (withdrawalMatch != null) {
      events.addAll(
        _extractSymbolQty(
          withdrawalMatch.group(1)!,
          InvestmentEventType.withdrawal,
          occurredAtMs,
        ),
      );
    }

    return ParseResult(investmentEvents: events);
  }

  List<ParsedInvestmentEvent> _extractSymbolQty(
    String section,
    InvestmentEventType eventType,
    int occurredAtMs,
  ) {
    final events = <ParsedInvestmentEvent>[];
    for (final match in _symbolQtyPattern.allMatches(section)) {
      final symbol = match.group(1)!.toUpperCase();
      final qty = int.tryParse(match.group(2)!) ?? 0;
      if (qty > 0) {
        events.add(ParsedInvestmentEvent(
          occurredAtMs: occurredAtMs,
          eventType: eventType,
          symbol: symbol,
          qty: qty,
        ),);
      }
    }
    return events;
  }
}
