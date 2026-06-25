enum MarketplaceCouponType { percentage, fixedAmount, freeDelivery }

class MarketplaceCoupon {
  final String id;
  final String code;
  final MarketplaceCouponType type;
  final double value;
  final double? minOrderAmount;
  final double? maxDiscount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int? usageLimit;
  final int usageCount;
  final bool isActive;
  final String? campaignId;

  const MarketplaceCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minOrderAmount,
    this.maxDiscount,
    this.startsAt,
    this.expiresAt,
    this.usageLimit,
    this.usageCount = 0,
    this.isActive = true,
    this.campaignId,
  });

  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    if (usageLimit != null && usageCount >= usageLimit!) return false;
    return true;
  }

  double calculateDiscount(double subtotal) {
    if (!isValid) return 0;
    if (minOrderAmount != null && subtotal < minOrderAmount!) return 0;
    double discount;
    switch (type) {
      case MarketplaceCouponType.percentage:
        discount = subtotal * (value / 100);
      case MarketplaceCouponType.fixedAmount:
        discount = value;
      case MarketplaceCouponType.freeDelivery:
        discount = 0;
    }
    if (maxDiscount != null && discount > maxDiscount!) {
      discount = maxDiscount!;
    }
    return discount.clamp(0, subtotal);
  }

  factory MarketplaceCoupon.fromJson(Map<String, dynamic> json) {
    return MarketplaceCoupon(
      id: json['id'] as String,
      code: json['code'] as String,
      type: MarketplaceCouponType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MarketplaceCouponType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      usageLimit: json['usage_limit'] as int?,
      usageCount: json['usage_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      campaignId: json['campaign_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'type': type.name,
        'value': value,
        'min_order_amount': minOrderAmount,
        'max_discount': maxDiscount,
        'starts_at': startsAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'usage_limit': usageLimit,
        'usage_count': usageCount,
        'is_active': isActive,
        'campaign_id': campaignId,
      };
}
