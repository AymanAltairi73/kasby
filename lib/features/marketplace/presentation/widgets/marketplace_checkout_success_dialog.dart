import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';
import '../../domain/models/marketplace_order.dart';

class MarketplaceCheckoutSuccessDialog extends StatelessWidget {
  final MarketplaceOrder order;

  const MarketplaceCheckoutSuccessDialog({super.key, required this.order});

  static void show(MarketplaceOrder order) {
    Get.dialog(
      MarketplaceCheckoutSuccessDialog(order: order),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KasbyRadius.card)),
      child: Padding(
        padding: const EdgeInsets.all(KasbySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 72, color: AppColors.softGreen)
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: KasbySpacing.lg),
            Text(
              'marketplace_payment_success'.tr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KasbySpacing.sm),
            Text('${'marketplace_order_number'.tr}: #${order.id}'),
            if (order.deliveryCode != null) ...[
              const SizedBox(height: KasbySpacing.sm),
              Text('${'marketplace_delivery_code'.tr}: ${order.deliveryCode}'),
            ],
            const SizedBox(height: KasbySpacing.lg),
            KasbyButton(
              text: 'marketplace_view_order'.tr,
              width: double.infinity,
              onPressed: () {
                Get.back();
                Get.offAllNamed(Routes.marketplaceOrderDetail, arguments: order.id);
              },
            ),
            TextButton(
              onPressed: () {
                Get.back();
                Get.offAllNamed(Routes.marketplace);
              },
              child: Text('marketplace_continue_shopping'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
