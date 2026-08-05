import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';
import 'package:kasby/features/store/presentation/widgets/store_product_card.dart';

class StoreProductsView extends StatelessWidget {
  const StoreProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoreController.to;
    final category = controller.selectedCategory.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(category != null ? category.nameAr : 'منتجات القسم'),
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
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد منتجات متوفرة في هذا القسم حالياً',
                  style: TextStyle(color: Colors.grey[400], fontSize: 15),
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
