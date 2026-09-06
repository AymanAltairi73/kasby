import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/store/domain/models/store_order_model.dart';

class StoreOrderCard extends StatelessWidget {
  final StoreOrderModel order;

  const StoreOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B1B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final dateStr =
        '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Product name & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.productName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'marketplace_delivered'.tr,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Order details row
          Row(
            children: [
              Text(
                '${'marketplace_order_number'.tr}: ${order.orderNumber}',
                style: TextStyle(
                  color: isDark
                      ? Colors.grey[500]
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(
                  color: isDark
                      ? Colors.grey[500]
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                order.paymentMethod == 'ksp'
                    ? '${order.amount.toStringAsFixed(0)} KSP'
                    : '\$${order.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.paymentMethod == 'ksp'
                      ? 'ksp_points_badge'.tr
                      : 'usd_wallet_badge'.tr,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Delivered Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121216) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.grey.withValues(alpha: 0.2)
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_outlined,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'card_code_received'.tr,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[500]
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                        ),
                      ),
                      SelectableText(
                        order.deliveryCode,
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                      if (order.serialNumber != null &&
                          order.serialNumber!.isNotEmpty)
                        Text(
                          'S/N: ${order.serialNumber}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[500]
                                : AppColors.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: order.deliveryCode));
                    AppSnack.success('copied'.tr, 'code_copied_success'.tr);
                  },
                  icon: const Icon(
                    Icons.copy,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
                  tooltip: 'marketplace_copy_code'.tr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
