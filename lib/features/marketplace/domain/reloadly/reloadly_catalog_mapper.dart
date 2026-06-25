import '../models/marketplace_brand.dart';
import '../models/marketplace_category.dart';
import '../models/marketplace_catalog_listing.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_product_variant.dart';
import '../models/marketplace_provider_mapping.dart';
import 'reloadly_models.dart';

/// Maps Reloadly Gift Card API products → Kasby Category/Brand/Product/Variant.
class ReloadlyCatalogMapper {
  ReloadlyCatalogMapper._();

  static const giftCardsCategoryId = 'reloadly_gift_cards';
  static const mobileTopUpCategoryId = 'reloadly_mobile_topup';
  static const utilitiesCategoryId = 'reloadly_utilities';

  static const _gamingKeywords = [
    'pubg',
    'free fire',
    'mobile legends',
    'call of duty',
    'cod',
    'fortnite',
    'roblox',
    'xbox',
    'playstation',
    'steam',
    'nintendo',
    'game',
    'gaming',
  ];

  static const _subscriptionKeywords = [
    'netflix',
    'spotify',
    'youtube',
    'chatgpt',
    'openai',
    'canva',
    'disney',
    'hulu',
  ];

  static List<MarketplaceCategory> buildCategories() {
    return const [
      MarketplaceCategory(
        id: giftCardsCategoryId,
        nameEn: 'Gift Cards',
        nameAr: 'بطاقات الهدايا',
        iconName: 'card_giftcard',
        sortOrder: 0,
        isVisible: true,
      ),
      MarketplaceCategory(
        id: 'reloadly_gaming',
        nameEn: 'Gaming',
        nameAr: 'الألعاب',
        iconName: 'sports_esports',
        sortOrder: 1,
        isVisible: true,
      ),
      MarketplaceCategory(
        id: 'reloadly_subscriptions',
        nameEn: 'Subscriptions',
        nameAr: 'الاشتراكات',
        iconName: 'subscriptions',
        sortOrder: 2,
        isVisible: true,
      ),
    ];
  }

  static String resolveCategoryId(ReloadlyProductDto product) {
    final haystack = '${product.productName} ${product.brandName}'.toLowerCase();
    if (_gamingKeywords.any(haystack.contains)) return 'reloadly_gaming';
    if (_subscriptionKeywords.any(haystack.contains)) {
      return 'reloadly_subscriptions';
    }
    return giftCardsCategoryId;
  }

  static String brandId(ReloadlyProductDto product) =>
      'reloadly_brand_${product.brandId}';

  static String productId(ReloadlyProductDto product) =>
      'reloadly_product_${product.productId}';

  static String variantId(ReloadlyProductDto product, double unitPrice) =>
      'reloadly_variant_${product.productId}_${unitPrice.toStringAsFixed(2)}';

  static MarketplaceBrand toBrand(ReloadlyProductDto product, String categoryId) {
    return MarketplaceBrand(
      id: brandId(product),
      categoryId: categoryId,
      nameEn: product.brandName,
      nameAr: product.brandName,
      imageUrl: product.logoUrls.isNotEmpty ? product.logoUrls.first : '',
      sortOrder: product.brandId,
      isVisible: true,
    );
  }

  static MarketplaceProduct toProduct(ReloadlyProductDto product, String categoryId) {
    return MarketplaceProduct(
      id: productId(product),
      brandId: brandId(product),
      categoryId: categoryId,
      nameEn: product.productName,
      nameAr: product.productName,
      descriptionEn: product.global
          ? 'Global gift card'
          : 'Available in ${product.countryName ?? product.countryIso ?? 'selected region'}',
      descriptionAr: product.global
          ? 'بطاقة هدايا عالمية'
          : 'متاح في ${product.countryName ?? product.countryIso ?? 'المنطقة المحددة'}',
      imageUrl: product.logoUrls.isNotEmpty ? product.logoUrls.first : '',
      isActive: true,
    );
  }

