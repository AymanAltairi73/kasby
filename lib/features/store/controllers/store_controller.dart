import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/snack_service.dart';
import '../services/store_service.dart';
import '../models/topup_service.dart';
import '../models/store_cart_item.dart';
import 'store_cart_controller.dart';

class StoreController extends GetxController {
  static StoreController get to => Get.find();

  final StoreService storeService;

  StoreController({required this.storeService});

  final RxBool isLoading = false.obs;
  final RxBool isCheckingOut = false.obs;
  final RxList<TopupService> services = <TopupService>[].obs;
  final RxString selectedCategory = 'all'.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedPaymentMethod = 'wallet'.obs; // 'wallet' or 'ksp'

  @override
  void onInit() {
    super.onInit();
    fetchServices();
  }

  Future<void> fetchServices() async {
    isLoading.value = true;
    try {
      final list = await storeService.fetchCatalog();
      services.assignAll(list);
      _log('Fetched ${list.length} services successfully');
    } catch (e) {
      _log('Failed to fetch services: $e', isError: true);
      AppSnack.error('خطأ', 'تعذر تحميل منتجات المتجر');
    } finally {
      isLoading.value = false;
    }
  }

  List<TopupService> get filteredServices {
    debugPrint('==================================================');
    debugPrint('[STORE_CONTROLLER] STEP 4: Controller Filtering');
    debugPrint('[STORE_CONTROLLER] Total Services Loaded: ${services.length}');
    debugPrint('[STORE_CONTROLLER] Filter - Category: "${selectedCategory.value}", Search: "${searchQuery.value}"');

    final result = services.where((s) {
      // Category filter
      if (selectedCategory.value != 'all' && s.flow != selectedCategory.value) {
        return false;
      }

      // Search query filter
      if (searchQuery.value.trim().isNotEmpty) {
        final query = searchQuery.value.toLowerCase().trim();
        final matchName = s.name.toLowerCase().contains(query);
        final matchDesc = s.description.toLowerCase().contains(query);
        final matchProduct = s.products.any((p) =>
            p.productLabel.toLowerCase().contains(query) ||
            p.game.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query));
        return matchName || matchDesc || matchProduct;
      }

      return true;
    }).toList();

    debugPrint('[STORE_CONTROLLER] Visible Services after filtering: ${result.length}');
    final visibleProductsCount = result.fold(0, (sum, s) => sum + s.products.length);
    debugPrint('[STORE_CONTROLLER] Visible Products Count: $visibleProductsCount');
    debugPrint('==================================================');

    return result;
  }

  /// Purchase a single cart item directly
  Future<bool> checkoutSingleItem(StoreCartItem item) async {
    isCheckingOut.value = true;
    try {
      final result = await storeService.processCartItemCheckout(
        item: item,
        paymentMethod: selectedPaymentMethod.value,
      );

      if (result.success) {
        AppSnack.success('تم بنجاح', result.message);
        return true;
      } else {
        AppSnack.error('فشل الطلب', result.message);
        return false;
      }
    } catch (e) {
      _log('Checkout exception: $e', isError: true);
      AppSnack.error('خطأ', 'حدث خطأ غير متوقع أثناء الدفع');
      return false;
    } finally {
      isCheckingOut.value = false;
    }
  }

  /// Purchase all items in cart sequentially
  Future<void> checkoutCart() async {
    final cart = StoreCartController.to;
    if (cart.cartItems.isEmpty) {
      AppSnack.warning('تنبيه', 'السلة فارغة');
      return;
    }

    isCheckingOut.value = true;
    int successCount = 0;
    int failCount = 0;

    try {
      final itemsToProcess = List<StoreCartItem>.from(cart.cartItems);
      for (final item in itemsToProcess) {
        final result = await storeService.processCartItemCheckout(
          item: item,
          paymentMethod: selectedPaymentMethod.value,
        );

        if (result.success) {
          successCount++;
        } else {
          failCount++;
          _log('Item checkout failed: ${result.message}', isError: true);
        }
      }

      cart.clearCart();

      if (failCount == 0) {
        AppSnack.success('تم الشراء', 'تم تنفيذ جميع طلبات السلة بنجاح');
      } else if (successCount > 0) {
        AppSnack.warning(
          'تنفيذ جزئي',
          'تم تنفيذ $successCount طلبات بنجاح وفشل $failCount طلبات',
        );
      } else {
        AppSnack.error('فشل الشراء', 'تعذر تنفيذ طلبات السلة');
      }
    } catch (e) {
      _log('Cart checkout exception: $e', isError: true);
      AppSnack.error('خطأ', 'حدث خطأ أثناء تنفيذ السلة');
    } finally {
      isCheckingOut.value = false;
    }
  }

  void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      print('[STORE_CONTROLLER] ${isError ? '❌' : 'ℹ️'} $message');
    }
  }
}
