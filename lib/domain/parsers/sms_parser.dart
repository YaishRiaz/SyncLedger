import 'package:sync_ledger/domain/models/parsed_transaction.dart';
import 'package:sync_ledger/domain/models/parsed_investment_event.dart';

abstract class SmsParser {
  bool canParse(String sender, String body);

  ParseResult parse(String sender, String body, int receivedAtMs);
}

class ParseResult {
  const ParseResult({
    this.transactions = const [],
    this.investmentEvents = const [],
  });

  final List<ParsedTransaction> transactions;
  final List<ParsedInvestmentEvent> investmentEvents;

  bool get isEmpty => transactions.isEmpty && investmentEvents.isEmpty;
}
