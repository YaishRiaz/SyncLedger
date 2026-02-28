import 'package:sync_ledger/domain/parsers/sms_parser.dart';
import 'package:sync_ledger/domain/parsers/parse_utils.dart';
import 'package:sync_ledger/domain/models/parsed_transaction.dart';
import 'package:sync_ledger/domain/models/enums.dart';

/// Generic SMS parser that works with any unknown bank.
/// Extracts common patterns: amount, date, account, balance, merchant.
/// Confidence: 0.60-0.75 (lower for generic; user should verify important transactions)
class GenericBankParser implements SmsParser {
  @override
  bool canParse(String sender, String body) {
    // Generic parser accepts any message - acts as fallback
    // Check if it looks like a financial message (contains amount or keywords)
    final normalized = body.toLowerCase();
    return normalized.contains(RegExp(
      r'(debited|credited|received|transferred|sent|payment|amount|balance)',
      caseSensitive: false,
    ));
  }

  @override
  ParseResult parse(String sender, String body, int receivedAtMs) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Try to extract amount
    final amount = ParseUtils.parseAmountFlexible(normalized);
    if (amount <= 0) {
      return const ParseResult();
    }

    // Determine direction (debit vs credit)
    final direction = _detectDirection(normalized);

    // Extract date - try to get a parsed date
    DateTime? parsedDate = _extractDate(normalized);
    if (parsedDate == null) {
      // Fallback to SMS timestamp
      parsedDate = DateTime.fromMillisecondsSinceEpoch(receivedAtMs);
    }

    // Extract account hint (last 2 digits) to match specific bank parsers
    // This prevents transaction reference numbers from being mistaken for account identifiers
    final accountHint = _extractAccountLast2(normalized);

    // Extract balance if present
    final balance = ParseUtils.extractBalance(normalized);

    // Try to extract merchant/recipient name
    final merchant = _extractMerchant(normalized);

    // Classify transaction type
    final transactionType = _classifyTransactionType(normalized);

    // Calculate confidence based on extracted data
    double confidence = 0.60; // Base confidence for generic parser
    if (amount > 0) confidence += 0.05;
    if (accountHint != null) confidence += 0.05;
    if (balance != null) confidence += 0.05;
    if (merchant != null) confidence += 0.05;
    confidence = (confidence).clamp(0.60, 0.75);

    final transaction = ParsedTransaction(
      amount: amount,
      currency: 'LKR',
      direction: direction,
      occurredAtMs: parsedDate.millisecondsSinceEpoch,
      accountHint: accountHint,
      merchant: merchant,
      balance: balance,
      type: transactionType,
      confidence: confidence,
      sourceSmsSender: _extractBankName(sender),
    );

    return ParseResult(transactions: [transaction]);
  }

  /// Detect whether transaction is debit or credit based on keywords
  TransactionDirection _detectDirection(String text) {
    final lower = text.toLowerCase();

    if (lower.contains(RegExp(r'\b(debited|paid|sent|transferred|withdrawn)\b'))) {
      return TransactionDirection.expense;
    }
    if (lower.contains(RegExp(r'\b(credited|received|deposited)\b'))) {
      return TransactionDirection.income;
    }

    // Default based on context
    return TransactionDirection.expense;
  }

  /// Extract date from various formats in the message
  DateTime? _extractDate(String text) {
    // Look for date patterns
    final datePatterns = [
      RegExp(
        r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
      ), // 22/02/26 or 22-02-2026
      RegExp(
        r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{2,4})',
        caseSensitive: false,
      ), // 22 Feb 2026
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final dateStr = match.group(0) ?? '';
          final parsed = ParseUtils.parseMultipleDateFormats(dateStr);
          if (parsed != null) {
            return parsed;
          }
        } catch (_) {
          // Try next pattern
        }
      }
    }

    return null;
  }

  /// Extract merchant or recipient name from the message
  String? _extractMerchant(String text) {
    final patterns = [
      RegExp(
        r'(?:from|to|merchant|recipient)[\s:]+([A-Za-z0-9\s&.,-]+?)(?:\s+on\s|\s+at\s|Balance|Bal|Amount|$)',
        caseSensitive: false,
      ),
      RegExp(r'([A-Z][A-Z\s]{2,20}[A-Z])\s+(?:debited|credited)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty && merchant.length > 2) {
          return merchant;
        }
      }
    }

    return null;
  }

  /// Classify transaction type based on keywords and content
  TransactionType _classifyTransactionType(String text) {
    final lower = text.toLowerCase();

    if (lower.contains(RegExp(r'\b(reversal|reversed)\b'))) {
      return TransactionType.reversal;
    }
    if (lower.contains(RegExp(r'\b(fee|charge|debit charge)\b'))) {
      return TransactionType.fee;
    }
    if (lower.contains(RegExp(r'\b(transfer|ceft|swift|trn)\b'))) {
      return TransactionType.transfer;
    }
    if (lower.contains(RegExp(r'\b(salary|payroll|disbursement)\b'))) {
      return TransactionType.income;
    }

    // Default to income/expense based on direction
    if (text.toLowerCase().contains(RegExp(r'\b(debited|paid|withdrawn)\b'))) {
      return TransactionType.expense;
    }

    return TransactionType.income;
  }

  /// Extract the last 2 digits from an account number in the message.
  /// Looks for patterns like "AC XXXXXXXX1234" or "Account: 1234567890"
  /// and extracts the last 2 digits to match HNB/NDB parser behavior.
  String? _extractAccountLast2(String text) {
    // Look for account number patterns before any reference numbers
    final patterns = [
      RegExp(r'AC(?:OUNT)?\s*(?:NO\.?|:)?\s*(\S{6,}?)(?:\s|$)', caseSensitive: false),
      RegExp(r'(?:from|to|account)\s+(\d{6,})(?:\s|$)', caseSensitive: false),
      RegExp(r'Ac\s*No[:\s]*(\S+?)(?:\s+on\s|\s|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final account = match.group(1);
        if (account != null) {
          return ParseUtils.extractLast2(account);
        }
      }
    }

    return null;
  }

  /// Extract bank name from sender ID
  String _extractBankName(String sender) {
    final normalized = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (normalized.contains('HNB')) return 'HNB';
    if (normalized.contains('NDB')) return 'NDB';
    if (normalized.contains('BOC')) return 'BOC';
    if (normalized.contains('HSBC')) return 'HSBC';
    if (normalized.contains('NTB')) return 'NTB';
    if (normalized.contains('COMBANK') || normalized.contains('COMMERCIAL')) {
      return 'COMBANK';
    }
    if (normalized.contains('SEYLAN')) return 'SEYLAN';
    if (normalized.contains('SAMPATH')) return 'SAMPATH';

    return 'UNKNOWN';
  }
}
