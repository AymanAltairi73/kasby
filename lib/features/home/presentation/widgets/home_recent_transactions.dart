import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/localization/model_localization_extensions.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
import 'package:kasby/core/widgets/directional_chevron.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onSeeAll,
  });

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: KasbyTypography.sectionHeader(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            'see_all'.tr,
            style: TextStyle(color: AppColors.darkGold),
          ),
        ),
      ],
    );
  }
}

class HomeRecentTransactions extends StatelessWidget {
  const HomeRecentTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeController = HomeController.to;
    final currencyController = CurrencyController.to;

    return Obx(() {
      final transactions = homeController.recentTransactions.take(3).toList();

      if (homeController.isLoadingTransactions.value) {
        return Column(
          children: List.generate(
            3,
            (i) => const KasbyShimmer.listItem(
              margin: EdgeInsets.only(bottom: 12),
            ),
          ),
        );
      }

      if (transactions.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'no_transactions'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        );
      }

      return Column(
        children: transactions.map((tx) {
          final isOut = tx.isDebit;
          return Semantics(
            button: true,
            label: tx.localizedDescription,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Get.toNamed(
                  Routes.transactionDetails,
                  arguments: {'transaction': tx, 'heroTag': 'home_tx_${tx.id}'},
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isOut ? AppColors.error : AppColors.softGreen)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isOut
                            ? Icons.arrow_outward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isOut ? AppColors.error : AppColors.softGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.localizedDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: KasbyTypography.sp(
                                ar: 13.0,
                                en: 12.0,
                                context: context,
                              ),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx.createdAt != null
                                ? DateHelper.dateTime(tx.createdAt)
                                : '',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                              fontSize: KasbyTypography.sp(
                                ar: 11.0,
                                en: 10.0,
                                context: context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${isOut ? '-' : '+'}${currencyController.formatAmount(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isOut
                                ? AppColors.error
                                : AppColors.softGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    DirectionalChevron(
                      size: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}
