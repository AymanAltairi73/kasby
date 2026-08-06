import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/sound_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/store/domain/models/store_banner_model.dart';
import 'package:kasby/features/store/domain/models/store_category_model.dart';
import 'package:kasby/features/store/domain/models/store_order_model.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';
import 'package:kasby/features/store/domain/services/store_service.dart';

class StoreController extends GetxController {
  static StoreController get to => Get.find();

  final StoreService _service = StoreService();

  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;

  final RxList<StoreBannerModel> banners = <StoreBannerModel>[].obs;
  final RxList<StoreCategoryModel> categories = <StoreCategoryModel>[].obs;
  final RxList<StoreProductModel> allProducts = <StoreProductModel>[].obs;
  final RxList<StoreProductModel> topSellingProducts =
      <StoreProductModel>[].obs;
  final RxList<StoreProductModel> latestProducts = <StoreProductModel>[].obs;
  final RxList<StoreProductModel> offerProducts = <StoreProductModel>[].obs;
  final RxList<StoreProductModel> suggestedProducts = <StoreProductModel>[].obs;

  final Rxn<StoreCategoryModel> selectedCategory = Rxn<StoreCategoryModel>();
  final RxList<StoreProductModel> categoryProducts = <StoreProductModel>[].obs;

  final RxList<StoreOrderModel> orders = <StoreOrderModel>[].obs;

  final RxString searchQuery = ''.obs;
  final RxDouble usdBalance = 0.0.obs;
  final RxDouble kspBalance = 0.0.obs;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _reloadDebounce;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _subscribeToMarketplaceChanges();
  }

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _reloadDebounce?.cancel();
    super.onClose();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchUserBalances(),
        fetchBanners(),
        fetchCategories(),
        fetchCatalog(),
        fetchOrders(),
      ]);
    } catch (e) {
      debugPrint('[STORE_CONTROLLER] Error during refreshAll: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchUserBalances() async {
    try {
      if (Get.isRegistered<CurrencyController>()) {
        usdBalance.value = CurrencyController.to.totalBalance.value;
      }
      if (Get.isRegistered<HomeController>()) {
        kspBalance.value = HomeController.to.pointsBalance.toDouble();
      } else {
        final userId = SupabaseService.userId;
        if (userId != null) {
          final walletRes = await SupabaseService.client
              .from('wallets')
              .select('available_balance')
              .eq('user_id', userId)
              .maybeSingle();

          if (walletRes != null) {
            usdBalance.value =
                (walletRes['available_balance'] as num?)?.toDouble() ?? 0.0;
          }

          final kspRes = await SupabaseService.client
              .from('user_points')
              .select('current_balance')
              .eq('user_id', userId)
              .maybeSingle();

          if (kspRes != null) {
            kspBalance.value =
                (kspRes['current_balance'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('[STORE_CONTROLLER] Error fetching balances: $e');
    }
  }

  Future<void> fetchBanners() async {
    banners.value = await _service.fetchBanners();
  }

  Future<void> fetchCategories() async {
    categories.value = await _service.fetchCategories();
  }

  Future<void> fetchCatalog() async {
    final products = await _service.fetchProducts();
    allProducts.value = products;

    topSellingProducts.value = products.where((p) => p.isTopSelling).toList();
    latestProducts.value = products.where((p) => p.isNew).toList();
    offerProducts.value = products.where((p) => p.discountPercent > 0).toList();
    suggestedProducts.value = products.where((p) => p.isFeatured).toList();

    // Fallbacks if active flags are empty
    if (topSellingProducts.isEmpty && products.isNotEmpty) {
      topSellingProducts.value = products.take(5).toList();
    }
    if (latestProducts.isEmpty && products.isNotEmpty) {
      latestProducts.value = products.reversed.take(5).toList();
    }
    if (suggestedProducts.isEmpty && products.isNotEmpty) {
      suggestedProducts.value = products.skip(1).take(5).toList();
    }
  }

  Future<void> fetchCategoryProducts(String categoryId) async {
    categoryProducts.value = await _service.fetchProducts(
      categoryId: categoryId,
    );
  }

  Future<void> fetchOrders() async {
    orders.value = await _service.fetchOrders();
  }

  void _subscribeToMarketplaceChanges() {
    const tables = <String>[
      'marketplace_categories',
      'marketplace_products',
      'marketplace_digital_codes',
      'marketplace_banners',
      'marketplace_orders',
    ];

    for (final table in tables) {
      _subscriptions.add(
        SupabaseService.client
            .from(table)
            .stream(primaryKey: ['id'])
            .listen(
              (_) {
                _reloadDebounce?.cancel();
                _reloadDebounce = Timer(
                  const Duration(milliseconds: 500),
                  refreshAll,
                );
              },
              onError: (error) {
                debugPrint(
                  '[STORE_CONTROLLER] Realtime error on $table: $error',
                );
              },
            ),
      );
    }
  }

  void selectCategory(StoreCategoryModel category) {
    selectedCategory.value = category;
    fetchCategoryProducts(category.id);
    Get.toNamed('/store-products');
  }

  List<StoreProductModel> get filteredProducts {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return allProducts;
    return allProducts.where((p) {
      return p.nameAr.toLowerCase().contains(query) ||
          p.nameEn.toLowerCase().contains(query) ||
          p.descriptionAr.toLowerCase().contains(query);
    }).toList();
  }

  Future<Map<String, dynamic>> executePurchase({
    required StoreProductModel product,
    required String paymentMethod,
  }) async {
    if (isPurchasing.value) return {'success': false};
    isPurchasing.value = true;
    try {
      final result = await _service.buyProduct(
        productId: product.id,
        paymentMethod: paymentMethod,
      );

      if (result['success'] == true) {
        SoundService.to.playPurchase();
        AppSnack.success(
          'purchase_success_title'.tr,
          'purchase_success_desc'.tr,
        );
        fetchUserBalances();
        fetchOrders();
        fetchCatalog();
        if (selectedCategory.value != null) {
          fetchCategoryProducts(selectedCategory.value!.id);
        }
      } else {
        final errorMsg =
            result['message_ar'] as String? ?? 'purchase_failed'.tr;
        AppSnack.error('purchase_error_title'.tr, errorMsg);
      }
      return result;
    } catch (e) {
      AppSnack.error('error'.tr, '${'operation_error'.tr} ($e)');
      return {'success': false, 'error': e.toString()};
    } finally {
      isPurchasing.value = false;
    }
  }
}
