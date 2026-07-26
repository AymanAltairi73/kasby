import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header title
            Row(
              children: [
                const Icon(Icons.shopping_cart_checkout, color: AppColors.primaryGold),
                const SizedBox(width: 8),
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
            const SizedBox(height: 16),

            // Selected Product preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202028) : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A35) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: widget.product.imageUrl != null &&
                            widget.product.imageUrl!.isNotEmpty
                        ? Image.network(widget.product.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.card_giftcard, color: AppColors.primaryGold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.nameAr,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'التسليم: تلقائي فوري',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedMethod == 'wallet'
                        ? AppColors.primaryGold
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppColors.primaryGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رصيد المحفظة بالدولار (USD Wallet)',
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
                        fontSize: 15,
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedMethod == 'ksp' ? Colors.amber : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رصيد عملة KSP',
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
                          fontSize: 15,
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
                            ? 'رصيد المحفظة بالدولار غير كافٍ لإتمام عملية الشراء.'
                            : 'رصيد نقاط KSP غير كافٍ لإتمام عملية الشراء.',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buy Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    : const Text(
                        'تأكيد الدفع والشراء الآن',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
          backgroundColor: const Color(0xFF1A1A22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
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
              const SizedBox(height: 16),

              // Code Display Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111116),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGold),
                ),
                child: Column(
                  children: [
                    const Text(
                      'الكود الخاص بك:',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
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
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        AppSnack.success(
                          'تم نسخ الكود',
                          'تم نسخ كود البطاقة إلى الحافظة بنجاح.',
                        );
                      },
                      icon: const Icon(Icons.copy, color: AppColors.primaryGold, size: 18),
                      label: const Text(
                        'نسخ الكود',
                        style: TextStyle(color: AppColors.primaryGold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
