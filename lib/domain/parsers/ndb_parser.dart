import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/models/parsed_transaction.dart';
import 'package:sync_ledger/domain/parsers/sms_parser.dart';
import 'package:sync_ledger/domain/parsers/parse_utils.dart';

class NdbParser implements SmsParser {
  // Pattern 1: Debit
  // "LKR 4,000.00 debited from AC XXXXXXXX8484 on 22 Feb 2026 20:23 as CEFTS Outward Transfer. Avl Bal 12345 Call 94112448888 for info"
  static final _debitPattern = RegExp(
    r'LKR\s+([\d,]+\.?\d*)\s+debited\s+from\s+AC\s+(\S+)\s+on\s+(\d{1,2}\s+\w+\s+\d{4})\s+(\d{2}:\d{2})\s+as\s+(.*?)\s*(?:Avl\s+Bal\s+([\d,]+\.?\d*))?\s*(?:Call\s+\d+.*)?$',
    caseSensitive: false,
  );

  // Pattern 2: Credit
  // "LKR 100,000.00 credited to AC XXXXXXXX8484 on 22 Feb 2026 09:00 as Mobile Banking TXN. Avl Bal 12345 Call 94112448888 for info"
  static final _creditPattern = RegExp(
    r'LKR\s+([\d,]+\.?\d*)\s+credited\s+to\s+AC\s+(\S+)\s+on\s+(\d{1,2}\s+\w+\s+\d{4})\s+(\d{2}:\d{2})\s+as\s+(.*?)\s*(?:Avl\s+Bal\s+([\d,]+\.?\d*))?\s*(?:Call\s+\d+.*)?$',
    caseSensitive: false,
  );

  // Pattern 3: POS Reversal credit (different structure)
  // "A reversal for POS TXN of LKR 722.40 credited to AC XXXXXXXX8484 on 22 Feb 2026 10:15. Avl Bal 12345 Call 94112448888 for info"
  static final _reversalPattern = RegExp(
    r'A\s+reversal.*?LKR\s+([\d,]+\.?\d*)\s+credited\s+to\s+AC\s+(\S+)\s+on\s+(\d{1,2}\s+\w+\s+\d{4})\s+(\d{2}:\d{2}).*?(?:Avl\s+Bal\s+([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase().replaceAll('+', ' ').trim();
    return s.contains('NDB');
  }

  @override
  ParseResult parse(String sender, String body, int receivedAtMs) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Try debit
    var match = _debitPattern.firstMatch(normalized);
    if (match != null) {
      return _parseDebit(match, receivedAtMs);
    }

    // Try credit
    match = _creditPattern.firstMatch(normalized);
    if (match != null) {
      return _parseCredit(match, receivedAtMs);
    }

    // Try reversal
    match = _reversalPattern.firstMatch(normalized);
    if (match != null) {
      return _parseReversal(match, receivedAtMs);
    }

    return const ParseResult();
  }

  ParseResult _parseDebit(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final account = match.group(2);
    final dateStr = match.group(3)!;
    final timeStr = match.group(4)!;
    final description = _cleanDescription(match.group(5) ?? '');
    final balance = match.group(6) != null
        ? ParseUtils.parseAmount(match.group(6)!)
        : null;

    final occurredAt = ParseUtils.parseDateTimeNdb(dateStr, timeStr);
    final ts = occurredAt?.millisecondsSinceEpoch ?? receivedAtMs;

    final descUpper = description.toUpperCase();

    TransactionType type;
    String? merchant;
    final String reference = description;

    if (descUpper.contains('CEFTS') &&
        descUpper.contains('OUTWARD TRANSFER')) {
      type = TransactionType.transfer;
    } else if (descUpper.contains('CEFTS') &&
        descUpper.contains('TRANSFER CHARGES')) {
      type = TransactionType.fee;
    } else if (descUpper.contains('CHARGES') ||
        descUpper.contains('FEE')) {
      type = TransactionType.fee;
    } else {
      type = TransactionType.expense;
      merchant = _extractMerchant(description);
    }

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.expense,
          occurredAtMs: ts,
          type: type,
          accountHint: ParseUtils.extractLast2(account),
          merchant: merchant,
          reference: reference,
          balance: balance,
          confidence: 0.95,
          sourceSmsSender: 'NDB',
        ),
      ],
    );
  }

  ParseResult _parseCredit(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final account = match.group(2);
    final dateStr = match.group(3)!;
    final timeStr = match.group(4)!;
    final description = _cleanDescription(match.group(5) ?? '');
    final balance = match.group(6) != null
        ? ParseUtils.parseAmount(match.group(6)!)
        : null;

    final occurredAt = ParseUtils.parseDateTimeNdb(dateStr, timeStr);
    final ts = occurredAt?.millisecondsSinceEpoch ?? receivedAtMs;

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: ts,
          type: TransactionType.income,
          accountHint: ParseUtils.extractLast2(account),
          reference: description,
          balance: balance,
          confidence: 0.95,
          sourceSmsSender: 'NDB',
        ),
      ],
    );
  }

  ParseResult _parseReversal(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final account = match.group(2);
    final dateStr = match.group(3)!;
    final timeStr = match.group(4)!;
    final balance = match.group(5) != null
        ? ParseUtils.parseAmount(match.group(5)!)
        : null;

    final occurredAt = ParseUtils.parseDateTimeNdb(dateStr, timeStr);
    final ts = occurredAt?.millisecondsSinceEpoch ?? receivedAtMs;

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: ts,
          type: TransactionType.reversal,
          accountHint: ParseUtils.extractLast2(account),
          reference: 'POS Reversal',
          balance: balance,
          confidence: 0.95,
          sourceSmsSender: 'NDB',
        ),
      ],
    );
  }

  /// Remove trailing ". " or "." from description captured before Avl Bal
  String _cleanDescription(String raw) {
    return raw.replaceAll(RegExp(r'[.\s]+$'), '').trim();
  }

  String? _extractMerchant(String description) {
    final atMatch =
        RegExp(r'\bat\s+(.+)', caseSensitive: false).firstMatch(description);
    if (atMatch != null) {
      return atMatch.group(1)?.trim();
    }
    return null;
  }
}
