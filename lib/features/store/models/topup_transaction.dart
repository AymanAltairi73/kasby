class TopupTransaction {
  final String id;
  final String type; // deposit, subscription, order_fee, order_principal, refund, credit
  final String description;
  final int deltaCents;
  final int balanceAfterCents;
  final String? ref;
  final String? orderId;
  final DateTime? createdAt;

  TopupTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.deltaCents,
    required this.balanceAfterCents,
    this.ref,
    this.orderId,
    this.createdAt,
  });

  factory TopupTransaction.fromJson(Map<String, dynamic> json) {
    return TopupTransaction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deltaCents: json['delta_cents'] as int? ?? 0,
      balanceAfterCents: json['balance_after_cents'] as int? ?? 0,
      ref: json['ref'] as String?,
      orderId: json['order_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'delta_cents': deltaCents,
      'balance_after_cents': balanceAfterCents,
      'ref': ref,
      'order_id': orderId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
