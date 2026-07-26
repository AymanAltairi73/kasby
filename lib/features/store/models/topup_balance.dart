class TopupBalance {
  final int balanceCents;
  final String currency;
  final String status;

  TopupBalance({
    required this.balanceCents,
    required this.currency,
    required this.status,
  });

  factory TopupBalance.fromJson(Map<String, dynamic> json) {
    return TopupBalance(
      balanceCents: json['balance_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance_cents': balanceCents,
      'currency': currency,
      'status': status,
    };
  }
}
