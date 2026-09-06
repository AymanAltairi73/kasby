import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';
import 'package:kasby/features/store/presentation/widgets/store_category_card.dart';

class StoreCategoriesView extends StatelessWidget {
  const StoreCategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoreController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.onSurfaceLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'store_all_categories'.tr,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        if (controller.categories.isEmpty) {
          return Center(
            child: Text(
              'store_no_categories'.tr,
              style: TextStyle(
                color: isDark ? Colors.grey : AppColors.textSecondaryLight,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.95,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: controller.categories.length,
          itemBuilder: (context, index) {
            final cat = controller.categories[index];
            return StoreCategoryCard(
              category: cat,
              onTap: () => controller.selectCategory(cat),
            );
          },
        );
      }),
    );
  }
}
