enum MarketplacePromotionType {
  banner,
  discount,
  coupon,
  campaign,
  flashSale,
  dailyDeal,
  weekendDeal,
  limitedTimeOffer,
  featuredOffer,
}

class MarketplacePromotion {
  final String id;
  final MarketplacePromotionType type;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? imageUrl;
  final String? actionRoute;
  final double? discountPercent;
  final String? couponCode;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final int sortOrder;

  const MarketplacePromotion({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.imageUrl,
    this.actionRoute,
    this.discountPercent,
    this.couponCode,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.sortOrder = 0,
  });

  String localizedTitle(String locale) =>
      locale.startsWith('ar') ? titleAr : titleEn;

  String? localizedDescription(String locale) {
    if (locale.startsWith('ar')) return descriptionAr;
    return descriptionEn;
  }

  factory MarketplacePromotion.fromJson(Map<String, dynamic> json) {
    return MarketplacePromotion(
      id: json['id'] as String,
      type: MarketplacePromotionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MarketplacePromotionType.banner,
      ),
      titleEn: json['title_en'] as String,
      titleAr: json['title_ar'] as String,
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      actionRoute: json['action_route'] as String?,
      discountPercent: (json['discount_percent'] as num?)?.toDouble(),
      couponCode: json['coupon_code'] as String?,
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title_en': titleEn,
        'title_ar': titleAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
        'image_url': imageUrl,
        'action_route': actionRoute,
        'discount_percent': discountPercent,
        'coupon_code': couponCode,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  MarketplacePromotion copyWith({
    String? id,
    MarketplacePromotionType? type,
    String? titleEn,
    String? titleAr,
    String? descriptionEn,
    String? descriptionAr,
    String? imageUrl,
    String? actionRoute,
    double? discountPercent,
    String? couponCode,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
    int? sortOrder,
  }) {
    return MarketplacePromotion(
      id: id ?? this.id,
      type: type ?? this.type,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      imageUrl: imageUrl ?? this.imageUrl,
      actionRoute: actionRoute ?? this.actionRoute,
      discountPercent: discountPercent ?? this.discountPercent,
      couponCode: couponCode ?? this.couponCode,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
