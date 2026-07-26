import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_category_model.dart';

class StoreCategoryCard extends StatelessWidget {
  final StoreCategoryModel category;
  final VoidCallback onTap;
  final bool isSelected;

  const StoreCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.isSelected = false,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'sports_esports':
      case 'games':
        return Icons.sports_esports_rounded;
      case 'card_giftcard':
      case 'gift_card':
        return Icons.card_giftcard_rounded;
      case 'subscriptions':
      case 'subscription':
        return Icons.subscriptions_rounded;
      case 'account_balance_wallet':
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'apps':
        return Icons.apps_rounded;
      case 'wifi':
      case 'internet':
        return Icons.wifi_rounded;
      case 'local_offer':
      case 'offers':
        return Icons.local_offer_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isSelected
        ? AppColors.primaryGold.withValues(alpha: 0.15)
        : (isDark ? const Color(0xFF1B1B22) : Colors.white);
    final textColor = isSelected
        ? AppColors.primaryGold
        : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGold
                  : AppColors.primaryGold.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primaryGold.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGold.withValues(alpha: 0.2),
                      AppColors.primaryGold.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                            _getIconData(category.iconName),
                            color: AppColors.primaryGold,
                            size: 22,
                          ),
                        )
                      : Icon(
                          _getIconData(category.iconName),
                          color: AppColors.primaryGold,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
