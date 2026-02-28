import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/models/parsed_transaction.dart';

abstract final class AutoTagger {
  static const _rules = <String, CategoryTag>{
    'uber eats': CategoryTag.food,
    'uber': CategoryTag.transport,
    'pickme': CategoryTag.transport,
    'grab': CategoryTag.transport,
    'fuel': CategoryTag.transport,
    'ceypetco': CategoryTag.transport,
    'ioc': CategoryTag.transport,

    'keells': CategoryTag.food,
    'cargills': CategoryTag.food,
    'arpico': CategoryTag.food,
    'pizza': CategoryTag.food,
    'kfc': CategoryTag.food,
    'mcdonald': CategoryTag.food,
    'restaurant': CategoryTag.food,
    'food': CategoryTag.food,

    'dialog': CategoryTag.utilities,
    'mobitel': CategoryTag.utilities,
    'leco': CategoryTag.utilities,
    'ceb': CategoryTag.utilities,
    'water': CategoryTag.utilities,
    'electricity': CategoryTag.utilities,

    'health': CategoryTag.healthcare,
    'hospital': CategoryTag.healthcare,
    'pharmacy': CategoryTag.healthcare,
    'cfc health': CategoryTag.healthcare,
    'medical': CategoryTag.healthcare,

    'netflix': CategoryTag.entertainment,
    'spotify': CategoryTag.entertainment,
    'youtube': CategoryTag.entertainment,
    'cinema': CategoryTag.entertainment,

    'salary': CategoryTag.salary,
    'payroll': CategoryTag.salary,
  };

  static CategoryTag categorize(ParsedTransaction txn) {
    if (txn.type == TransactionType.fee) return CategoryTag.fees;
    if (txn.type == TransactionType.transfer) return CategoryTag.transfers;
    if (txn.type == TransactionType.investment) return CategoryTag.investment;

    final merchantLower = (txn.merchant ?? '').toLowerCase();
    final refLower = (txn.reference ?? '').toLowerCase();
    final combined = '$merchantLower $refLower';

    for (final entry in _rules.entries) {
      if (combined.contains(entry.key)) {
        return entry.value;
      }
    }

    return CategoryTag.other;
  }
}
