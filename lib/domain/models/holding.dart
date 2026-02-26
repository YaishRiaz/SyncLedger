class Holding {
  const Holding({
    required this.symbol,
    required this.qty,
    required this.updatedAtMs,
    this.profileId,
  });

  final String symbol;
  final int qty;
  final int updatedAtMs;
  final String? profileId;

  Holding copyWith({int? qty, int? updatedAtMs}) {
    return Holding(
      symbol: symbol,
      qty: qty ?? this.qty,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      profileId: profileId,
    );
  }
}
