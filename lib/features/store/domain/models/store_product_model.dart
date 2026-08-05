class StoreProductModel {
  final String id;
  final String categoryId;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String? imageUrl;
  final double walletPrice;
  final double? kspPrice;
  final double? originalPrice;
  final int discountPercent;
  final bool isActive;
  final bool isFeatured;
  final bool isTopSelling;
  final bool isNew;
  final int sortOrder;
  final int availableStock;

  const StoreProductModel({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.imageUrl,
    required this.walletPrice,
    this.kspPrice,
    this.originalPrice,
    this.discountPercent = 0,
    this.isActive = true,
    this.isFeatured = false,
    this.isTopSelling = false,
    this.isNew = false,
    this.sortOrder = 0,
    this.availableStock = 0,
  });

  factory StoreProductModel.fromJson(
    Map<String, dynamic> json, {
    int stock = 0,
  }) {
    return StoreProductModel(
      id: json['id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      descriptionAr: json['description_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      walletPrice: (json['wallet_price'] as num?)?.toDouble() ?? 0.0,
      kspPrice: (json['ksp_price'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      isTopSelling: json['is_top_selling'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      availableStock: stock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'image_url': imageUrl,
      'wallet_price': walletPrice,
      'ksp_price': kspPrice,
      'original_price': originalPrice,
      'discount_percent': discountPercent,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_top_selling': isTopSelling,
      'is_new': isNew,
      'sort_order': sortOrder,
    };
  }

  bool get inStock => availableStock > 0;
}
