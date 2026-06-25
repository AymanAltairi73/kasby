class MarketplaceBrand {
  final String id;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? imageUrl;
  final int sortOrder;
  final bool isVisible;
  final bool isActive;

  const MarketplaceBrand({
    required this.id,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.imageUrl,
    this.sortOrder = 0,
    this.isVisible = true,
    this.isActive = true,
  });

  String localizedName(String locale) =>
      locale.startsWith('ar') ? nameAr : nameEn;

  factory MarketplaceBrand.fromJson(Map<String, dynamic> json) {
    return MarketplaceBrand(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isVisible: json['is_visible'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'is_active': isActive,
      };

  MarketplaceBrand copyWith({
    String? categoryId,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? imageUrl,
    int? sortOrder,
    bool? isVisible,
    bool? isActive,
  }) {
    return MarketplaceBrand(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
      isActive: isActive ?? this.isActive,
    );
  }
}
