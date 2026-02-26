import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/core/constants.dart';

class TransferMatchResult {
  const TransferMatchResult({
    required this.outTransaction,
    required this.inTransaction,
    required this.matchScore,
    this.feeTransaction,
  });

  final Transaction outTransaction;
  final Transaction inTransaction;
  final double matchScore;
  final Transaction? feeTransaction;
}

class TransferMatcher {
  TransferMatcher(this._db);

  final AppDatabase _db;

  Future<List<TransferMatchResult>> findMatches() async {
    final unmatched = await _db.getUnmatchedTransfers();
    final results = <TransferMatchResult>[];

    // Separate OUT transfers (NDB CEFTS Outward) and IN transfers (HNB CEFT credit)
    final outTransfers = unmatched.where((t) =>
        t.direction == 'expense' &&
        t.type == 'transfer' &&
        _isOutwardTransfer(t),).toList();

    final inTransfers = unmatched.where((t) =>
        t.direction == 'income' &&
        t.type == 'transfer' &&
        _isInwardTransfer(t),).toList();

    final feeTransactions = unmatched.where((t) =>
        t.type == 'fee' &&
        t.amount == AppConstants.transferFeeAmount,).toList();

    final matchedOutIds = <int>{};
    final matchedInIds = <int>{};

    for (final out in outTransfers) {
      TransferMatchResult? bestMatch;
      double bestScore = 0;

      for (final inTxn in inTransfers) {
        if (matchedInIds.contains(inTxn.id)) continue;

        final score = _calculateMatchScore(out, inTxn);
        if (score > bestScore && score >= 0.5) {
          Transaction? fee;
          for (final f in feeTransactions) {
            if (_isFeeForTransfer(f, out)) {
              fee = f;
              break;
            }
          }

          bestMatch = TransferMatchResult(
            outTransaction: out,
            inTransaction: inTxn,
            matchScore: score,
            feeTransaction: fee,
          );
          bestScore = score;
        }
      }

      if (bestMatch != null) {
        results.add(bestMatch);
        matchedOutIds.add(out.id);
        matchedInIds.add(bestMatch.inTransaction.id);
      }
    }

    return results;
  }

  double _calculateMatchScore(Transaction out, Transaction inTxn) {
    double score = 0;

    // Same amount: +0.4
    if ((out.amount - inTxn.amount).abs() < 0.01) {
      score += 0.4;
    } else {
      return 0; // Different amounts can't be a match
    }

    // Within 48 hours: +0.3
    final timeDiff = (out.occurredAtMs - inTxn.occurredAtMs).abs();
    final hoursDiff = timeDiff / (1000 * 60 * 60);
    if (hoursDiff <= AppConstants.transferMatchWindowHours) {
      score += 0.3;
      // Bonus for closer timestamps
      if (hoursDiff <= 1) score += 0.1;
    } else {
      return 0;
    }

    // Transfer keywords in both: +0.1
    final outRef = (out.reference ?? '').toUpperCase();
    final inRef = (inTxn.reference ?? '').toUpperCase();
    if ((outRef.contains('CEFT') || outRef.contains('TRANSFER')) &&
        (inRef.contains('CEFT') || inRef.contains('TRANSFER'))) {
      score += 0.1;
    }

    // Reference similarity (name tokens): +0.1
    if (outRef.isNotEmpty && inRef.isNotEmpty) {
      final outTokens = outRef.split(RegExp(r'[\s\-]+'));
      final inTokens = inRef.split(RegExp(r'[\s\-]+'));
      final commonTokens = outTokens
          .where((t) => t.length > 2 && inTokens.contains(t))
          .length;
      if (commonTokens > 0) {
        score += 0.1;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  bool _isOutwardTransfer(Transaction t) {
    final ref = (t.reference ?? '').toUpperCase();
    return ref.contains('CEFTS') && ref.contains('OUTWARD');
  }

  bool _isInwardTransfer(Transaction t) {
    final ref = (t.reference ?? '').toUpperCase();
    return ref.contains('CEFT');
  }

  bool _isFeeForTransfer(Transaction fee, Transaction transfer) {
    final timeDiff = (fee.occurredAtMs - transfer.occurredAtMs).abs();
    final minutesDiff = timeDiff / (1000 * 60);
    return minutesDiff <= 5; // fee should be within 5 minutes
  }

  Future<void> applyMatch(TransferMatchResult match) async {
    final groupId = await _db.createTransferGroup(match.matchScore);

    await _db.setTransferGroup(match.outTransaction.id, groupId);
    await _db.setTransferGroup(match.inTransaction.id, groupId);

    if (match.feeTransaction != null) {
      await _db.setTransferGroup(match.feeTransaction!.id, groupId);
    }

    await _db.insertTransferLink(
      transferGroupId: groupId,
      fromTransactionId: match.outTransaction.id,
      toTransactionId: match.inTransaction.id,
    );
  }

  Future<int> autoMatchAll() async {
    final matches = await findMatches();
    int count = 0;
    for (final match in matches) {
      if (match.matchScore >= 0.7) {
        await applyMatch(match);
        count++;
      }
    }
    return count;
  }
}
