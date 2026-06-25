import 'package:kasby/core/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

import '../models/marketplace_brand.dart';
import '../models/marketplace_cart_item.dart';
import '../models/marketplace_catalog_listing.dart';
import '../models/marketplace_category.dart';
import '../models/marketplace_coupon.dart';
import '../models/marketplace_filter_options.dart';
import '../models/marketplace_notification.dart';
import '../models/marketplace_order.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_product_variant.dart';
import '../models/marketplace_promotion.dart';
import '../models/marketplace_provider_mapping.dart';
import '../models/marketplace_reward.dart';
import '../models/marketplace_settings.dart';
import '../providers/marketplace_provider.dart';
import '../services/marketplace_order_store.dart';
import '../services/marketplace_settlement_service.dart';
import '../reloadly/reloadly_api_client.dart';
import '../reloadly/reloadly_catalog_mapper.dart';
import '../reloadly/reloadly_config.dart';
import '../reloadly/reloadly_models.dart';

/// Production [MarketplaceProvider] — Reloadly Gift Cards API only (v1).
///
/// Kasby Marketplace launches with Reloadly as the sole provider.
/// Admin catalog management uses Supabase + reloadly-proxy separately.
class ReloadlyProvider implements MarketplaceProvider {
  ReloadlyProvider({
    ReloadlyApiClient? client,
    MarketplaceSettlementService? settlement,
    MarketplaceOrderStore? orderStore,
  })  : _client = client ?? ReloadlyApiClient(),
        _settlement = settlement ?? MarketplaceSettlementService(),
        _orderStore = orderStore ?? MarketplaceOrderStore();

  final ReloadlyApiClient _client;
  final MarketplaceSettlementService _settlement;
  final MarketplaceOrderStore _orderStore;
  final _uuid = const Uuid();

  List<ReloadlyProductDto>? _rawProducts;
  List<MarketplaceCatalogListing>? _listings;
  List<MarketplaceBrand>? _brands;
  List<MarketplaceProduct>? _products;
  List<MarketplaceProductVariant>? _variants;
  String? _loadError;

  /// Last catalog fetch error (null when Reloadly catalog loaded successfully).
  String? get catalogLoadError => _loadError;

  bool get isCatalogAvailable => _loadError == null;

  Future<void> warmUp() async {
    try {
      await _ensureCatalogLoaded();
    } catch (_) {}
  }

  /// Clears in-memory cache and reloads catalog from Reloadly.
  Future<void> refreshCatalog() async {
    _rawProducts = null;
    _listings = null;
    _brands = null;
    _products = null;
    _variants = null;
    _loadError = null;
    await _ensureCatalogLoaded();
  }

  /// Poll Reloadly for latest transaction status (order history refresh).
  Future<Map<String, dynamic>?> refreshProviderOrderStatus(int transactionId) async {
    final tx = await _client.getTransaction(transactionId);
    if (tx == null) return null;
    return {
      'transactionId': tx.transactionId,
      'status': tx.status,
      'amount': tx.amount,
      'currencyCode': tx.currencyCode,
      'isSuccessful': tx.isSuccessful,
    };
  }

  Never _adminUnsupported(String operation) =>
      throw UnsupportedError(
        'ReloadlyProvider does not support admin operation "$operation". '
        'Admin marketplace uses MockMarketplaceAdminStore.',
      );

  Future<void> _ensureCatalogLoaded() async {
    if (_listings != null) return;

    try {
      _rawProducts = await _client.getProducts(
        countryCode: ReloadlyConfig.defaultCountryCode.isEmpty
            ? null
            : ReloadlyConfig.defaultCountryCode,
      );
      _loadError = null;
    } on ReloadlyApiException catch (e) {
      _loadError = e.message;
      _rawProducts = const [];
    }

    final categories = ReloadlyCatalogMapper.buildCategories();
    final categoryById = {for (final c in categories) c.id: c};

    final brands = <MarketplaceBrand>[];
    final products = <MarketplaceProduct>[];
    final variants = <MarketplaceProductVariant>[];
    final listings = <MarketplaceCatalogListing>[];
    final brandKeys = <String>{};

    for (final raw in _rawProducts ?? const <ReloadlyProductDto>[]) {
      final categoryId = ReloadlyCatalogMapper.resolveCategoryId(raw);
      final category = categoryById[categoryId] ?? categories.first;
      final brand = ReloadlyCatalogMapper.toBrand(raw, categoryId);
      if (brandKeys.add(brand.id)) brands.add(brand);

      products.add(ReloadlyCatalogMapper.toProduct(raw, categoryId));
      final productVariants = ReloadlyCatalogMapper.toVariants(raw);
      variants.addAll(productVariants);

      for (final variant in productVariants) {
        listings.add(
          ReloadlyCatalogMapper.toListing(
            product: raw,
            variant: variant,
            categoryId: categoryId,
            category: category,
            brand: brand,
          ),
        );
      }
    }

    _brands = brands;
    _products = products;
    _variants = variants;
    _listings = listings;
  }

