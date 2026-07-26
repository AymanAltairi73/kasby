class StoreCategoryModel {
  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String iconName;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  const StoreCategoryModel({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.iconName = 'category',
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory StoreCategoryModel.fromJson(Map<String, dynamic> json) {
    return StoreCategoryModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'category',
      imageUrl: json['image_url'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name_ar': nameAr,
      'name_en': nameEn,
      'icon_name': iconName,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
