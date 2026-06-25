enum MarketplaceStockStatus { inStock, lowStock, outOfStock }

class MarketplaceProductVariant {
  final String id;
  final String productId;
  final String nameEn;
  final String nameAr;
  final double walletPrice;
  final double? kspPrice;
  final double? originalPrice;
  final MarketplaceStockStatus stockStatus;
  final int sortOrder;
  final bool isFeatured;
  final bool isActive;
  final String providerSku;
  final String estimatedDelivery;

  const MarketplaceProductVariant({
    required this.id,
    required this.productId,
    required this.nameEn,
    required this.nameAr,
    required this.walletPrice,
    this.kspPrice,
    this.originalPrice,
    this.stockStatus = MarketplaceStockStatus.inStock,
    this.sortOrder = 0,
    this.isFeatured = false,
    this.isActive = true,
    this.providerSku = '',
    this.estimatedDelivery = 'Instant',
  });

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > walletPrice;

  int get discountPercent {
    if (!hasDiscount || originalPrice == null || originalPrice == 0) return 0;
    return (((originalPrice! - walletPrice) / originalPrice!) * 100).round();
  }

  bool get isAvailable => stockStatus != MarketplaceStockStatus.outOfStock;

  String localizedName(String locale) =>
      locale.startsWith('ar') ? nameAr : nameEn;

  factory MarketplaceProductVariant.fromJson(Map<String, dynamic> json) {
    return MarketplaceProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      walletPrice: (json['wallet_price'] as num).toDouble(),
      kspPrice: (json['ksp_price'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      stockStatus: MarketplaceStockStatus.values.firstWhere(
        (s) => s.name == json['stock_status'],
        orElse: () => MarketplaceStockStatus.inStock,
      ),
      sortOrder: json['sort_order'] as int? ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      providerSku: json['provider_sku'] as String? ?? '',
      estimatedDelivery: json['estimated_delivery'] as String? ?? 'Instant',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'wallet_price': walletPrice,
        'ksp_price': kspPrice,
        'original_price': originalPrice,
        'stock_status': stockStatus.name,
        'sort_order': sortOrder,
        'is_featured': isFeatured,
        'is_active': isActive,
        'provider_sku': providerSku,
        'estimated_delivery': estimatedDelivery,
      };

  MarketplaceProductVariant copyWith({
    String? productId,
    String? nameEn,
    String? nameAr,
    double? walletPrice,
    double? kspPrice,
    double? originalPrice,
    MarketplaceStockStatus? stockStatus,
    int? sortOrder,
    bool? isFeatured,
    bool? isActive,
    String? providerSku,
    String? estimatedDelivery,
  }) {
    return MarketplaceProductVariant(
      id: id,
      productId: productId ?? this.productId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      walletPrice: walletPrice ?? this.walletPrice,
      kspPrice: kspPrice ?? this.kspPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      stockStatus: stockStatus ?? this.stockStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      providerSku: providerSku ?? this.providerSku,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
    );
  }
}
