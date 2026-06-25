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
import '../providers/marketplace_provider.dart';
import '../providers/reloadly_provider.dart';
import '../services/marketplace_api_service.dart';
import '../services/marketplace_local_service.dart';

/// Business logic layer — UI and controllers depend on this, not the provider.
class MarketplaceRepository {
  MarketplaceRepository({
    MarketplaceApiService? apiService,
    MarketplaceLocalService? localService,
  })  : _api = apiService ?? MarketplaceApiService.to,
        _local = localService ?? MarketplaceLocalService();

  final MarketplaceApiService _api;
  final MarketplaceLocalService _local;

  MarketplaceProvider get _provider => _api.provider;

  String? get catalogLoadError => _api.catalogLoadError;

  bool get isCatalogAvailable => _api.isCatalogAvailable;

  Future<List<MarketplaceCatalogListing>> _allListings() =>
      _provider.getCatalogListings();

  // ── Catalog ──

  Future<List<MarketplaceCategory>> getCategories({bool includeHidden = false}) =>
      _provider.getCategories(includeHidden: includeHidden);

  Future<List<MarketplaceBrand>> getBrands({String? categoryId}) =>
      _provider.getBrands(categoryId: categoryId);

  Future<List<MarketplaceCatalogListing>> getCatalogListings({
    MarketplaceFilterOptions? filters,
    String? categoryId,
    bool? featured,
    bool? popular,
    bool? activeOnly,
    String? sortBy,
  }) {
    final merged = MarketplaceFilterOptions(
      categoryId: filters?.categoryId ?? categoryId,
      brandId: filters?.brandId,
      minPrice: filters?.minPrice,
      maxPrice: filters?.maxPrice,
      inStockOnly: filters?.inStockOnly ?? (activeOnly == true ? true : null),
      featuredOnly: filters?.featuredOnly ?? featured,
      hasKspPrice: filters?.hasKspPrice,
      sortBy: filters?.sortBy ?? sortBy ?? 'default',
    );
    return _provider.getCatalogListings(filters: merged);
  }

  Future<MarketplaceProduct?> getProductDetail(String productId) =>
      _provider.getProductDetail(productId);

  Future<MarketplaceCatalogListing?> getListingByVariantId(String variantId) async {
    final listings = await _allListings();
    return listings.where((l) => l.variantId == variantId).firstOrNull;
  }

  Future<MarketplaceCatalogListing?> getListingForProductVariant(
    String productId,
    String variantId,
  ) async {
    final listings = await _allListings();
    return listings
        .where((l) => l.productId == productId && l.variantId == variantId)
        .firstOrNull;
  }

  Future<List<MarketplaceCatalogListing>> searchCatalog(String query) =>
      _provider.searchCatalog(query);

  Future<List<String>> getSearchSuggestions(String query) =>
      _provider.getSearchSuggestions(query);

  Future<List<MarketplaceCatalogListing>> getFeaturedListings() =>
      _provider.getFeaturedListings();

  Future<List<MarketplaceCatalogListing>> getPopularListings() =>
      _provider.getPopularListings();

  Future<List<MarketplaceCatalogListing>> getTrendingListings() =>
      _provider.getTrendingListings();

  Future<List<MarketplaceCatalogListing>> getBestSellers() =>
      _provider.getBestSellers();

  Future<List<MarketplaceCatalogListing>> getNewArrivals() =>
      _provider.getNewArrivals();

  Future<List<MarketplaceCatalogListing>> getRecommendedListings({String? userId}) =>
      _provider.getRecommendedListings(userId: userId);

  Future<List<MarketplaceCatalogListing>> getRecentlyPurchased({String? userId}) =>
      _provider.getRecentlyPurchased(userId: userId);

  Future<List<MarketplaceCatalogListing>> getRelatedListings(String productId) =>
      _provider.getRelatedListings(productId);

  Future<List<MarketplacePromotion>> getBanners() =>
      _provider.getPromotions(type: MarketplacePromotionType.banner);

  Future<List<MarketplacePromotion>> getPromotions({MarketplacePromotionType? type}) =>
      _provider.getPromotions(type: type);

  // ── Recently Viewed ──

  Future<List<MarketplaceCatalogListing>> getRecentlyViewed() async {
    final ids = await _local.loadRecentlyViewed();
    if (ids.isEmpty) return [];
    final catalog = await _allListings();
    return _local.resolveListings(ids, catalog);
  }

  Future<void> trackVariantView(String variantId) =>
      _local.addRecentlyViewed(variantId);

  // ── Cart ──

  Future<List<MarketplaceCartItem>> loadCart() async {
    final raw = await _local.loadCartRaw();
    if (raw.isEmpty) return [];
    final catalog = await _allListings();
    return _local.resolveCartItems(raw, catalog);
  }

  Future<void> saveCart(List<MarketplaceCartItem> items) =>
      _local.saveCart(items);

  // ── Wishlist ──

  Future<List<MarketplaceCatalogListing>> loadWishlist() async {
    final ids = await _local.loadWishlist();
    if (ids.isEmpty) return [];
    final catalog = await _allListings();
    return _local.resolveListings(ids, catalog);
  }

  Future<List<String>> getWishlistIds() => _local.loadWishlist();

  Future<void> saveWishlistIds(List<String> ids) => _local.saveWishlist(ids);

  // ── Coupons ──

