import 'package:sync_ledger/domain/models/enums.dart';

class ParsedInvestmentEvent {
  const ParsedInvestmentEvent({
    required this.occurredAtMs,
    required this.eventType,
    required this.symbol,
    required this.qty,
  });

  final int occurredAtMs;
  final InvestmentEventType eventType;
  final String symbol;
  final int qty;

  DateTime get occurredAt =>
      DateTime.fromMillisecondsSinceEpoch(occurredAtMs);

  @override
  String toString() =>
      'ParsedInvestmentEvent(${eventType.name} $symbol x$qty)';
}
