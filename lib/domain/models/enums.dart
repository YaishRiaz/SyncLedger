enum TransactionDirection { income, expense }

enum TransactionType {
  income,
  expense,
  transfer,
  fee,
  reversal,
  investment,
}

enum InvestmentEventType { buy, sell, deposit, withdrawal }

enum ParsedStatus { parsed, needsReview, ignored }

enum DataScope { personal, family }

enum AccountType { bank, broker }

enum SyncOpType { insert, update, delete }

enum CategoryTag {
  transport,
  food,
  utilities,
  fees,
  transfers,
  healthcare,
  entertainment,
  shopping,
  salary,
  investment,
  other;

  String get displayName => switch (this) {
        transport => 'Transport',
        food => 'Food & Dining',
        utilities => 'Utilities',
        fees => 'Fees & Charges',
        transfers => 'Transfers',
        healthcare => 'Healthcare',
        entertainment => 'Entertainment',
        shopping => 'Shopping',
        salary => 'Salary',
        investment => 'Investment',
        other => 'Other',
      };
}
