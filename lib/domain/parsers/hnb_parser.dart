import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/domain/models/parsed_transaction.dart';
import 'package:sync_ledger/domain/parsers/sms_parser.dart';
import 'package:sync_ledger/domain/parsers/parse_utils.dart';

class HnbParser implements SmsParser {
  // Pattern 1: Credit with "LKR X credited to Ac No:..." format (most common)
  // "LKR 4,000.00 credited to Ac No:02702XXXXX71 on 22/02/26 20:23:11 Reason:CEFT-YAISH Bal:LKR 5,255.27"
  // "LKR 256,960.73 credited to Ac No:02702XXXXX71 on 25/02/26 09:52:14 Reason:IFS R D INTER Bal:LKR 261,214.85"
  static final _creditPattern = RegExp(
    r'LKR\s+([\d,]+\.?\d*)\s+credited\s+to\s+Ac\s*No[:\s]*(\S+)\s+on\s+(\d{2}/\d{2}/\d{2})\s+(\d{2}:\d{2}:\d{2})\s*(?:Reason[:\s]*(.+?))?\s*(?:Bal[:\s]*LKR\s*([\d,]+\.?\d*))?',
    caseSensitive: false,
  );

  // Pattern 2: Older format "You received LKR X from NAME"
  // "You received LKR 100,000 from M R FAROOK"
  static final _receivedPattern = RegExp(
    r'You\s+received\s+LKR\s+([\d,]+\.?\d*)\s+from\s+(.+)',
    caseSensitive: false,
  );

