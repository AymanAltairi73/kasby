import 'package:get/get.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/marketplace_coupon.dart';
import '../../domain/models/marketplace_order.dart';
import '../../domain/repositories/marketplace_repository.dart';
import 'marketplace_cart_controller.dart';

class MarketplaceCheckoutController extends GetxController {
  final MarketplaceRepository _repo;

  MarketplaceCheckoutController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final selectedPayment = MarketplacePaymentMethod.wallet.obs;
  final isProcessing = false.obs;
  final termsAccepted = false.obs;
  final couponCode = ''.obs;
  final appliedCoupon = Rxn<MarketplaceCoupon>();
  final couponError = RxnString();
  final completedOrder = Rxn<MarketplaceOrder>();
  final showSuccess = false.obs;
  final _uuid = const Uuid();
  String? _checkoutIdempotencyKey;

  int get effectiveKsp => KspBalanceService.to.effectiveKsp.value;

  int get kspCheckoutCost => total.ceil();

  @override
  void onInit() {
    super.onInit();
    if (SupabaseService.isLoggedIn && Get.isRegistered<KspBalanceService>()) {
      KspBalanceService.to.refresh();
    }
  }

  double get subtotal => MarketplaceCartController.to.walletSubtotal;

  double get discountAmount => appliedCoupon.value?.calculateDiscount(subtotal) ?? 0;

  double get total => (subtotal - discountAmount).clamp(0, double.infinity);

  Future<void> applyCoupon() async {
    couponError.value = null;
    if (couponCode.value.trim().isEmpty) return;
    final coupon = await _repo.validateCoupon(couponCode.value.trim(), subtotal);
    if (coupon == null) {
      appliedCoupon.value = null;
      couponError.value = 'marketplace_coupon_invalid'.tr;
      return;
    }
    appliedCoupon.value = coupon;
  }

  void removeCoupon() {
    appliedCoupon.value = null;
    couponCode.value = '';
    couponError.value = null;
  }

  Future<bool> processCheckout() async {
    final cart = MarketplaceCartController.to;
    if (cart.isEmpty || !termsAccepted.value) return false;

    isProcessing.value = true;
    try {
      final userId = SupabaseService.userId ?? 'guest_user';
      _checkoutIdempotencyKey ??= _uuid.v4();
      final result = await _repo.placeOrder(
        userId: userId,
        items: cart.cartItems.toList(),
        paymentMethod: selectedPayment.value,
        couponCode: appliedCoupon.value?.code ?? couponCode.value.trim(),
        discountAmount: discountAmount,
        idempotencyKey: _checkoutIdempotencyKey,
        termsAccepted: termsAccepted.value,
      );
      if (!result.success) {
        SafeGetx.snackbar(title: 'marketplace'.tr, message: result.message ?? 'marketplace_order_failed'.tr);
        return false;
      }
      completedOrder.value = result.order;
      showSuccess.value = true;
      _checkoutIdempotencyKey = null;
      await cart.clearCart();
      return true;
    } catch (e, st) {
      SafeGetx.debugTrace(className: 'MarketplaceCheckoutController', method: 'processCheckout', feature: 'Marketplace', status: 'FAILED', error: e, stackTrace: st);
      SafeGetx.snackbar(title: 'marketplace'.tr, message: 'marketplace_order_failed'.tr);
      return false;
    } finally {
      isProcessing.value = false;
    }
  }
}
