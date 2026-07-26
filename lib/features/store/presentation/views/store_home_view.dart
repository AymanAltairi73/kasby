import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';
import 'package:kasby/features/store/presentation/widgets/store_banner_slider.dart';
import 'package:kasby/features/store/presentation/widgets/store_category_card.dart';
import 'package:kasby/features/store/presentation/widgets/store_product_card.dart';
import 'package:kasby/features/store/presentation/widgets/store_shimmer.dart';

class StoreHomeView extends StatelessWidget {
  const StoreHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StoreController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.storefront, color: AppColors.primaryGold, size: 28),
            SizedBox(width: 8),
            Text(
              'متجر كاسبي الرقمي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed('/store-orders'),
            icon: const Icon(Icons.receipt_long, color: AppColors.primaryGold),
            tooltip: 'طلباتي',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshAll(),
        color: AppColors.primaryGold,
        child: Obx(() {
          if (controller.isLoading.value && controller.allProducts.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const StoreShimmer(height: 150, borderRadius: 20),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 6,
                    itemBuilder: (_, __) => const StoreShimmer(height: 80, borderRadius: 16),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Balance Summary Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF231E14), Color(0xFF141318)],
                    ),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet,
                                  color: AppColors.primaryGold, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'رصيد المحفظة',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${controller.usdBalance.value.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 35, width: 1, color: Colors.white12),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars, color: Colors.amber, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'رصيد KSP',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${controller.kspBalance.value.toStringAsFixed(0)} KSP',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (val) => controller.searchQuery.value = val,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن بطاقة، لعبة، أو اشتراك...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF181820) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primaryGold.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primaryGold.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Search Results View if Searching
                if (controller.searchQuery.value.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'نتائج البحث (${controller.filteredProducts.length})',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProductGrid(controller.filteredProducts),
                ] else ...[
                  // 3. Animated Banners Slider
                  StoreBannerSlider(banners: controller.banners),

                  const SizedBox(height: 20),

                  // 4. Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الأقسام الرئيسية',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed('/store-categories'),
                          child: const Text(
                            'عرض الكل',
                            style: TextStyle(color: AppColors.primaryGold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 95,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: controller.categories.length,
                      itemBuilder: (context, index) {
                        final cat = controller.categories[index];
                        return Container(
                          width: 105,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: StoreCategoryCard(
                            category: cat,
                            onTap: () => controller.selectCategory(cat),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Top Selling Products
                  if (controller.topSellingProducts.isNotEmpty) ...[
                    _buildSectionHeader('🔥 الأكثر مبيعاً'),
                    _buildHorizontalProductList(controller.topSellingProducts),
                    const SizedBox(height: 24),
                  ],

                  // 6. Offers Section
                  if (controller.offerProducts.isNotEmpty) ...[
                    _buildSectionHeader('🏷️ أقوى العروض والتخفيضات'),
                    _buildHorizontalProductList(controller.offerProducts),
                    const SizedBox(height: 24),
                  ],

                  // 7. Latest Products Section
                  if (controller.latestProducts.isNotEmpty) ...[
                    _buildSectionHeader('✨ أحدث المنتجات'),
                    _buildHorizontalProductList(controller.latestProducts),
                    const SizedBox(height: 24),
                  ],

                  // 8. Suggested Products Grid
                  _buildSectionHeader('⭐ منتجات مقترحة لك'),
                  _buildProductGrid(controller.allProducts.take(6).toList()),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHorizontalProductList(List<StoreProductModel> products) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final prod = products[index];
          return Container(
            width: 155,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: StoreProductCard(
              product: prod,
              onTap: () => _openProductDetail(prod),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(List<StoreProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('لا توجد منتجات مطابقة حالياً', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final prod = products[index];
        return StoreProductCard(
          product: prod,
          onTap: () => _openProductDetail(prod),
        );
      },
    );
  }

  void _openProductDetail(StoreProductModel product) {
    Get.toNamed('/store-product-detail', arguments: {'product': product});
  }
}