  List<MarketplaceCatalogListing> _applyFilters(MarketplaceFilterOptions? filters) {
    var list = (_listings ?? const <MarketplaceCatalogListing>[]).toList();
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

  // ── Categories ──

  @override
  Future<List<MarketplaceCategory>> getCategories({bool includeHidden = false}) async {
    await _ensureCatalogLoaded();
    final list = ReloadlyCatalogMapper.buildCategories();
    return includeHidden ? list : list.where((c) => c.isVisible).toList();
  }

  @override
  Future<MarketplaceCategory?> getCategoryById(String id) async {
    await _ensureCatalogLoaded();
    return ReloadlyCatalogMapper.buildCategories()
        .where((c) => c.id == id)
        .firstOrNull;
  }

  @override
  Future<MarketplaceCategory> createCategory(MarketplaceCategory category) async =>
      _adminUnsupported('createCategory');

  @override
  Future<MarketplaceCategory> updateCategory(MarketplaceCategory category) async =>
      _adminUnsupported('updateCategory');

  @override
  Future<void> deleteCategory(String id) async => _adminUnsupported('deleteCategory');

  @override
  Future<void> reorderCategories(List<String> orderedIds) async =>
      _adminUnsupported('reorderCategories');

  // ── Brands ──

  @override
  Future<List<MarketplaceBrand>> getBrands({
    String? categoryId,
    bool includeHidden = false,
  }) async {
    await _ensureCatalogLoaded();
    var list = (_brands ?? const []).toList();
    if (categoryId != null) {
      list = list.where((b) => b.categoryId == categoryId).toList();
    }
    if (!includeHidden) list = list.where((b) => b.isVisible).toList();
    return list;
  }

  @override
  Future<MarketplaceBrand?> getBrandById(String id) async {
    await _ensureCatalogLoaded();
    return (_brands ?? const []).where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceBrand> createBrand(MarketplaceBrand brand) async =>
      _adminUnsupported('createBrand');

  @override
  Future<MarketplaceBrand> updateBrand(MarketplaceBrand brand) async =>
      _adminUnsupported('updateBrand');

  @override
  Future<void> deleteBrand(String id) async => _adminUnsupported('deleteBrand');

  // ── Products ──

  @override
  Future<List<MarketplaceProduct>> getProducts({
    String? brandId,
    String? categoryId,
    bool? activeOnly,
  }) async {
    await _ensureCatalogLoaded();
    var list = (_products ?? const []).toList();
    if (brandId != null) list = list.where((p) => p.brandId == brandId).toList();
    if (categoryId != null) {
      list = list.where((p) => p.categoryId == categoryId).toList();
    }
    if (activeOnly == true) list = list.where((p) => p.isActive).toList();
    return list;
  }

  @override
  Future<MarketplaceProduct?> getProductById(String id) async {
    await _ensureCatalogLoaded();
    return (_products ?? const []).where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceProduct?> getProductDetail(String productId) async {
    await _ensureCatalogLoaded();
    var product = (_products ?? const []).where((p) => p.id == productId).firstOrNull;
    if (product != null) return product;

    // Live fetch from Reloadly when not in cache
    final reloadlyId = int.tryParse(productId.replaceFirst('reloadly_product_', ''));
    if (reloadlyId == null) return null;
    final dto = await _client.getProductById(reloadlyId);
    if (dto == null) return null;

    final categoryId = ReloadlyCatalogMapper.resolveCategoryId(dto);
    product = ReloadlyCatalogMapper.toProduct(dto, categoryId);
    _products = [...(_products ?? const []), product];
    return product;
  }

  @override
  Future<MarketplaceProduct> createProduct(MarketplaceProduct product) async =>
      _adminUnsupported('createProduct');

  @override
  Future<MarketplaceProduct> updateProduct(MarketplaceProduct product) async =>
      _adminUnsupported('updateProduct');

  @override
  Future<void> deleteProduct(String id) async => _adminUnsupported('deleteProduct');

  @override
  Future<void> bulkUpdateProducts(List<String> ids, {bool? isActive}) async =>
      _adminUnsupported('bulkUpdateProducts');

  // ── Variants ──

  @override
  Future<List<MarketplaceProductVariant>> getVariants({
    String? productId,
    bool? activeOnly,
  }) async {
    await _ensureCatalogLoaded();
    var list = (_variants ?? const []).toList();
    if (productId != null) {
      list = list.where((v) => v.productId == productId).toList();
    }
    if (activeOnly == true) list = list.where((v) => v.isActive).toList();
    return list;
  }

  @override
  Future<MarketplaceProductVariant?> getVariantById(String id) async {
    await _ensureCatalogLoaded();
    return (_variants ?? const []).where((v) => v.id == id).firstOrNull;
  }

  @override
  Future<MarketplaceProductVariant> createVariant(
    MarketplaceProductVariant variant,
  ) async =>
      _adminUnsupported('createVariant');

  @override
  Future<MarketplaceProductVariant> updateVariant(
    MarketplaceProductVariant variant,
  ) async =>
      _adminUnsupported('updateVariant');

  @override
  Future<void> deleteVariant(String id) async => _adminUnsupported('deleteVariant');

  @override
  Future<void> bulkUpdateVariants(List<String> ids, {bool? isActive}) async =>
      _adminUnsupported('bulkUpdateVariants');

  // ── Catalog ──

  @override
  Future<List<MarketplaceCatalogListing>> getCatalogListings({
    MarketplaceFilterOptions? filters,
  }) async {
    await _ensureCatalogLoaded();
    return _applyFilters(filters);
  }

  @override
  Future<List<MarketplaceCatalogListing>> searchCatalog(String query) async {
    await _ensureCatalogLoaded();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _applyFilters(null);
    return _applyFilters(null).where((l) {
      return l.productNameEn.toLowerCase().contains(q) ||
          l.brandNameEn.toLowerCase().contains(q) ||
          l.variantNameEn.toLowerCase().contains(q) ||
          l.categoryNameEn.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    final results = await searchCatalog(query);
    return results.take(8).map((l) => l.displayNameEn).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getFeaturedListings() async {
    await _ensureCatalogLoaded();
    return _applyFilters(const MarketplaceFilterOptions(featuredOnly: true));
  }

  @override
  Future<List<MarketplaceCatalogListing>> getPopularListings() async {
    await _ensureCatalogLoaded();
    return _applyFilters(null).where((l) => l.isPopular).take(20).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getTrendingListings() async =>
      getPopularListings();

  @override
  Future<List<MarketplaceCatalogListing>> getBestSellers() async =>
      getPopularListings();

  @override
  Future<List<MarketplaceCatalogListing>> getNewArrivals() async {
    await _ensureCatalogLoaded();
    return _applyFilters(null).take(20).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getRecommendedListings({
    String? userId,
  }) async =>
      getFeaturedListings();

  @override
  Future<List<MarketplaceCatalogListing>> getRecentlyPurchased({
    String? userId,
  }) async {
    if (userId == null) return const [];
    final orders = await _orderStore.getOrders(userId: userId);
    final ids = orders.expand((o) => o.items.map((i) => i.variantId)).toSet();
    return _applyFilters(null).where((l) => ids.contains(l.variantId)).toList();
  }

  @override
  Future<List<MarketplaceCatalogListing>> getRelatedListings(
    String productId,
  ) async {
    await _ensureCatalogLoaded();
    final product = await getProductById(productId);
    if (product == null) return const [];
    return _applyFilters(null)
        .where((l) => l.categoryId == product.categoryId && l.productId != productId)
        .take(12)
        .toList();
  }

  // ── Coupons & Promotions (Kasby-managed — not Reloadly) ──

  @override
  Future<List<MarketplaceCoupon>> getCoupons({bool activeOnly = true}) async =>
      const [];

  @override
  Future<MarketplaceCoupon?> validateCoupon(String code, {required double subtotal}) async =>
      null;

  @override
  Future<MarketplaceCoupon> createCoupon(MarketplaceCoupon coupon) async =>
      _adminUnsupported('createCoupon');

  @override
  Future<MarketplaceCoupon> updateCoupon(MarketplaceCoupon coupon) async =>
      _adminUnsupported('updateCoupon');

  @override
  Future<void> deleteCoupon(String id) async => _adminUnsupported('deleteCoupon');

  @override
  Future<List<MarketplacePromotion>> getPromotions({MarketplacePromotionType? type}) async =>
      const [];

  @override
  Future<MarketplacePromotion> createPromotion(MarketplacePromotion promotion) async =>
      _adminUnsupported('createPromotion');

  @override
  Future<MarketplacePromotion> updatePromotion(MarketplacePromotion promotion) async =>
      _adminUnsupported('updatePromotion');

  @override
  Future<void> deletePromotion(String id) async => _adminUnsupported('deletePromotion');

  // ── Provider mapping ──

  @override
  Future<List<MarketplaceProviderMapping>> getProviderMappings({String? variantId}) async {
    await _ensureCatalogLoaded();
    final mappings = <MarketplaceProviderMapping>[];
    for (final variant in _variants ?? const <MarketplaceProductVariant>[]) {
      if (variantId != null && variant.id != variantId) continue;
      final parsed = ReloadlyCatalogMapper.parseVariantSku(variant.id);
      if (parsed == null) continue;
      final raw = (_rawProducts ?? const [])
          .where((p) => p.productId == parsed.productId)
          .firstOrNull;
      if (raw == null) continue;
      mappings.add(ReloadlyCatalogMapper.toProviderMapping(variant, raw));
    }
    return mappings;
  }

  @override
  Future<MarketplaceProviderMapping?> getProviderMappingForVariant(
    String variantId,
  ) async {
    final list = await getProviderMappings(variantId: variantId);
    return list.firstOrNull;
  }

  // ── Orders ──

  @override
  Future<List<MarketplaceOrder>> getOrders({
    MarketplaceOrderStatus? status,
    String? userId,
  }) async {
    if (userId == null) return const [];
    return _orderStore.getOrders(userId: userId, status: status);
  }

  @override
  Future<MarketplaceOrder?> getOrderById(String id) async {
    final userId = SupabaseService.userId;
    if (userId == null) return null;
    return _orderStore.getOrderById(userId: userId, orderId: id);
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
    if (!termsAccepted) {
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, 'Terms must be accepted'),
        success: false,
        message: 'Terms must be accepted',
      );
    }
    if (items.isEmpty) {
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, 'Cart is empty'),
        success: false,
        message: 'Cart is empty',
      );
    }

    final email = SupabaseService.currentUser?.email ?? '';
    final profileName =
        SupabaseService.currentUser?.userMetadata?['full_name']?.toString() ??
            'Kasby User';
    if (email.isEmpty) {
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, 'Email required'),
        success: false,
        message: 'Verified email required for digital delivery',
      );
    }

    await _ensureCatalogLoaded();

    final subtotal = items.fold<double>(0, (s, i) => s + i.walletSubtotal);
    final total = (subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final checkoutKey = idempotencyKey ?? _uuid.v4();
    String? orderId;

    try {
      final settlement = await _settlement.beginCheckout(
        idempotencyKey: checkoutKey,
        paymentMethod: paymentMethod,
        subtotal: subtotal,
        discount: discountAmount,
        total: total,
        couponCode: couponCode?.isNotEmpty == true ? couponCode : null,
        items: items,
      );
      orderId = settlement.orderId;

      if (settlement.idempotent) {
        final existing = await _orderStore.getOrderById(
          userId: userId,
          orderId: orderId,
        );
        if (existing != null) {
          return MarketplaceCheckoutResult(order: existing, success: true);
        }
      }

      final persistedItems = await _orderStore.getOrderItems(orderId);
      final itemUpdates = <ItemFulfillmentUpdate>[];
      String? deliveryCode;
      String? deliveryInfo;
      int? lastProviderTxId;

      for (final item in items) {
        final parsed = ReloadlyCatalogMapper.parseVariantSku(item.variantId);
        if (parsed == null) {
          throw ReloadlyApiException('Invalid Reloadly variant ${item.variantId}');
        }

        final persisted = persistedItems
            .where((p) => p.variantId == item.variantId)
            .firstOrNull;

        final customId = 'kasby_${userId}_${checkoutKey}_${item.variantId}';
        final response = await _client.placeOrder(
          productId: parsed.productId,
          unitPrice: parsed.unitPrice,
          quantity: item.quantity,
          recipientEmail: email,
          senderName: profileName,
          customIdentifier: customId,
        );
        lastProviderTxId = response.transactionId;

        final codes = await _client.getRedeemCodes(response.transactionId);
        final redeemJson = codes
            .map(
              (c) => {
                'cardNumber': c.cardNumber,
                'pinCode': c.pinCode,
                'expirationDate': c.expirationDate,
              },
            )
            .toList();

        if (codes.isNotEmpty) {
          final code = codes.first;
          deliveryCode = code.pinCode ?? code.cardNumber;
          deliveryInfo = code.cardNumber != null
              ? 'Card: ${code.cardNumber}${code.pinCode != null ? ' · PIN: ${code.pinCode}' : ''}'
              : 'PIN: ${code.pinCode}';
        }

        if (persisted != null) {
          itemUpdates.add(
            ItemFulfillmentUpdate(
              itemId: persisted.id,
              providerTransactionId: response.transactionId,
              redeemCodes: redeemJson,
            ),
          );
        }
      }

      await _settlement.completeOrder(
        orderId: orderId,
        providerTransactionId: lastProviderTxId,
        deliveryCode: deliveryCode,
        deliveryInfo: deliveryInfo ?? 'Digital delivery via Reloadly',
        itemUpdates: itemUpdates,
      );

      final order = await _orderStore.getOrderById(userId: userId, orderId: orderId);
      if (order == null) {
        throw SettlementException('Order not found after completion');
      }
      return MarketplaceCheckoutResult(order: order, success: true);
    } on SettlementException catch (e) {
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, e.message),
        success: false,
        message: e.message,
      );
    } on ReloadlyApiException catch (e) {
      if (orderId != null) {
        try {
          await _settlement.refundOrder(
            orderId: orderId,
            reason: e.message,
          );
        } catch (_) {}
      }
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, e.message),
        success: false,
        message: e.message,
      );
    } catch (e) {
      if (orderId != null) {
        try {
          await _settlement.refundOrder(
            orderId: orderId,
            reason: e.toString(),
          );
        } catch (_) {}
      }
      return MarketplaceCheckoutResult(
        order: _failedOrder(userId, paymentMethod, e.toString()),
        success: false,
        message: e.toString(),
      );
    }
  }

  MarketplaceOrder _failedOrder(
    String userId,
    MarketplacePaymentMethod paymentMethod,
    String message,
  ) {
    return MarketplaceOrder(
      id: 'failed_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      items: const [],
      subtotalAmount: 0,
      totalAmount: 0,
      paymentMethod: paymentMethod,
      status: MarketplaceOrderStatus.failed,
      createdAt: DateTime.now(),
      deliveryInfo: message,
    );
  }

  @override
  Future<MarketplaceOrder> updateOrderStatus(
    String orderId,
    MarketplaceOrderStatus status,
  ) async =>
      _adminUnsupported('updateOrderStatus');

  // ── Rewards & Notifications (Kasby-native) ──

  @override
  Future<List<MarketplaceReward>> getRewards() async => const [];

  @override
  Future<MarketplaceReward> claimReward(String rewardId) async =>
      _adminUnsupported('claimReward');

  @override
  Future<List<MarketplaceNotification>> getNotifications() async => const [];

  @override
  Future<void> markNotificationRead(String id) async {}

  // ── Settings & Analytics ──

  @override
  Future<MarketplaceSettings> getSettings() async => const MarketplaceSettings(
        isEnabled: true,
        walletPaymentEnabled: true,
        kspPaymentEnabled: true,
        maintenanceMode: false,
      );

  @override
  Future<MarketplaceSettings> updateSettings(MarketplaceSettings settings) async =>
      _adminUnsupported('updateSettings');

  @override
  Future<MarketplaceDashboardStats> getDashboardStats() async =>
      _adminUnsupported('getDashboardStats');

  @override
  Future<List<Map<String, dynamic>>> getRevenueByCategory() async =>
      _adminUnsupported('getRevenueByCategory');

  @override
  Future<Map<String, dynamic>> getMarketplaceHealth() async {
    await _ensureCatalogLoaded();
    final healthData = await _client.getHealthStatus();
    final dbSummary = await _orderStore.getHealthSummary();

    return {
      'provider': 'reloadly',
      'catalogCount': _listings?.length ?? healthData['catalogCount'] ?? 0,
      'error': _loadError,
      'environment': ReloadlyConfig.environment,
      ...healthData,
      ...dbSummary,
    };
  }
}

extension _FirstOrNullReloadly<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
