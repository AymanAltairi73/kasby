import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';

class StoreCheckoutSheet extends StatefulWidget {
  final StoreProductModel product;

  const StoreCheckoutSheet({super.key, required this.product});

  @override
  State<StoreCheckoutSheet> createState() => _StoreCheckoutSheetState();
}

class _StoreCheckoutSheetState extends State<StoreCheckoutSheet> {
  String _selectedMethod = 'wallet'; // 'wallet' or 'ksp'

  @override
  Widget build(BuildContext context) {
    final controller = StoreController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF16161D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Obx(() {
        final usdAvailable = controller.usdBalance.value;
        final kspAvailable = controller.kspBalance.value;

        final hasKsp = widget.product.kspPrice != null && widget.product.kspPrice! > 0;
        final isUsdSufficient = usdAvailable >= widget.product.walletPrice;
        final isKspSufficient = hasKsp && kspAvailable >= widget.product.kspPrice!;

        final isCurrentSufficient =
            _selectedMethod == 'wallet' ? isUsdSufficient : isKspSufficient;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout_rounded,
                      color: AppColors.primaryGold, size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  'تأكيد الدفع والشراء',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Selected Product preview card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202028) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A35) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.15)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.product.imageUrl != null &&
                              widget.product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.product.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.card_giftcard_rounded,
                                color: AppColors.primaryGold,
                              ),
                            )
                          : const Icon(Icons.card_giftcard_rounded, color: AppColors.primaryGold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.nameAr,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'التسليم: تلقائي فوري',
                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'اختر طريقة الدفع المناسبة:',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),

            // Payment Option 1: USD Wallet
            GestureDetector(
              onTap: () => setState(() => _selectedMethod = 'wallet'),
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _selectedMethod == 'wallet'
                      ? AppColors.primaryGold.withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF202028) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedMethod == 'wallet'
                        ? AppColors.primaryGold
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.primaryGold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رصيد المحفظة (USD Wallet)',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المتوفر: \$${usdAvailable.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isUsdSufficient ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${widget.product.walletPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Payment Option 2: KSP Points
            if (hasKsp)
              GestureDetector(
                onTap: () => setState(() => _selectedMethod = 'ksp'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedMethod == 'ksp'
                        ? Colors.amber.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF202028) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMethod == 'ksp' ? Colors.amber : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رصيد نقاط KSP',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'المتوفر: ${kspAvailable.toStringAsFixed(0)} KSP',
                              style: TextStyle(
                                color: isKspSufficient ? Colors.green : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.product.kspPrice!.toStringAsFixed(0)} KSP',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Error notice if insufficient balance
            if (!isCurrentSufficient)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMethod == 'wallet'
                            ? 'رصيد المحفظة غير كافٍ لإتمام العملية.'
                            : 'رصيد نقاط KSP غير كافٍ لإتمام العملية.',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buy Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: (!isCurrentSufficient || controller.isPurchasing.value)
                    ? null
                    : () async {
                        final res = await controller.executePurchase(
                          product: widget.product,
                          paymentMethod: _selectedMethod,
                        );

                        if (res['success'] == true) {
                          Get.back(); // close sheet
                          _showSuccessDeliveryModal(
                            context: Get.context!,
                            productName: widget.product.nameAr,
                            code: res['delivery_code'] as String? ?? '',
                            serialNumber: res['serial_number'] as String?,
                          );
                        }
                      },
                child: controller.isPurchasing.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'تأكيد الدفع والشراء الآن',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      }),
    );
  }

  void _showSuccessDeliveryModal({
    required BuildContext context,
    required String productName,
    required String code,
    String? serialNumber,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم الشراء والتسليم بنجاح!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                productName,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Code Display Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121216),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGold),
                ),
                child: Column(
                  children: [
                    Text(
                      'كود البطاقة الخاص بك:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (serialNumber != null && serialNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'S/N: $serialNumber',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        AppSnack.success(
                          'تم النسخ',
                          'تم نسخ كود البطاقة بنجاح.',
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primaryGold, size: 18),
                      label: const Text(
                        'نسخ الكود',
                        style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Get.back();
                        Get.toNamed('/store-orders');
                      },
                      child: const Text(
                        'سجل الطلبات',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
