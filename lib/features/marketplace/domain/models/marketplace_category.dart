class MarketplaceCategory {
  final String id;
  final String nameEn;
  final String nameAr;
  final String iconName;
  final int sortOrder;
  final bool isVisible;
  final String? imageUrl;

  const MarketplaceCategory({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.iconName,
    this.sortOrder = 0,
    this.isVisible = true,
    this.imageUrl,
  });

  String localizedName(String locale) =>
      locale.startsWith('ar') ? nameAr : nameEn;

  factory MarketplaceCategory.fromJson(Map<String, dynamic> json) {
    return MarketplaceCategory(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      iconName: json['icon_name'] as String? ?? 'category',
      sortOrder: json['sort_order'] as int? ?? 0,
      isVisible: json['is_visible'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_en': nameEn,
        'name_ar': nameAr,
        'icon_name': iconName,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'image_url': imageUrl,
      };

  MarketplaceCategory copyWith({
    String? id,
    String? nameEn,
    String? nameAr,
    String? iconName,
    int? sortOrder,
    bool? isVisible,
    String? imageUrl,
  }) {
    return MarketplaceCategory(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
