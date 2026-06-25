import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import '../../domain/models/marketplace_product_variant.dart';

class MarketplaceVariantSelector extends StatelessWidget {
  final List<MarketplaceProductVariant> variants;
  final MarketplaceProductVariant? selected;
  final ValueChanged<MarketplaceProductVariant> onSelected;

  const MarketplaceVariantSelector({
    super.key,
    required this.variants,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'en';
    return Wrap(
      spacing: KasbySpacing.sm,
      runSpacing: KasbySpacing.sm,
      children: variants.map((v) {
        final isSelected = selected?.id == v.id;
        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.localizedName(locale), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('\$${v.walletPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: AppColors.darkGold)),
            ],
          ),
          selected: isSelected,
          selectedColor: AppColors.darkGold.withValues(alpha: 0.2),
          onSelected: v.isAvailable ? (_) => onSelected(v) : null,
        );
      }).toList(),
    );
  }
}
