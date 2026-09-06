import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
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
    final bg = isDark ? const Color(0xFF0E0E11) : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.onSurfaceLight;

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
            Text(
              'store_title'.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
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
              tooltip: 'store_orders_tooltip'.tr,
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
                    itemBuilder: (_, _) =>
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF2B2416), Color(0xFF16151B)]
                          : const [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
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
                                  'store_wallet_balance'.tr,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (_) {
                                final effUsd = Get.isRegistered<CurrencyController>()
                                    ? CurrencyController.to.totalEffectiveUsd
                                    : controller.usdBalance.value;
                                return Text(
                                  '\$${effUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGold,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
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
                                  'store_ksp_balance'.tr,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (_) {
                                final effKsp = Get.isRegistered<CurrencyController>()
                                    ? CurrencyController.to.totalEffectiveKsp
                                    : controller.kspBalance.value.round();
                                return Text(
                                  '$effKsp KSP',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
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
                      hintText: 'store_search_hint'.tr,
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey[500]
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGold,
                      ),
                      suffixIcon: controller.searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: isDark
                                    ? Colors.grey
                                    : AppColors.textSecondaryLight,
                              ),
                              onPressed: () =>
                                  controller.searchQuery.value = '',
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF181820)
                          : AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.primaryGold.withValues(alpha: 0.2)
                              : AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.primaryGold.withValues(alpha: 0.2)
                              : AppColors.borderLight,
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
                      'store_search_results'.trParams({'count': controller.filteredProducts.length.toString()}),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildProductGrid(controller.filteredProducts, isDark, textColor),
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
                              'store_main_categories'.tr,
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
                          child: Row(
                            children: [
                              Text(
                                'store_view_all'.tr,
                                style: const TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: 13,
                                ),
                              ),
                              Icon(
                                Get.locale?.languageCode == 'ar'
                                    ? Icons.chevron_left_rounded
                                    : Icons.chevron_right_rounded,
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
                    _buildSectionHeader('store_top_selling'.tr, textColor),
                    _buildHorizontalProductList(controller.topSellingProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 7. Offers & Discounts Section ──
                  if (controller.offerProducts.isNotEmpty) ...[
                    _buildSectionHeader('store_top_offers'.tr, textColor),
                    _buildHorizontalProductList(controller.offerProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 8. Latest Products Section ──
                  if (controller.latestProducts.isNotEmpty) ...[
                    _buildSectionHeader('store_latest_products'.tr, textColor),
                    _buildHorizontalProductList(controller.latestProducts),
                    const SizedBox(height: 24),
                  ],

                  // ── 9. Suggested Products Grid ──
                  _buildSectionHeader('store_suggested_products'.tr, textColor),
                  _buildProductGrid(
                    controller.allProducts.take(6).toList(),
                    isDark,
                    textColor,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
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
            style: TextStyle(
              color: textColor,
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

  Widget _buildProductGrid(
    List<StoreProductModel> products,
    bool isDark,
    Color textColor,
  ) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            'store_no_matching_products'.tr,
            style: TextStyle(
              color: isDark ? Colors.grey : AppColors.textSecondaryLight,
            ),
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
