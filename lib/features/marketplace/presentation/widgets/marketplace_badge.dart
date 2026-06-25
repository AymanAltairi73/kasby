import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';

class MarketplaceBadge extends StatelessWidget {
  final String label;
  final Color color;

  const MarketplaceBadge({
    super.key,
    required this.label,
    required this.color,
  });

  factory MarketplaceBadge.featured() => MarketplaceBadge(
        label: 'Featured',
        color: AppColors.darkGold,
      );

  factory MarketplaceBadge.popular() => MarketplaceBadge(
        label: 'Popular',
        color: AppColors.softGreen,
      );

  factory MarketplaceBadge.discount(int percent) => MarketplaceBadge(
        label: '-$percent%',
        color: Colors.redAccent,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KasbySpacing.sm,
        vertical: KasbySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(KasbyRadius.chip),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
