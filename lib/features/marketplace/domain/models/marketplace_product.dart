import 'marketplace_product_variant.dart';

/// Product line under a brand (e.g. "UC" under PUBG Mobile).
/// Pricing lives on [MarketplaceProductVariant].
class MarketplaceProduct {
  final String id;
  final String brandId;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final String imageUrl;
  final List<String> galleryUrls;
  final double rating;
  final int reviewCount;
  final bool isPopular;
  final bool isActive;
  final String instructionsEn;
  final String instructionsAr;
  final String termsEn;
  final String termsAr;
  final String deliveryInfoEn;
  final String deliveryInfoAr;
  final List<String> paymentMethods;
  final List<MarketplaceProductVariant> variants;

  const MarketplaceProduct({
    required this.id,
    required this.brandId,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn = '',
    this.descriptionAr = '',
    required this.imageUrl,
    this.galleryUrls = const [],
    this.rating = 4.5,
    this.reviewCount = 0,
    this.isPopular = false,
    this.isActive = true,
    this.instructionsEn = '',
    this.instructionsAr = '',
    this.termsEn = '',
    this.termsAr = '',
    this.deliveryInfoEn = '',
    this.deliveryInfoAr = '',
    this.paymentMethods = const ['wallet', 'ksp'],
    this.variants = const [],
  });

  MarketplaceProductVariant? get defaultVariant {
    if (variants.isEmpty) return null;
    final featured = variants.where((v) => v.isFeatured && v.isActive);
    if (featured.isNotEmpty) return featured.first;
    return variants.where((v) => v.isActive).firstOrNull;
  }

  double? get lowestWalletPrice {
    final active = variants.where((v) => v.isActive);
    if (active.isEmpty) return null;
    return active.map((v) => v.walletPrice).reduce((a, b) => a < b ? a : b);
  }

  String localizedName(String locale) =>
      locale.startsWith('ar') ? nameAr : nameEn;

  String localizedDescription(String locale) =>
      locale.startsWith('ar') ? descriptionAr : descriptionEn;

  String localizedInstructions(String locale) =>
      locale.startsWith('ar') ? instructionsAr : instructionsEn;

  String localizedTerms(String locale) =>
      locale.startsWith('ar') ? termsAr : termsEn;

  String localizedDeliveryInfo(String locale) =>
      locale.startsWith('ar') ? deliveryInfoAr : deliveryInfoEn;

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    return MarketplaceProduct(
      id: json['id'] as String,
      brandId: json['brand_id'] as String,
      categoryId: json['category_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      descriptionEn: json['description_en'] as String? ?? '',
      descriptionAr: json['description_ar'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      galleryUrls: (json['gallery_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: json['review_count'] as int? ?? 0,
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      instructionsEn: json['instructions_en'] as String? ?? '',
      instructionsAr: json['instructions_ar'] as String? ?? '',
      termsEn: json['terms_en'] as String? ?? '',
      termsAr: json['terms_ar'] as String? ?? '',
      deliveryInfoEn: json['delivery_info_en'] as String? ?? '',
      deliveryInfoAr: json['delivery_info_ar'] as String? ?? '',
      paymentMethods: (json['payment_methods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['wallet', 'ksp'],
      variants: (json['variants'] as List<dynamic>?)
              ?.map(
                (e) => MarketplaceProductVariant.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand_id': brandId,
        'category_id': categoryId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
        'image_url': imageUrl,
        'gallery_urls': galleryUrls,
        'rating': rating,
        'review_count': reviewCount,
        'is_popular': isPopular,
        'is_active': isActive,
        'instructions_en': instructionsEn,
        'instructions_ar': instructionsAr,
        'terms_en': termsEn,
        'terms_ar': termsAr,
        'delivery_info_en': deliveryInfoEn,
        'delivery_info_ar': deliveryInfoAr,
        'payment_methods': paymentMethods,
        'variants': variants.map((v) => v.toJson()).toList(),
      };

  MarketplaceProduct copyWith({
    String? brandId,
    String? categoryId,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? imageUrl,
    List<String>? galleryUrls,
    double? rating,
    int? reviewCount,
    bool? isPopular,
    bool? isActive,
    String? instructionsEn,
    String? instructionsAr,
    String? termsEn,
    String? termsAr,
    String? deliveryInfoEn,
    String? deliveryInfoAr,
    List<String>? paymentMethods,
    List<MarketplaceProductVariant>? variants,
  }) {
    return MarketplaceProduct(
      id: id,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      instructionsEn: instructionsEn ?? this.instructionsEn,
      instructionsAr: instructionsAr ?? this.instructionsAr,
      termsEn: termsEn ?? this.termsEn,
      termsAr: termsAr ?? this.termsAr,
      deliveryInfoEn: deliveryInfoEn ?? this.deliveryInfoEn,
      deliveryInfoAr: deliveryInfoAr ?? this.deliveryInfoAr,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      variants: variants ?? this.variants,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
