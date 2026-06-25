import 'marketplace_product_variant.dart';

/// Denormalized read model for browse grids, search, and cart display.
/// Built from Category → Brand → Product → Variant hierarchy by the provider.
class MarketplaceCatalogListing {
  final String variantId;
  final String productId;
  final String brandId;
  final String categoryId;
  final String variantNameEn;
  final String variantNameAr;
  final String productNameEn;
  final String productNameAr;
  final String brandNameEn;
  final String brandNameAr;
  final String categoryNameEn;
  final String categoryNameAr;
  final String imageUrl;
  final double walletPrice;
  final double? kspPrice;
  final double? originalPrice;
  final MarketplaceStockStatus stockStatus;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isPopular;
  final bool isActive;
  final String estimatedDelivery;

  const MarketplaceCatalogListing({
    required this.variantId,
    required this.productId,
    required this.brandId,
    required this.categoryId,
    required this.variantNameEn,
    required this.variantNameAr,
    required this.productNameEn,
    required this.productNameAr,
    required this.brandNameEn,
    required this.brandNameAr,
    required this.categoryNameEn,
    required this.categoryNameAr,
    required this.imageUrl,
    required this.walletPrice,
    this.kspPrice,
    this.originalPrice,
    this.stockStatus = MarketplaceStockStatus.inStock,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.isPopular = false,
    this.isActive = true,
    this.estimatedDelivery = 'Instant',
  });

  String get id => variantId;

  String get displayNameEn => '$brandNameEn — $variantNameEn';

  String get displayNameAr => '$brandNameAr — $variantNameAr';

  String localizedDisplayName(String locale) =>
      locale.startsWith('ar') ? displayNameAr : displayNameEn;

  String localizedVariantName(String locale) =>
      locale.startsWith('ar') ? variantNameAr : variantNameEn;

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > walletPrice;

  int get discountPercent {
    if (!hasDiscount || originalPrice == null || originalPrice == 0) return 0;
    return (((originalPrice! - walletPrice) / originalPrice!) * 100).round();
  }

  bool get isAvailable => stockStatus != MarketplaceStockStatus.outOfStock;

  factory MarketplaceCatalogListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceCatalogListing(
      variantId: json['variant_id'] as String,
      productId: json['product_id'] as String,
      brandId: json['brand_id'] as String,
      categoryId: json['category_id'] as String,
      variantNameEn: json['variant_name_en'] as String,
      variantNameAr: json['variant_name_ar'] as String,
      productNameEn: json['product_name_en'] as String,
      productNameAr: json['product_name_ar'] as String,
      brandNameEn: json['brand_name_en'] as String,
      brandNameAr: json['brand_name_ar'] as String,
      categoryNameEn: json['category_name_en'] as String,
      categoryNameAr: json['category_name_ar'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      walletPrice: (json['wallet_price'] as num).toDouble(),
      kspPrice: (json['ksp_price'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      stockStatus: MarketplaceStockStatus.values.firstWhere(
        (s) => s.name == json['stock_status'],
        orElse: () => MarketplaceStockStatus.inStock,
      ),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: json['review_count'] as int? ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      estimatedDelivery: json['estimated_delivery'] as String? ?? 'Instant',
    );
  }
}
