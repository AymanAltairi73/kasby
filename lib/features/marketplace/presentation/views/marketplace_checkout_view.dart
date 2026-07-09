import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/services/transaction_auth_service.dart';
import '../../domain/models/marketplace_order.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_checkout_controller.dart';
import '../widgets/marketplace_checkout_success_dialog.dart';

class MarketplaceCheckoutView extends StatelessWidget {
  const MarketplaceCheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final checkout = Get.put(MarketplaceCheckoutController());
    final cart = MarketplaceCartController.to;
    final locale = Get.locale?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('marketplace_checkout'.tr)),
      body: Obx(() {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(KasbySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('marketplace_order_summary'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: KasbySpacing.md),
              ...cart.cartItems.map((item) {
                final l = item.listing;
                return Card(
                  margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(KasbyRadius.chip),
                      child: Image.network(l.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                    title: Text(l.localizedDisplayName(locale)),
                    subtitle: Text('${l.localizedVariantName(locale)} x${item.quantity}'),
                    trailing: Text('\$${item.walletSubtotal.toStringAsFixed(2)}'),
                  ),
                );
              }),
              const Divider(height: KasbySpacing.xl),
              _row('marketplace_subtotal'.tr, '\$${checkout.subtotal.toStringAsFixed(2)}'),
              if (checkout.discountAmount > 0)
                _row('marketplace_discount'.tr, '-\$${checkout.discountAmount.toStringAsFixed(2)}', color: AppColors.softGreen),
              _row('marketplace_total'.tr, '\$${checkout.total.toStringAsFixed(2)}', bold: true),
              const SizedBox(height: KasbySpacing.lg),
              Text('marketplace_coupon'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: KasbySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: KasbyTextField(
                      hint: 'marketplace_coupon_hint'.tr,
                      onChanged: (v) => checkout.couponCode.value = v,
                    ),
                  ),
                  const SizedBox(width: KasbySpacing.sm),
                  KasbyButton(
                    text: 'apply_filters'.tr,
                    isSecondary: true,
                    onPressed: checkout.applyCoupon,
                  ),
                ],
              ),
              if (checkout.couponError.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: KasbySpacing.sm),
                  child: Text(checkout.couponError.value!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (checkout.appliedCoupon.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: KasbySpacing.sm),
                  child: Chip(
                    label: Text(checkout.appliedCoupon.value!.code),
                    onDeleted: checkout.removeCoupon,
                  ),
                ),
              const SizedBox(height: KasbySpacing.lg),
              Text('marketplace_payment_method'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: KasbySpacing.md),
              _paymentTile(checkout, MarketplacePaymentMethod.wallet, Icons.account_balance_wallet_rounded, 'marketplace_pay_wallet'.tr),
              _paymentTile(checkout, MarketplacePaymentMethod.ksp, Icons.diamond_rounded, 'marketplace_pay_ksp'.tr),
              Obx(() {
                if (checkout.selectedPayment.value != MarketplacePaymentMethod.ksp) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: KasbySpacing.sm),
                  child: Text(
                    '${'ksp_balance'.tr}: ${checkout.effectiveKsp} KSP · ${'marketplace_ksp_cost'.tr}: ${checkout.kspCheckoutCost} KSP',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              const SizedBox(height: KasbySpacing.lg),
              Text('marketplace_estimated_delivery'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('marketplace_delivery_instant'.tr, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: KasbySpacing.lg),
              CheckboxListTile(
                value: checkout.termsAccepted.value,
                onChanged: (v) => checkout.termsAccepted.value = v ?? false,
                activeColor: AppColors.darkGold,
                title: Text('marketplace_accept_terms'.tr),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: KasbySpacing.lg),
              KasbyButton(
                text: 'confirm_payment'.tr,
                width: double.infinity,
                isLoading: checkout.isProcessing.value,
                onPressed: checkout.isProcessing.value || !checkout.termsAccepted.value
                    ? null
                    : () => _confirmAndPay(context, checkout),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _confirmAndPay(BuildContext context, MarketplaceCheckoutController checkout) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('confirm_payment'.tr),
        content: Text('marketplace_confirm_payment_message'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('confirm'.tr)),
        ],
      ),
    );
    if (confirmed != true) return;

    final authOk = await TransactionAuthService.to.requireConfirmation(
      purpose: 'marketplace_checkout',
    );
    if (!authOk) return;

    final ok = await checkout.processCheckout();
    if (ok && checkout.completedOrder.value != null) {
      MarketplaceCheckoutSuccessDialog.show(checkout.completedOrder.value!);
    }
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 20 : 16,
              color: color ?? (bold ? AppColors.darkGold : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(MarketplaceCheckoutController checkout, MarketplacePaymentMethod method, IconData icon, String title) {
    return Obx(() {
      final selected = checkout.selectedPayment.value == method;
      return Card(
        margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KasbyRadius.card),
          side: BorderSide(color: selected ? AppColors.darkGold : Colors.transparent, width: 2),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.darkGold),
          title: Text(title),
          trailing: Radio<MarketplacePaymentMethod>(
            value: method,
            groupValue: checkout.selectedPayment.value,
            activeColor: AppColors.darkGold,
            onChanged: (val) { if (val != null) checkout.selectedPayment.value = val; },
          ),
          onTap: () => checkout.selectedPayment.value = method,
        ),
      );
    });
  }
}
