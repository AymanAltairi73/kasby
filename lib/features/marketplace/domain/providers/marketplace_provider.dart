import '../models/marketplace_brand.dart';
import '../models/marketplace_category.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_product_variant.dart';
import '../models/marketplace_catalog_listing.dart';
import '../models/marketplace_order.dart';
import '../models/marketplace_promotion.dart';
import '../models/marketplace_reward.dart';
import '../models/marketplace_notification.dart';
import '../models/marketplace_settings.dart';
import '../models/marketplace_cart_item.dart';
import '../models/marketplace_coupon.dart';
import '../models/marketplace_provider_mapping.dart';
import '../models/marketplace_filter_options.dart';

/// Contract for all Marketplace data providers.
/// Only provider implementations change at integration time.
abstract class MarketplaceProvider {
  // Categories
  Future<List<MarketplaceCategory>> getCategories({bool includeHidden = false});
  Future<MarketplaceCategory?> getCategoryById(String id);
  Future<MarketplaceCategory> createCategory(MarketplaceCategory category);
  Future<MarketplaceCategory> updateCategory(MarketplaceCategory category);
  Future<void> deleteCategory(String id);
  Future<void> reorderCategories(List<String> orderedIds);

  // Brands
  Future<List<MarketplaceBrand>> getBrands({String? categoryId, bool includeHidden = false});
  Future<MarketplaceBrand?> getBrandById(String id);
  Future<MarketplaceBrand> createBrand(MarketplaceBrand brand);
  Future<MarketplaceBrand> updateBrand(MarketplaceBrand brand);
  Future<void> deleteBrand(String id);

  // Products (product lines)
  Future<List<MarketplaceProduct>> getProducts({String? brandId, String? categoryId, bool? activeOnly});
  Future<MarketplaceProduct?> getProductById(String id);
  Future<MarketplaceProduct?> getProductDetail(String productId);
  Future<MarketplaceProduct> createProduct(MarketplaceProduct product);
  Future<MarketplaceProduct> updateProduct(MarketplaceProduct product);
  Future<void> deleteProduct(String id);
  Future<void> bulkUpdateProducts(List<String> ids, {bool? isActive});

  // Variants
  Future<List<MarketplaceProductVariant>> getVariants({String? productId, bool? activeOnly});
  Future<MarketplaceProductVariant?> getVariantById(String id);
  Future<MarketplaceProductVariant> createVariant(MarketplaceProductVariant variant);
  Future<MarketplaceProductVariant> updateVariant(MarketplaceProductVariant variant);
  Future<void> deleteVariant(String id);
  Future<void> bulkUpdateVariants(List<String> ids, {bool? isActive});

  // Catalog (denormalized listings for browse/search)
  Future<List<MarketplaceCatalogListing>> getCatalogListings({MarketplaceFilterOptions? filters});
  Future<List<MarketplaceCatalogListing>> searchCatalog(String query);
  Future<List<String>> getSearchSuggestions(String query);
  Future<List<MarketplaceCatalogListing>> getFeaturedListings();
  Future<List<MarketplaceCatalogListing>> getPopularListings();
  Future<List<MarketplaceCatalogListing>> getTrendingListings();
  Future<List<MarketplaceCatalogListing>> getBestSellers();
  Future<List<MarketplaceCatalogListing>> getNewArrivals();
  Future<List<MarketplaceCatalogListing>> getRecommendedListings({String? userId});
  Future<List<MarketplaceCatalogListing>> getRecentlyPurchased({String? userId});
  Future<List<MarketplaceCatalogListing>> getRelatedListings(String productId);

  // Coupons & Promotions
  Future<List<MarketplaceCoupon>> getCoupons({bool activeOnly = true});
  Future<MarketplaceCoupon?> validateCoupon(String code, {required double subtotal});
  Future<MarketplaceCoupon> createCoupon(MarketplaceCoupon coupon);
  Future<MarketplaceCoupon> updateCoupon(MarketplaceCoupon coupon);
  Future<void> deleteCoupon(String id);
  Future<List<MarketplacePromotion>> getPromotions({MarketplacePromotionType? type});
  Future<MarketplacePromotion> createPromotion(MarketplacePromotion promotion);
  Future<MarketplacePromotion> updatePromotion(MarketplacePromotion promotion);
  Future<void> deletePromotion(String id);

  // Provider mapping (admin / integration layer)
  Future<List<MarketplaceProviderMapping>> getProviderMappings({String? variantId});
  Future<MarketplaceProviderMapping?> getProviderMappingForVariant(String variantId);

  // Orders
  Future<List<MarketplaceOrder>> getOrders({MarketplaceOrderStatus? status, String? userId});
  Future<MarketplaceOrder?> getOrderById(String id);
  Future<MarketplaceCheckoutResult> placeOrder({
    required String userId,
    required List<MarketplaceCartItem> items,
    required MarketplacePaymentMethod paymentMethod,
    String? couponCode,
    double discountAmount = 0,
    String? idempotencyKey,
    bool termsAccepted = false,
  });
  Future<MarketplaceOrder> updateOrderStatus(String orderId, MarketplaceOrderStatus status);

  // Rewards & Notifications
  Future<List<MarketplaceReward>> getRewards();
  Future<MarketplaceReward> claimReward(String rewardId);
  Future<List<MarketplaceNotification>> getNotifications();
  Future<void> markNotificationRead(String id);

  // Settings & Analytics
  Future<MarketplaceSettings> getSettings();
  Future<MarketplaceSettings> updateSettings(MarketplaceSettings settings);
  Future<MarketplaceDashboardStats> getDashboardStats();
  Future<List<Map<String, dynamic>>> getRevenueByCategory();
  Future<Map<String, dynamic>> getMarketplaceHealth();
}
