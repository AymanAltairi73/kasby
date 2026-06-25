import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import '../../domain/models/marketplace_category.dart';

class MarketplaceCategoryChip extends StatelessWidget {
  final MarketplaceCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const MarketplaceCategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  IconData _iconFor(String name) {
    switch (name) {
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'new_releases':
        return Icons.new_releases_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'en';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KasbyMotion.normal,
        margin: const EdgeInsets.only(right: KasbySpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: KasbySpacing.md,
          vertical: KasbySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkGold.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(KasbyRadius.chip),
          border: Border.all(
            color: isSelected ? AppColors.darkGold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(category.iconName),
              size: 18,
              color: isSelected ? AppColors.darkGold : Colors.grey,
            ),
            const SizedBox(width: KasbySpacing.sm),
            Text(
              category.localizedName(locale),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.darkGold : null,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
