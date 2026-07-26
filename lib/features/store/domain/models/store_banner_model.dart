class StoreBannerModel {
  final String id;
  final String? titleAr;
  final String? titleEn;
  final String imageUrl;
  final String? actionUrl;
  final String? targetCategoryId;
  final String? targetProductId;
  final bool isActive;
  final int sortOrder;

  const StoreBannerModel({
    required this.id,
    this.titleAr,
    this.titleEn,
    required this.imageUrl,
    this.actionUrl,
    this.targetCategoryId,
    this.targetProductId,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory StoreBannerModel.fromJson(Map<String, dynamic> json) {
    return StoreBannerModel(
      id: json['id'] as String? ?? '',
      titleAr: json['title_ar'] as String?,
      titleEn: json['title_en'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      actionUrl: json['action_url'] as String?,
      targetCategoryId: json['target_category_id'] as String?,
      targetProductId: json['target_product_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
