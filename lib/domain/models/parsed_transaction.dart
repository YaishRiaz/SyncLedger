import 'package:sync_ledger/domain/models/enums.dart';

class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.direction,
    required this.occurredAtMs,
    required this.type,
    this.currency = 'LKR',
    this.accountHint,
    this.merchant,
    this.reference,
    this.balance,
    this.category = CategoryTag.other,
    this.confidence = 1.0,
    this.sourceSmsSender,
  });

  final double amount;
  final String currency;
  final TransactionDirection direction;
  final int occurredAtMs;
  final String? accountHint;
  final String? merchant;
  final String? reference;
  final double? balance;
  final TransactionType type;
  final CategoryTag category;
  final double confidence;
  final String? sourceSmsSender;

  DateTime get occurredAt =>
      DateTime.fromMillisecondsSinceEpoch(occurredAtMs);

  ParsedTransaction copyWith({
    double? amount,
    String? currency,
    TransactionDirection? direction,
    int? occurredAtMs,
    String? accountHint,
    String? merchant,
    String? reference,
    double? balance,
    TransactionType? type,
    CategoryTag? category,
    double? confidence,
    String? sourceSmsSender,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      direction: direction ?? this.direction,
      occurredAtMs: occurredAtMs ?? this.occurredAtMs,
      accountHint: accountHint ?? this.accountHint,
      merchant: merchant ?? this.merchant,
      reference: reference ?? this.reference,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      sourceSmsSender: sourceSmsSender ?? this.sourceSmsSender,
    );
  }

  @override
  String toString() =>
      'ParsedTransaction(${direction.name} $currency $amount ${type.name})';
}
