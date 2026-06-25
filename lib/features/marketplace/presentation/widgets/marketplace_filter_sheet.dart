import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';

class MarketplaceFilterSheet extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onApply;

  const MarketplaceFilterSheet({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    required this.onApply,
  });

  static void show({
    required String currentSort,
    required ValueChanged<String> onSortChanged,
    required VoidCallback onApply,
  }) {
    Get.bottomSheet(
      MarketplaceFilterSheet(
        currentSort: currentSort,
        onSortChanged: onSortChanged,
        onApply: onApply,
      ),
      backgroundColor: Get.theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KasbyRadius.sheet)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: KasbySpacing.lg),
          Text(
            'marketplace_filter_sort'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: KasbySpacing.md),
          _sortTile('default', 'marketplace_sort_default'.tr),
          _sortTile('price_asc', 'marketplace_sort_price_low'.tr),
          _sortTile('price_desc', 'marketplace_sort_price_high'.tr),
          _sortTile('rating', 'marketplace_sort_rating'.tr),
          const SizedBox(height: KasbySpacing.lg),
          KasbyButton(
            text: 'apply_filters'.tr,
            onPressed: () {
              onApply();
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  Widget _sortTile(String value, String label) {
    return RadioListTile<String>(
      value: value,
      groupValue: currentSort,
      activeColor: AppColors.darkGold,
      title: Text(label),
      onChanged: (v) {
        if (v != null) onSortChanged(v);
      },
    );
  }
}