  // Pattern 3: Card/Online debit (supports LKR and foreign currencies like USD)
  // "HNB SMS ALERT:INTERNET, Account:0270***4971,Location:UBER, LK,Amount(Approx.):279.00 LKR,Av.Bal:1848.91"
  // "HNB SMS ALERT:INTERNET, Account:0270***4971,Location:NETFLIX, US,Amount(Approx.):15.99 USD,Av.Bal:1848.91"
  static final _debitAlertPattern = RegExp(
    r'HNB\s+SMS\s+ALERT[:\s]*(\w+),?\s*Account[:\s]*(\S+),?\s*Location[:\s]*(.+?),?\s*Amount\s*\(?Approx\.?\)?[:\s]*([\d,]+\.?\d*)\s*(LKR|USD|EUR|GBP|SGD|AUD|CAD|JPY|AED|CHF),?\s*Av\.?\s*Bal[:\s]*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  // Pattern 4: Credit adjustment/reversal format
  // "A Transaction for LKR 2,860.00 has been credit ed to Ac No:02702XXXXX71 on 16/02/26 15:33:08 .Remarks :ADJ FOR ECOM/UBER EATS02/12.Bal: LKR 4,157.19"
  static final _adjustmentCreditPattern = RegExp(
    r'A\s+Transaction\s+for\s+LKR\s+([\d,]+\.?\d*)\s+has\s+been\s+credit\s*ed.*?Ac\s*No[:\s]*(\S+)\s+on\s+(\d{2}/\d{2}/\d{2})\s+(\d{2}:\d{2}:\d{2}).*?(?:Remarks?\s*[:\s]*(.+?))?Bal[:\s]*LKR\s*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  // Pattern 5: Debit (fees/charges)
  // "A Transaction for LKR 25.00 has been debit ed ... Remarks :Finacle Alert Charges"
  static final _feePattern = RegExp(
    r'(?:A\s+)?Transaction\s+for\s+LKR\s+([\d,]+\.?\d*)\s+has\s+been\s+debit\s*ed.*?Remarks?\s*[:\s]*(.+)',
    caseSensitive: false,
  );

  // Pattern 4: Reversal
  // "HNB TRANSACTION REVERSAL ... Amount:548.69 LKR"
  static final _reversalPattern = RegExp(
    r'HNB\s+TRANSACTION\s+REVERSAL.*?Amount[:\s]*([\d,]+\.?\d*)\s*LKR',
    caseSensitive: false,
  );

  @override
  bool canParse(String sender, String body) {
    final s = sender.toUpperCase().replaceAll('+', ' ').trim();
    return s.contains('HNB') && !s.contains('NDB');
  }

  @override
  ParseResult parse(String sender, String body, int receivedAtMs) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Try credit (main pattern) - works for both CEFT and salary
    var match = _creditPattern.firstMatch(normalized);
    if (match != null) {
      return _parseCredit(match, receivedAtMs);
    }

    // Try "You received" format
    match = _receivedPattern.firstMatch(normalized);
    if (match != null) {
      return _parseReceived(match, receivedAtMs);
    }

    // Try adjustment credit
    match = _adjustmentCreditPattern.firstMatch(normalized);
    if (match != null) {
      return _parseAdjustmentCredit(match, receivedAtMs);
    }

    // Try card/online debit
    match = _debitAlertPattern.firstMatch(normalized);
    if (match != null) {
      return _parseDebitAlert(match, receivedAtMs);
    }

    // Try reversal before fee (reversal also has amount)
    match = _reversalPattern.firstMatch(normalized);
    if (match != null) {
      return _parseReversal(match, receivedAtMs);
    }

    // Try fee/charge
    match = _feePattern.firstMatch(normalized);
    if (match != null) {
      return _parseFee(match, receivedAtMs);
    }

    return const ParseResult();
  }

  ParseResult _parseReceived(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final from = match.group(2)?.trim();

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: receivedAtMs,
          type: TransactionType.income,
          reference: 'From $from',
          confidence: 0.90,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  ParseResult _parseAdjustmentCredit(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final account = match.group(2);
    final dateStr = match.group(3)!;
    final timeStr = match.group(4)!;
    final remarks = match.group(5)?.trim();
    final balance = match.group(6) != null
        ? ParseUtils.parseAmount(match.group(6)!)
        : null;

    final occurredAt = ParseUtils.parseDateTimeSL(dateStr, timeStr);
    final ts = occurredAt?.millisecondsSinceEpoch ?? receivedAtMs;

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: ts,
          type: TransactionType.income,
          accountHint: ParseUtils.extractLast2(account),
          reference: remarks,
          balance: balance,
          confidence: 0.90,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  ParseResult _parseCredit(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final account = match.group(2);
    final dateStr = match.group(3)!;
    final timeStr = match.group(4)!;
    final reason = match.group(5)?.trim();
    final balance = match.group(6) != null
        ? ParseUtils.parseAmount(match.group(6)!)
        : null;

    final occurredAt = ParseUtils.parseDateTimeSL(dateStr, timeStr);
    final ts = occurredAt?.millisecondsSinceEpoch ?? receivedAtMs;

    final isCeft = reason != null &&
        reason.toUpperCase().contains('CEFT');

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: ts,
          type: isCeft ? TransactionType.transfer : TransactionType.income,
          accountHint: ParseUtils.extractLast2(account),
          reference: reason,
          balance: balance,
          confidence: 0.95,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  ParseResult _parseDebitAlert(RegExpMatch match, int receivedAtMs) {
    final channel = match.group(1); // INTERNET, POS, etc.
    final account = match.group(2);
    final location = match.group(3)?.trim();
    final amount = ParseUtils.parseAmount(match.group(4)!);
    final currency = (match.group(5) ?? 'LKR').toUpperCase();
    final balance = ParseUtils.parseAmount(match.group(6)!);

    final merchant = _cleanMerchant(location);

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          currency: currency,
          direction: TransactionDirection.expense,
          occurredAtMs: receivedAtMs,
          type: TransactionType.expense,
          accountHint: ParseUtils.extractLast2(account),
          merchant: merchant,
          reference: channel,
          // Av.Bal is always the LKR available balance, even for foreign-currency txns
          balance: balance,
          confidence: 0.90,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  ParseResult _parseFee(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);
    final remarks = match.group(2)?.trim();

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.expense,
          occurredAtMs: receivedAtMs,
          type: TransactionType.fee,
          reference: remarks,
          confidence: 0.85,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  ParseResult _parseReversal(RegExpMatch match, int receivedAtMs) {
    final amount = ParseUtils.parseAmount(match.group(1)!);

    return ParseResult(
      transactions: [
        ParsedTransaction(
          amount: amount,
          direction: TransactionDirection.income,
          occurredAtMs: receivedAtMs,
          type: TransactionType.reversal,
          reference: 'TRANSACTION REVERSAL',
          confidence: 0.90,
          sourceSmsSender: 'HNB',
        ),
      ],
    );
  }

  String? _cleanMerchant(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Remove trailing country codes like ", LK" or ", SG"
    return raw.replaceAll(RegExp(r',?\s*[A-Z]{2}\s*$'), '').trim();
  }
}
