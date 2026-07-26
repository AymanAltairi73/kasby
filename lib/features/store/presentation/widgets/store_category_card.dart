import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_category_model.dart';

class StoreCategoryCard extends StatelessWidget {
  final StoreCategoryModel category;
  final VoidCallback onTap;

  const StoreCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'sports_esports':
      case 'games':
        return Icons.sports_esports;
      case 'card_giftcard':
      case 'gift_card':
        return Icons.card_giftcard;
      case 'subscriptions':
      case 'subscription':
        return Icons.subscriptions;
      case 'account_balance_wallet':
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'apps':
        return Icons.apps;
      case 'wifi':
      case 'internet':
        return Icons.wifi;
      case 'local_offer':
      case 'offers':
        return Icons.local_offer;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B1B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.2),
                    AppColors.primaryGold.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                  ? Image.network(
                      category.imageUrl!,
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) => Icon(
                        _getIconData(category.iconName),
                        color: AppColors.primaryGold,
                        size: 26,
                      ),
                    )
                  : Icon(
                      _getIconData(category.iconName),
                      color: AppColors.primaryGold,
                      size: 26,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              category.nameAr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
