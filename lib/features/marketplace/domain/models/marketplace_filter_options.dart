class MarketplaceFilterOptions {
  final String? categoryId;
  final String? brandId;
  final double? minPrice;
  final double? maxPrice;
  final bool? inStockOnly;
  final bool? featuredOnly;
  final bool? hasKspPrice;
  final String sortBy;

  const MarketplaceFilterOptions({
    this.categoryId,
    this.brandId,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly,
    this.featuredOnly,
    this.hasKspPrice,
    this.sortBy = 'default',
  });

  MarketplaceFilterOptions copyWith({
    String? categoryId,
    String? brandId,
    double? minPrice,
    double? maxPrice,
    bool? inStockOnly,
    bool? featuredOnly,
    bool? hasKspPrice,
    String? sortBy,
  }) {
    return MarketplaceFilterOptions(
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      hasKspPrice: hasKspPrice ?? this.hasKspPrice,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get hasActiveFilters =>
      categoryId != null ||
      brandId != null ||
      minPrice != null ||
      maxPrice != null ||
      inStockOnly == true ||
      featuredOnly == true ||
      hasKspPrice == true ||
      sortBy != 'default';
}
