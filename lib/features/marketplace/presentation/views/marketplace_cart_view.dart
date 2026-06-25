import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart' show Routes;
import '../controllers/marketplace_cart_controller.dart';

class MarketplaceCartView extends StatelessWidget {
  const MarketplaceCartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = MarketplaceCartController.to;
    final locale = Get.locale?.languageCode ?? 'en';

    return Scaffold(
      appBar: AppBar(title: Text('marketplace_cart'.tr)),
      body: Obx(() {
        if (cart.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(KasbySpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 72, color: AppColors.darkGold.withValues(alpha: 0.5)),
                  const SizedBox(height: KasbySpacing.lg),
                  Text('marketplace_cart_empty'.tr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: KasbySpacing.sm),
                  Text('marketplace_cart_empty_desc'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: KasbySpacing.xl),
                  KasbyButton(
                    text: 'marketplace_browse'.tr,
                    onPressed: () => Get.offNamed(Routes.marketplace),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(KasbySpacing.lg),
                itemCount: cart.cartItems.length,
                itemBuilder: (_, i) {
                  final item = cart.cartItems[i];
                  final l = item.listing;
                  return Card(
                    margin: const EdgeInsets.only(bottom: KasbySpacing.md),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(KasbyRadius.chip),
                        child: Image.network(l.imageUrl,
                            width: 48, height: 48, fit: BoxFit.cover),
                      ),
                      title: Text(l.localizedDisplayName(locale)),
                      subtitle: Text(l.localizedVariantName(locale)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('x${item.quantity}'),
                          Text('\$${item.walletSubtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: AppColors.darkGold,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(KasbySpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('marketplace_total'.tr,
                          style: const TextStyle(fontSize: 18)),
                      Text('\$${cart.walletSubtotal.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGold)),
                    ],
                  ),
                  const SizedBox(height: KasbySpacing.md),
                  KasbyButton(
                    text: 'marketplace_checkout'.tr,
                    onPressed: () => Get.toNamed(Routes.marketplaceCheckout),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
