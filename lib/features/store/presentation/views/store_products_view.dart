import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';
import 'package:kasby/features/store/presentation/widgets/store_product_card.dart';

class StoreProductsView extends StatelessWidget {
  const StoreProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoreController.to;
    final category = controller.selectedCategory.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.onSurfaceLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          category != null ? category.nameAr : 'منتجات القسم',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        if (controller.categoryProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: isDark
                      ? Colors.grey[600]
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد منتجات متوفرة في هذا القسم حالياً',
                  style: TextStyle(
                    color: isDark
                        ? Colors.grey[400]
                        : AppColors.textSecondaryLight,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: controller.categoryProducts.length,
          itemBuilder: (context, index) {
            final prod = controller.categoryProducts[index];
            return StoreProductCard(
              product: prod,
              onTap: () {
                Get.toNamed(
                  '/store-product-detail',
                  arguments: {'product': prod},
                );
              },
            );
          },
        );
      }),
    );
  }
}