  static List<MarketplaceProductVariant> toVariants(ReloadlyProductDto product) {
    if (product.denominationType == 'RANGE') {
      final min = product.minRecipientDenomination ?? 0;
      final max = product.maxRecipientDenomination ?? min;
      if (min <= 0) return const [];
      return [
        MarketplaceProductVariant(
          id: variantId(product, min),
          productId: productId(product),
          nameEn: '\$${min.toStringAsFixed(0)} – \$${max.toStringAsFixed(0)}',
          nameAr: '\$${min.toStringAsFixed(0)} – \$${max.toStringAsFixed(0)}',
          walletPrice: min,
          stockStatus: MarketplaceStockStatus.inStock,
          isActive: true,
          providerSku: '${product.productId}:${min.toStringAsFixed(2)}',
        ),
      ];
    }

    return product.fixedRecipientDenominations.map((price) {
      return MarketplaceProductVariant(
        id: variantId(product, price),
        productId: productId(product),
        nameEn: '\$${price.toStringAsFixed(2)}',
        nameAr: '\$${price.toStringAsFixed(2)}',
        walletPrice: price,
        stockStatus: MarketplaceStockStatus.inStock,
        isActive: true,
        providerSku: '${product.productId}:${price.toStringAsFixed(2)}',
      );
    }).toList();
  }

  static MarketplaceCatalogListing toListing({
    required ReloadlyProductDto product,
    required MarketplaceProductVariant variant,
    required String categoryId,
    required MarketplaceCategory category,
    required MarketplaceBrand brand,
  }) {
    final discount = product.discountPercentage ?? 0;
    final original = discount > 0
        ? variant.walletPrice / (1 - discount / 100)
        : null;

    return MarketplaceCatalogListing(
      variantId: variant.id,
      productId: productId(product),
      brandId: brand.id,
      categoryId: categoryId,
      variantNameEn: variant.nameEn,
      variantNameAr: variant.nameAr,
      productNameEn: product.productName,
      productNameAr: product.productName,
      brandNameEn: brand.nameEn,
      brandNameAr: brand.nameAr,
      categoryNameEn: category.nameEn,
      categoryNameAr: category.nameAr,
      imageUrl: product.logoUrls.isNotEmpty ? product.logoUrls.first : '',
      walletPrice: variant.walletPrice,
      originalPrice: original,
      stockStatus: variant.stockStatus,
      rating: 4.5,
      reviewCount: 0,
      isFeatured: discount >= 5,
      isPopular: _gamingKeywords.any(
        '${product.productName} ${product.brandName}'.toLowerCase().contains,
      ),
      isActive: true,
      estimatedDelivery: 'Instant',
    );
  }

  static MarketplaceProviderMapping toProviderMapping(
    MarketplaceProductVariant variant,
    ReloadlyProductDto product,
  ) {
    return MarketplaceProviderMapping(
      id: 'reloadly_map_${variant.id}',
      variantId: variant.id,
      providerName: MarketplaceProviderName.reloadly,
      providerProductId: product.productId.toString(),
      providerSku: variant.providerSku,
      providerCategory: 'giftcards',
      providerStatus: MarketplaceProviderStatus.active,
      providerMetadata: {
        'reloadlyProductId': product.productId,
        'recipientCurrencyCode': product.recipientCurrencyCode,
      },
    );
  }

  static ({int productId, double unitPrice})? parseVariantSku(String variantId) {
    if (!variantId.startsWith('reloadly_variant_')) return null;
    final body = variantId.replaceFirst('reloadly_variant_', '');
    final sep = body.lastIndexOf('_');
    if (sep <= 0) return null;
    final productId = int.tryParse(body.substring(0, sep));
    final unitPrice = double.tryParse(body.substring(sep + 1));
    if (productId == null || unitPrice == null) return null;
    return (productId: productId, unitPrice: unitPrice);
  }
}
