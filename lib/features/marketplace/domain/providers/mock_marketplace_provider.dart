import '../data/mock_marketplace_data.dart';
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
import 'marketplace_provider.dart';

/// Mock implementation of [MarketplaceProvider].
/// TODO: Replace this mock endpoint with the production Marketplace Provider API.
class MockMarketplaceProvider implements MarketplaceProvider {
  static const _networkDelay = Duration(milliseconds: 350);

  Future<void> _simulateNetwork() => Future.delayed(_networkDelay);

  List<MarketplaceCatalogListing> get _listings => MockMarketplaceData.catalogListings;

  List<MarketplaceCatalogListing> _applyFilters(MarketplaceFilterOptions? filters) {
    var list = _listings.toList();
    if (filters == null) return list;
    if (filters.categoryId != null) {
      list = list.where((l) => l.categoryId == filters.categoryId).toList();
    }
    if (filters.brandId != null) {
      list = list.where((l) => l.brandId == filters.brandId).toList();
    }
    if (filters.minPrice != null) {
      list = list.where((l) => l.walletPrice >= filters.minPrice!).toList();
    }
    if (filters.maxPrice != null) {
      list = list.where((l) => l.walletPrice <= filters.maxPrice!).toList();
    }
    if (filters.inStockOnly == true) {
      list = list.where((l) => l.isAvailable).toList();
    }
    if (filters.featuredOnly == true) {
      list = list.where((l) => l.isFeatured).toList();
    }
    if (filters.hasKspPrice == true) {
      list = list.where((l) => l.kspPrice != null).toList();
    }
    switch (filters.sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.walletPrice.compareTo(b.walletPrice));
      case 'price_desc':
        list.sort((a, b) => b.walletPrice.compareTo(a.walletPrice));
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 'popular':
        list.sort((a, b) => (b.isPopular ? 1 : 0).compareTo(a.isPopular ? 1 : 0));
      default:
        break;
    }
    return list;
  }

  @override
  Future<List<MarketplaceCategory>> getCategories({bool includeHidden = false}) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    final list = MockMarketplaceData.categories.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return includeHidden ? list : list.where((c) => c.isVisible).toList();
  }

  @override
  Future<MarketplaceCategory?> getCategoryById(String id) async {
    await _simulateNetwork();
    return MockMarketplaceData.categories.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceCategory> createCategory(MarketplaceCategory category) async {
    await _simulateNetwork();
    MockMarketplaceData.categories.add(category);
    return category;
  }

  @override
  Future<MarketplaceCategory> updateCategory(MarketplaceCategory category) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) MockMarketplaceData.categories[idx] = category;
    return category;
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    await _simulateNetwork();
    for (var i = 0; i < orderedIds.length; i++) {
      final idx = MockMarketplaceData.categories.indexWhere((c) => c.id == orderedIds[i]);
      if (idx >= 0) {
        MockMarketplaceData.categories[idx] =
            MockMarketplaceData.categories[idx].copyWith(sortOrder: i);
      }
    }
  }

  @override
  Future<List<MarketplaceBrand>> getBrands({String? categoryId, bool includeHidden = false}) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    var list = MockMarketplaceData.brands.toList();
    if (categoryId != null) list = list.where((b) => b.categoryId == categoryId).toList();
    if (!includeHidden) list = list.where((b) => b.isVisible).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<MarketplaceBrand?> getBrandById(String id) async {
    await _simulateNetwork();
    return MockMarketplaceData.brands.where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceBrand> createBrand(MarketplaceBrand brand) async {
    await _simulateNetwork();
    MockMarketplaceData.brands.add(brand);
    return brand;
  }

  @override
  Future<MarketplaceBrand> updateBrand(MarketplaceBrand brand) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.brands.indexWhere((b) => b.id == brand.id);
    if (idx >= 0) MockMarketplaceData.brands[idx] = brand;
    return brand;
  }

  @override
  Future<void> deleteBrand(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.brands.removeWhere((b) => b.id == id);
  }

  @override
  Future<List<MarketplaceProduct>> getProducts({
    String? brandId,
    String? categoryId,
    bool? activeOnly,
  }) async {
    await _simulateNetwork();
    var list = MockMarketplaceData.products.toList();
    if (brandId != null) list = list.where((p) => p.brandId == brandId).toList();
    if (categoryId != null) list = list.where((p) => p.categoryId == categoryId).toList();
    if (activeOnly == true) list = list.where((p) => p.isActive).toList();
    return list;
  }

  @override
  Future<MarketplaceProduct?> getProductById(String id) async {
    await _simulateNetwork();
    return MockMarketplaceData.products.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceProduct?> getProductDetail(String productId) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    return MockMarketplaceData.productWithVariants(productId);
  }

  @override
  Future<MarketplaceProduct> createProduct(MarketplaceProduct product) async {
    await _simulateNetwork();
    MockMarketplaceData.products.add(product);
    return product;
  }

  @override
  Future<MarketplaceProduct> updateProduct(MarketplaceProduct product) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.products.indexWhere((p) => p.id == product.id);
    if (idx >= 0) MockMarketplaceData.products[idx] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.products.removeWhere((p) => p.id == id);
    MockMarketplaceData.variants.removeWhere((v) => v.productId == id);
  }

  @override
  Future<void> bulkUpdateProducts(List<String> ids, {bool? isActive}) async {
    await _simulateNetwork();
    for (final id in ids) {
      final idx = MockMarketplaceData.products.indexWhere((p) => p.id == id);
      if (idx >= 0 && isActive != null) {
        MockMarketplaceData.products[idx] =
            MockMarketplaceData.products[idx].copyWith(isActive: isActive);
      }
    }
  }

  @override
  Future<List<MarketplaceProductVariant>> getVariants({String? productId, bool? activeOnly}) async {
    await _simulateNetwork();
    var list = MockMarketplaceData.variants.toList();
    if (productId != null) list = list.where((v) => v.productId == productId).toList();
    if (activeOnly == true) list = list.where((v) => v.isActive).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<MarketplaceProductVariant?> getVariantById(String id) async {
    await _simulateNetwork();
    return MockMarketplaceData.variants.where((v) => v.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceProductVariant> createVariant(MarketplaceProductVariant variant) async {
    await _simulateNetwork();
    MockMarketplaceData.variants.add(variant);
    return variant;
  }

  @override
  Future<MarketplaceProductVariant> updateVariant(MarketplaceProductVariant variant) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.variants.indexWhere((v) => v.id == variant.id);
    if (idx >= 0) MockMarketplaceData.variants[idx] = variant;
    return variant;
  }

  @override
  Future<void> deleteVariant(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.variants.removeWhere((v) => v.id == id);
  }

  @override
  Future<void> bulkUpdateVariants(List<String> ids, {bool? isActive}) async {
    await _simulateNetwork();
    for (final id in ids) {
      final idx = MockMarketplaceData.variants.indexWhere((v) => v.id == id);
      if (idx >= 0 && isActive != null) {
        MockMarketplaceData.variants[idx] =
            MockMarketplaceData.variants[idx].copyWith(isActive: isActive);
      }
    }
  }

  @override
  Future<List<MarketplaceCatalogListing>> getCatalogListings({MarketplaceFilterOptions? filters}) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    return _applyFilters(filters);
  }

  @override
  Future<List<MarketplaceCatalogListing>> searchCatalog(String query) async {
    await _simulateNetwork();
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return _listings.where((l) {
      return l.displayNameEn.toLowerCase().contains(q) ||
          l.displayNameAr.contains(q) ||
          l.brandNameEn.toLowerCase().contains(q) ||
          l.variantNameEn.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    await _simulateNetwork();
    if (query.length < 2) return [];
    final q = query.toLowerCase();
    return _listings
        .where((l) => l.displayNameEn.toLowerCase().contains(q))
        .map((l) => l.displayNameEn)
        .take(8)
        .toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getFeaturedListings() async {
    await _simulateNetwork();
    return _listings.where((l) => l.isFeatured).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getPopularListings() async {
    await _simulateNetwork();
    return _listings.where((l) => l.isPopular).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getTrendingListings() async {
    await _simulateNetwork();
    return (_listings.toList()..sort((a, b) => b.reviewCount.compareTo(a.reviewCount))).take(10).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getBestSellers() async {
    await _simulateNetwork();
    return (_listings.toList()..sort((a, b) => b.rating.compareTo(a.rating))).take(8).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getNewArrivals() async {
    await _simulateNetwork();
    return _listings.where((l) => l.categoryId == 'cat_new_arrivals').toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getRecommendedListings({String? userId}) async {
    await _simulateNetwork();
    return _listings.take(8).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getRecentlyPurchased({String? userId}) async {
    await _simulateNetwork();
    return _listings
        .where((l) => MockMarketplaceData.recentlyPurchasedVariantIds.contains(l.variantId))
        .toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getRelatedListings(String productId) async {
    await _simulateNetwork();
    return _listings.where((l) => l.productId != productId).take(6).toList();
  }

  @override
  Future<List<MarketplaceCoupon>> getCoupons({bool activeOnly = true}) async {
    await _simulateNetwork();
    var list = MockMarketplaceData.coupons.toList();
    if (activeOnly) list = list.where((c) => c.isValid).toList();
    return list;
  }

  @override
  Future<MarketplaceCoupon?> validateCoupon(String code, {required double subtotal}) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    try {
      final coupon = MockMarketplaceData.coupons.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
      );
      if (!coupon.isValid) return null;
      if (coupon.calculateDiscount(subtotal) <= 0) return null;
      return coupon;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MarketplaceCoupon> createCoupon(MarketplaceCoupon coupon) async {
    await _simulateNetwork();
    MockMarketplaceData.coupons.add(coupon);
    return coupon;
  }

  @override
  Future<MarketplaceCoupon> updateCoupon(MarketplaceCoupon coupon) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.coupons.indexWhere((c) => c.id == coupon.id);
    if (idx >= 0) MockMarketplaceData.coupons[idx] = coupon;
    return coupon;
  }

  @override
  Future<void> deleteCoupon(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.coupons.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<MarketplacePromotion>> getPromotions({MarketplacePromotionType? type}) async {
    await _simulateNetwork();
    var list = MockMarketplaceData.promotions.where((p) => p.isActive).toList();
    if (type != null) list = list.where((p) => p.type == type).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<MarketplacePromotion> createPromotion(MarketplacePromotion promotion) async {
    await _simulateNetwork();
    MockMarketplaceData.promotions.add(promotion);
    return promotion;
  }

  @override
  Future<MarketplacePromotion> updatePromotion(MarketplacePromotion promotion) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.promotions.indexWhere((p) => p.id == promotion.id);
    if (idx >= 0) MockMarketplaceData.promotions[idx] = promotion;
    return promotion;
  }

  @override
  Future<void> deletePromotion(String id) async {
    await _simulateNetwork();
    MockMarketplaceData.promotions.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<MarketplaceProviderMapping>> getProviderMappings({String? variantId}) async {
    await _simulateNetwork();
    if (variantId != null) {
      return MockMarketplaceData.providerMappings.where((m) => m.variantId == variantId).toList();
    }
    return MockMarketplaceData.providerMappings.toList();
  }

  @override
  Future<MarketplaceProviderMapping?> getProviderMappingForVariant(String variantId) async {
    await _simulateNetwork();
    return MockMarketplaceData.providerMappings.where((m) => m.variantId == variantId).firstOrNull;
  }

  @override
  Future<List<MarketplaceOrder>> getOrders({MarketplaceOrderStatus? status, String? userId}) async {
    await _simulateNetwork();
    var list = MockMarketplaceData.orders.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (status != null) list = list.where((o) => o.status == status).toList();
    return list;
  }

  @override
  Future<MarketplaceOrder?> getOrderById(String id) async {
    await _simulateNetwork();
    return MockMarketplaceData.orders.where((o) => o.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceCheckoutResult> placeOrder({
    required String userId,
    required List<MarketplaceCartItem> items,
    required MarketplacePaymentMethod paymentMethod,
    String? couponCode,
    double discountAmount = 0,
    String? idempotencyKey,
    bool termsAccepted = false,
  }) async {
    // TODO: Replace this mock endpoint with the production Marketplace Provider API.
    await _simulateNetwork();
    if (!termsAccepted) {
      return MarketplaceCheckoutResult(
        order: MarketplaceOrder(
          id: 'failed',
          userId: userId,
          items: const [],
          subtotalAmount: 0,
          totalAmount: 0,
          paymentMethod: paymentMethod,
          status: MarketplaceOrderStatus.failed,
          createdAt: DateTime.now(),
        ),
        success: false,
        message: 'Terms must be accepted',
      );
    }

    final orderItems = items.map((item) {
      final l = item.listing;
      return MarketplaceOrderItem(
        variantId: l.variantId,
        productId: l.productId,
        brandId: l.brandId,
        variantNameEn: l.variantNameEn,
        variantNameAr: l.variantNameAr,
        productNameEn: l.productNameEn,
        productNameAr: l.productNameAr,
        brandNameEn: l.brandNameEn,
        brandNameAr: l.brandNameAr,
        imageUrl: l.imageUrl,
        quantity: item.quantity,
        unitPrice: l.walletPrice,
        totalPrice: item.walletSubtotal,
      );
    }).toList();

    final subtotal = orderItems.fold<double>(0, (s, i) => s + i.totalPrice);
    var discount = 0.0;
    MarketplaceCoupon? appliedCoupon;
    if (couponCode != null && couponCode.isNotEmpty) {
      appliedCoupon = await validateCoupon(couponCode, subtotal: subtotal);
      discount = appliedCoupon?.calculateDiscount(subtotal) ?? 0;
    }
    final total = (subtotal - discount).clamp(0, double.infinity);
    final now = DateTime.now();

    final timeline = [
      MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.pending, timestamp: now),
      MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.processing, timestamp: now.add(const Duration(seconds: 1))),
      MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.providerAccepted, timestamp: now.add(const Duration(seconds: 2))),
      MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.delivered, timestamp: now.add(const Duration(seconds: 3))),
      MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.completed, timestamp: now.add(const Duration(seconds: 4))),
    ];

    final order = MarketplaceOrder(
      id: 'ord_${now.millisecondsSinceEpoch}',
      userId: userId,
      items: orderItems,
      subtotalAmount: subtotal,
      discountAmount: discount,
      totalAmount: total.toDouble(),
      couponCode: appliedCoupon?.code,
      paymentMethod: paymentMethod,
      status: MarketplaceOrderStatus.completed,
      createdAt: now,
      updatedAt: now.add(const Duration(seconds: 4)),
      deliveryCode: 'KSB-${now.millisecondsSinceEpoch % 100000}',
      deliveryInfo: 'Digital code delivered to your Kasby account',
      timeline: timeline,
    );

    MockMarketplaceData.orders.insert(0, order);
    for (final item in items) {
      if (!MockMarketplaceData.recentlyPurchasedVariantIds.contains(item.variantId)) {
        MockMarketplaceData.recentlyPurchasedVariantIds.insert(0, item.variantId);
      }
    }

    return MarketplaceCheckoutResult(order: order, success: true);
  }

  @override
  Future<MarketplaceOrder> updateOrderStatus(String orderId, MarketplaceOrderStatus status) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) throw Exception('Order not found');
    final now = DateTime.now();
    final updated = MockMarketplaceData.orders[idx].copyWith(
      status: status,
      updatedAt: now,
      timeline: [
        ...MockMarketplaceData.orders[idx].timeline,
        MarketplaceOrderTimelineEntry(status: status, timestamp: now),
      ],
    );
    MockMarketplaceData.orders[idx] = updated;
    return updated;
  }

  @override
  Future<List<MarketplaceReward>> getRewards() async {
    await _simulateNetwork();
    return MockMarketplaceData.rewards.toList();
  }

  @override
  Future<MarketplaceReward> claimReward(String rewardId) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.rewards.indexWhere((r) => r.id == rewardId);
    if (idx < 0) throw Exception('Reward not found');
    final updated = MockMarketplaceData.rewards[idx].copyWith(isClaimed: true);
    MockMarketplaceData.rewards[idx] = updated;
    return updated;
  }

  @override
  Future<List<MarketplaceNotification>> getNotifications() async {
    await _simulateNetwork();
    return MockMarketplaceData.notifications.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _simulateNetwork();
    final idx = MockMarketplaceData.notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      MockMarketplaceData.notifications[idx] =
          MockMarketplaceData.notifications[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<MarketplaceSettings> getSettings() async {
    await _simulateNetwork();
    return MockMarketplaceData.settings;
  }

  @override
  Future<MarketplaceSettings> updateSettings(MarketplaceSettings settings) async {
    await _simulateNetwork();
    MockMarketplaceData.settings = settings;
    return settings;
  }

  @override
  Future<MarketplaceDashboardStats> getDashboardStats() async {
    await _simulateNetwork();
    final orders = MockMarketplaceData.orders;
    final revenue = orders
        .where((o) => o.status == MarketplaceOrderStatus.completed)
        .fold<double>(0, (s, o) => s + o.totalAmount);

    return MarketplaceDashboardStats(
      totalProducts: MockMarketplaceData.products.length,
      totalBrands: MockMarketplaceData.brands.length,
      totalVariants: MockMarketplaceData.variants.length,
      totalCategories: MockMarketplaceData.categories.length,
      totalOrders: orders.length,
      totalRevenue: revenue,
      pendingOrders: orders.where((o) => o.status == MarketplaceOrderStatus.pending).length,
      bestSellingProducts: [
        {'name_en': 'PUBG 300 UC', 'sales_count': 42},
        {'name_en': 'Google Play \$10', 'sales_count': 38},
      ],
      topCategories: [
        {'name_en': 'Games', 'revenue': 1250.0},
        {'name_en': 'Gift Cards', 'revenue': 890.0},
      ],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getRevenueByCategory() async {
    await _simulateNetwork();
    return [
      {'category_id': 'cat_games', 'name_en': 'Games', 'revenue': 1250.0},
      {'category_id': 'cat_gift_cards', 'name_en': 'Gift Cards', 'revenue': 890.0},
      {'category_id': 'cat_subscriptions', 'name_en': 'Subscriptions', 'revenue': 620.0},
    ];
  }

  @override
  Future<Map<String, dynamic>> getMarketplaceHealth() async {
    await _simulateNetwork();
    return {
      'status': 'healthy',
      'active_products': MockMarketplaceData.products.where((p) => p.isActive).length,
      'active_variants': MockMarketplaceData.variants.where((v) => v.isActive).length,
      'out_of_stock_variants': MockMarketplaceData.variants
          .where((v) => v.stockStatus.name == 'outOfStock')
          .length,
      'provider_mappings': MockMarketplaceData.providerMappings.length,
      'maintenance_mode': MockMarketplaceData.settings.maintenanceMode,
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
