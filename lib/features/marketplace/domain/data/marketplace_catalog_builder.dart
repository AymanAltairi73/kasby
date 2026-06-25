import '../models/marketplace_brand.dart';
import '../models/marketplace_category.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_product_variant.dart';
import '../models/marketplace_catalog_listing.dart';

/// Builds denormalized catalog listings from the product hierarchy.
class MarketplaceCatalogBuilder {
  static List<MarketplaceCatalogListing> buildListings({
    required List<MarketplaceCategory> categories,
    required List<MarketplaceBrand> brands,
    required List<MarketplaceProduct> products,
    required List<MarketplaceProductVariant> variants,
  }) {
    final catMap = {for (final c in categories) c.id: c};
    final brandMap = {for (final b in brands) b.id: b};
    final productMap = {for (final p in products) p.id: p};

    final listings = <MarketplaceCatalogListing>[];
    for (final variant in variants) {
      if (!variant.isActive) continue;
      final product = productMap[variant.productId];
      if (product == null || !product.isActive) continue;
      final brand = brandMap[product.brandId];
      if (brand == null || !brand.isActive) continue;
      final category = catMap[product.categoryId];
      if (category == null || !category.isVisible) continue;

      listings.add(
        MarketplaceCatalogListing(
          variantId: variant.id,
          productId: product.id,
          brandId: brand.id,
          categoryId: category.id,
          variantNameEn: variant.nameEn,
          variantNameAr: variant.nameAr,
          productNameEn: product.nameEn,
          productNameAr: product.nameAr,
          brandNameEn: brand.nameEn,
          brandNameAr: brand.nameAr,
          categoryNameEn: category.nameEn,
          categoryNameAr: category.nameAr,
          imageUrl: product.imageUrl,
          walletPrice: variant.walletPrice,
          kspPrice: variant.kspPrice,
          originalPrice: variant.originalPrice,
          stockStatus: variant.stockStatus,
          rating: product.rating,
          reviewCount: product.reviewCount,
          isFeatured: variant.isFeatured,
          isPopular: product.isPopular,
          isActive: variant.isActive,
          estimatedDelivery: variant.estimatedDelivery,
        ),
      );
    }
    return listings;
  }
}
