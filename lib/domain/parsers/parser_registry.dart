import 'package:sync_ledger/domain/parsers/sms_parser.dart';
import 'package:sync_ledger/domain/parsers/hnb_parser.dart';
import 'package:sync_ledger/domain/parsers/ndb_parser.dart';
import 'package:sync_ledger/domain/parsers/cds_parser.dart';

class ParserRegistry {
  ParserRegistry()
      : _parsers = [
          HnbParser(),
          NdbParser(),
          CdsParser(),
        ];

  final List<SmsParser> _parsers;

  void register(SmsParser parser) => _parsers.add(parser);

  ParseResult? tryParse(String sender, String body, int receivedAtMs) {
    for (final parser in _parsers) {
      if (parser.canParse(sender, body)) {
        final result = parser.parse(sender, body, receivedAtMs);
        if (!result.isEmpty) return result;
      }
    }
    return null;
  }
}
