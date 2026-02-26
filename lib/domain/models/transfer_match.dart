class TransferMatch {
  const TransferMatch({
    required this.outTransactionIndex,
    required this.inTransactionIndex,
    required this.matchScore,
    this.feeTransactionIndex,
  });

  final int outTransactionIndex;
  final int inTransactionIndex;
  final int? feeTransactionIndex;
  final double matchScore;

  @override
  String toString() =>
      'TransferMatch(out=$outTransactionIndex, in=$inTransactionIndex, '
      'score=$matchScore)';
}
