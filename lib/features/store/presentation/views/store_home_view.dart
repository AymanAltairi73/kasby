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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primaryGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'متجر كاسبي الرقمي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Get.toNamed('/store-orders'),
              icon: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primaryGold,
                size: 22,
              ),
              tooltip: 'طلباتي والأكواد',
            ),
          ),
          const SizedBox(width: 12),
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
                  const StoreShimmer(height: 90, borderRadius: 20),
                  const SizedBox(height: 16),
                  const StoreShimmer(height: 155, borderRadius: 20),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: 6,
                    itemBuilder: (_, __) =>
                        const StoreShimmer(height: 80, borderRadius: 16),
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
                // ── 1. Glassmorphic Wallet & Balance Summary Card ──
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B2416), Color(0xFF16151B)],
                    ),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // USD Wallet
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: AppColors.primaryGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'رصيد المحفظة',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\$${controller.usdBalance.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Container(
                        height: 36,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),

                      // KSP Points Wallet
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'رصيد KSP',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${controller.kspBalance.value.toStringAsFixed(0)} KSP',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 2. Search Input Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: TextField(
                    onChanged: (val) => controller.searchQuery.value = val,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن بطاقة، لعبة، أو اشتراك...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGold,
                      ),
                      suffixIcon: controller.searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.grey,
                              ),
                              onPressed: () =>
                                  controller.searchQuery.value = '',
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF181820)
                          : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGold,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── 3. Search Results Mode ──
                if (controller.searchQuery.value.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'نتائج البحث (${controller.filteredProducts.length})',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildProductGrid(controller.filteredProducts),
                ] else ...[
                  // ── 4. Banners Slider ──
                  StoreBannerSlider(banners: controller.banners),

                  const SizedBox(height: 20),

                  // ── 5. Categories Section ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الأقسام الرئيسية',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed('/store-categories'),
                          child: const Row(
                            children: [
                              Text(
                                'عرض الكل',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: 13,
                                ),
                              ),
                              Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.primaryGold,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 98,
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

                  // ── 6. Top Selling Products ──
                  if (controller.topSellingProducts.isNotEmpty) ...[
                    _buildSectionHeader('🔥 الأكثر مبيعاً'),
                    _buildHorizontalProductList(controller.topSellingProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 7. Offers & Discounts Section ──
                  if (controller.offerProducts.isNotEmpty) ...[
                    _buildSectionHeader('🏷️ أقوى العروض والتخفيضات'),
                    _buildHorizontalProductList(controller.offerProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 8. Latest Products Section ──
                  if (controller.latestProducts.isNotEmpty) ...[
                    _buildSectionHeader('✨ أحدث المنتجات'),
                    _buildHorizontalProductList(controller.latestProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 9. Suggested Products Grid ──
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProductList(List<StoreProductModel> products) {
    return SizedBox(
      height: 215,
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
          child: Text(
            'لا توجد منتجات مطابقة حالياً',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
