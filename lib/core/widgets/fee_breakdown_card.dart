import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/fee_service.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Shows expected fees with rate percentage for wallet operations.
class FeeBreakdownCard extends StatelessWidget {
  const FeeBreakdownCard({
    super.key,
    required this.category,
    required this.amount,
    this.compact = false,
  });

  final String category;
  final double amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fee = FeeService.totalFee(category, amount);
    final rateLabel = FeeService.feeRateLabel(category);
    final lines = FeeService.feeDescriptionLines(category, amount);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surface : AppColors.surfaceLight)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'expected_fee'.tr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                fee > 0 ? '-\$${fee.toStringAsFixed(2)}' : '\$0.00',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: fee > 0 ? AppColors.error : AppColors.softGreen,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
          if (rateLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'fee_rate_label'.trParams({'rate': rateLabel}),
              style: TextStyle(
                color: AppColors.darkGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (fee <= 0) ...[
            const SizedBox(height: 4),
            Text(
              'no_fee_applied'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if (!compact && lines.isNotEmpty && amount > 0) ...[
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $line',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          if (amount > 0 && fee > 0) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'net_amount'.tr,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '\$${(amount - fee).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.softGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