  Future<MarketplaceCoupon?> validateCoupon(String code, double subtotal) =>
      _provider.validateCoupon(code, subtotal: subtotal);

  Future<List<MarketplaceCoupon>> getCoupons() => _provider.getCoupons();

  // ── Orders ──

  Future<List<MarketplaceOrder>> getOrders({
    MarketplaceOrderStatus? status,
    String? userId,
  }) =>
      _provider.getOrders(status: status, userId: userId);

  Future<MarketplaceOrder?> getOrderById(String id) => _provider.getOrderById(id);

  /// Reload catalog from Reloadly (Reloadly provider only).
  Future<void> refreshCatalog() async {
    if (_provider is ReloadlyProvider) {
      await (_provider as ReloadlyProvider).refreshCatalog();
    }
  }

  /// Poll Reloadly transaction status for an order.
  Future<Map<String, dynamic>?> refreshOrderProviderStatus(String orderId) async {
    final order = await getOrderById(orderId);
    final txRaw = order?.providerTransactionId;
    if (txRaw == null || _provider is! ReloadlyProvider) return null;
    final txId = int.tryParse(txRaw);
    if (txId == null) return null;
    return (_provider as ReloadlyProvider).refreshProviderOrderStatus(txId);
  }

  Future<MarketplaceCheckoutResult> placeOrder({
    required String userId,
    required List<MarketplaceCartItem> items,
    required MarketplacePaymentMethod paymentMethod,
    String? couponCode,
    double discountAmount = 0,
    String? idempotencyKey,
    bool termsAccepted = false,
  }) =>
      _provider.placeOrder(
        userId: userId,
        items: items,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        discountAmount: discountAmount,
        idempotencyKey: idempotencyKey,
        termsAccepted: termsAccepted,
      );

  // ── Rewards & Notifications ──

  Future<List<MarketplaceReward>> getRewards() => _provider.getRewards();

  Future<MarketplaceReward> claimReward(String rewardId) =>
      _provider.claimReward(rewardId);

  Future<List<MarketplaceNotification>> getNotifications() =>
      _provider.getNotifications();

  Future<void> markNotificationRead(String id) =>
      _provider.markNotificationRead(id);

  // ── Provider mapping (admin) ──

  Future<List<MarketplaceProviderMapping>> getProviderMappings({String? variantId}) =>
      _provider.getProviderMappings(variantId: variantId);

  // ── Admin delegations ──

  Future<MarketplaceCategory> createCategory(MarketplaceCategory c) =>
      _provider.createCategory(c);

  Future<MarketplaceCategory> updateCategory(MarketplaceCategory c) =>
      _provider.updateCategory(c);

  Future<void> deleteCategory(String id) => _provider.deleteCategory(id);

  Future<MarketplaceBrand> createBrand(MarketplaceBrand b) =>
      _provider.createBrand(b);

  Future<MarketplaceBrand> updateBrand(MarketplaceBrand b) =>
      _provider.updateBrand(b);

  Future<void> deleteBrand(String id) => _provider.deleteBrand(id);

  Future<MarketplaceProduct> createProduct(MarketplaceProduct p) =>
      _provider.createProduct(p);

  Future<MarketplaceProduct> updateProduct(MarketplaceProduct p) =>
      _provider.updateProduct(p);

  Future<void> deleteProduct(String id) => _provider.deleteProduct(id);

  Future<void> bulkUpdateProducts(List<String> ids, {bool? isActive}) =>
      _provider.bulkUpdateProducts(ids, isActive: isActive);

  Future<MarketplaceProductVariant> createVariant(MarketplaceProductVariant v) =>
      _provider.createVariant(v);

  Future<MarketplaceProductVariant> updateVariant(MarketplaceProductVariant v) =>
      _provider.updateVariant(v);

  Future<void> deleteVariant(String id) => _provider.deleteVariant(id);

  Future<void> bulkUpdateVariants(List<String> ids, {bool? isActive}) =>
      _provider.bulkUpdateVariants(ids, isActive: isActive);

  Future<MarketplaceOrder> updateOrderStatus(
    String orderId,
    MarketplaceOrderStatus status,
  ) =>
      _provider.updateOrderStatus(orderId, status);

  Future<MarketplacePromotion> createPromotion(MarketplacePromotion p) =>
      _provider.createPromotion(p);

  Future<MarketplacePromotion> updatePromotion(MarketplacePromotion p) =>
      _provider.updatePromotion(p);

  Future<void> deletePromotion(String id) => _provider.deletePromotion(id);

  Future<MarketplaceCoupon> createCoupon(MarketplaceCoupon c) =>
      _provider.createCoupon(c);

  Future<MarketplaceCoupon> updateCoupon(MarketplaceCoupon c) =>
      _provider.updateCoupon(c);

  Future<void> deleteCoupon(String id) => _provider.deleteCoupon(id);

  Future<MarketplaceSettings> getSettings() => _provider.getSettings();

  Future<MarketplaceSettings> updateSettings(MarketplaceSettings s) =>
      _provider.updateSettings(s);

  Future<MarketplaceDashboardStats> getDashboardStats() =>
      _provider.getDashboardStats();

  Future<List<Map<String, dynamic>>> getRevenueByCategory() =>
      _provider.getRevenueByCategory();

  Future<Map<String, dynamic>> getMarketplaceHealth() =>
      _provider.getMarketplaceHealth();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
