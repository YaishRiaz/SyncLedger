import 'package:drift/drift.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text().nullable()(); // Profile this account belongs to
  TextColumn get name => text()();
  TextColumn get institution => text()();
  TextColumn get type => text()(); // bank, broker
  TextColumn get last4 => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  RealColumn get balance => real().nullable()();
  IntColumn get balanceUpdatedAtMs => integer().nullable()();
}

class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get displayName => text()();
}

class SmsMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()();
  TextColumn get bodyEncryptedOrNull => text().nullable()();
  IntColumn get receivedAtMs => integer()();
  TextColumn get hash => text().withLength(min: 32, max: 32).unique()();
  TextColumn get parsedStatus => text()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get occurredAtMs => integer()();
  TextColumn get direction => text()(); // income, expense
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('LKR'))();
  TextColumn get merchant => text().nullable()();
  TextColumn get reference => text().nullable()();
  TextColumn get type => text()(); // income, expense, transfer, fee, reversal, investment
  TextColumn get category => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
  IntColumn get sourceSmsId => integer().nullable()();
  IntColumn get transferGroupId => integer().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  TextColumn get scope => text().withDefault(const Constant('personal'))();
}

class TransferGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAtMs => integer()();
  RealColumn get matchScore => real()();
}

class TransferLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transferGroupId => integer()();
  IntColumn get fromTransactionId => integer()();
  IntColumn get toTransactionId => integer()();
}

class InvestmentEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text()();
  IntColumn get occurredAtMs => integer()();
  TextColumn get eventType => text()(); // buy, sell, deposit, withdrawal
  TextColumn get symbol => text()();
  IntColumn get qty => integer()();
  IntColumn get sourceSmsId => integer().nullable()();
  TextColumn get scope => text().withDefault(const Constant('personal'))();
}

@DataClassName('Position')
class Positions extends Table {
  TextColumn get profileId => text()();
  TextColumn get symbol => text()();
  IntColumn get qty => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {profileId, symbol};
}

/// Stock price data from CSE (Colombo Stock Exchange)
/// Stores historical end-of-day prices for stocks
class StockPrices extends Table {
  TextColumn get symbol => text()(); // Stock ticker (e.g., "ASPIDF", "COMB")
  IntColumn get priceDate => integer()(); // Date in YYYYMMDD format (e.g., 20260228)
  RealColumn get closePrice => real()(); // EOD close price in LKR
  RealColumn get highPrice => real().nullable()();
  RealColumn get lowPrice => real().nullable()();
  RealColumn get openPrice => real().nullable()();
  IntColumn get volume => integer().nullable()();
  IntColumn get fetchedAtMs => integer()(); // Timestamp when price was fetched

  @override
  Set<Column> get primaryKey => {symbol, priceDate};
}

/// Daily portfolio value tracking
/// Stores calculated portfolio value for each user profile
class PortfolioValue extends Table {
  TextColumn get profileId => text()(); // User profile
  IntColumn get valueDate => integer()(); // Date in YYYYMMDD format (e.g., 20260228)
  RealColumn get totalValue => real()(); // Total portfolio value in LKR
  RealColumn get dayChangeAmount => real().nullable()(); // Change from previous day
  RealColumn get dayChangePercent => real().nullable()(); // % change from previous day
  IntColumn get calculatedAtMs => integer()(); // Timestamp when calculated

  @override
  Set<Column> get primaryKey => {profileId, valueDate};
}

class Changes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  IntColumn get seq => integer()();
  IntColumn get createdAtMs => integer()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get opType => text()();
  TextColumn get payloadCiphertext => text().nullable()();
  TextColumn get payloadNonce => text().nullable()();
  TextColumn get payloadMac => text().nullable()();
}

class AutoTagRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get merchantKeyword => text()();
  TextColumn get category => text()();
}
