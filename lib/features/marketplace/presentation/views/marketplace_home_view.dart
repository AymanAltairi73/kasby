import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/routes/app_routes.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../controllers/marketplace_controller.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_wishlist_controller.dart';
import '../widgets/marketplace_banner_carousel.dart';
import '../widgets/marketplace_category_chip.dart';
import '../widgets/marketplace_product_card.dart';

class MarketplaceHomeView extends StatelessWidget {
  const MarketplaceHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceController());
    Get.put(MarketplaceCartController(), permanent: true);
    Get.put(MarketplaceWishlistController(), permanent: true);
    final cart = MarketplaceCartController.to;
    final wishlist = MarketplaceWishlistController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.isLoading.value) return _buildLoading();
        if (controller.hasError.value) {
          return ErrorStateWidget(onRetry: controller.loadHome);
        }
        return RefreshIndicator(
          color: AppColors.darkGold,
          onRefresh: controller.loadHome,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(cart),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(KasbySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.catalogUnavailable.value)
                        _catalogUnavailableBanner(
                          controller.catalogErrorMessage.value,
                          controller.loadHome,
                        ),
                      MarketplaceBannerCarousel(banners: controller.banners).animate().fadeIn(),
                      if (controller.flashDeals.isNotEmpty) ...[
                        const SizedBox(height: KasbySpacing.lg),
                        _sectionHeader('marketplace_flash_deals'.tr),
                        const SizedBox(height: KasbySpacing.sm),
                        _listingRow(controller.flashDeals.map((_) => controller.featuredListings.firstOrNull).whereType<MarketplaceCatalogListing>().toList(), cart, wishlist),
                      ],
                      const SizedBox(height: KasbySpacing.lg),
                      _sectionHeader('marketplace_categories'.tr),
                      const SizedBox(height: KasbySpacing.sm),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.categories.length,
                          itemBuilder: (_, i) {
                            final cat = controller.categories[i];
                            return MarketplaceCategoryChip(
                              category: cat,
                              isSelected: false,
                              onTap: () => Get.toNamed(Routes.marketplaceCategory, arguments: cat),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: KasbySpacing.lg),
                      _quickLinks(),
                      ..._sections(controller, cart, wishlist),
                      const SizedBox(height: KasbySpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _sections(MarketplaceController c, MarketplaceCartController cart, MarketplaceWishlistController wishlist) {
    return [
      if (c.recentlyPurchased.isNotEmpty) ...[
        const SizedBox(height: KasbySpacing.lg),
        _sectionHeader('marketplace_recently_purchased'.tr),
        const SizedBox(height: KasbySpacing.sm),
        _listingRow(c.recentlyPurchased, cart, wishlist),
      ],
      if (c.recentlyViewed.isNotEmpty) ...[
        const SizedBox(height: KasbySpacing.lg),
        _sectionHeader('marketplace_recently_viewed'.tr),
        const SizedBox(height: KasbySpacing.sm),
        _listingRow(c.recentlyViewed, cart, wishlist),
      ],
      const SizedBox(height: KasbySpacing.lg),
      _sectionHeader('marketplace_trending'.tr),
      const SizedBox(height: KasbySpacing.sm),
      _listingRow(c.trendingListings, cart, wishlist),
      const SizedBox(height: KasbySpacing.lg),
      _sectionHeader('marketplace_best_sellers'.tr),
      const SizedBox(height: KasbySpacing.sm),
      _listingGrid(c.bestSellers, cart, wishlist),
      const SizedBox(height: KasbySpacing.lg),
      _sectionHeader('marketplace_new_arrivals'.tr),
      const SizedBox(height: KasbySpacing.sm),
      _listingRow(c.newArrivals, cart, wishlist),
      const SizedBox(height: KasbySpacing.lg),
      _sectionHeader('marketplace_featured'.tr),
      const SizedBox(height: KasbySpacing.sm),
      _listingGrid(c.featuredListings, cart, wishlist),
      const SizedBox(height: KasbySpacing.lg),
      _sectionHeader('marketplace_recommended'.tr),
      const SizedBox(height: KasbySpacing.sm),
      _listingGrid(c.recommendedListings, cart, wishlist),
    ];
  }

  Widget _buildAppBar(MarketplaceCartController cart) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      title: Text('marketplace'.tr),
      actions: [
        IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => Get.toNamed(Routes.marketplaceSearch)),
        IconButton(icon: const Icon(Icons.favorite_border_rounded), onPressed: () => Get.toNamed(Routes.marketplaceWishlist)),
        Obx(() => Stack(
              children: [
                IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => Get.toNamed(Routes.marketplaceCart)),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.darkGold, shape: BoxShape.circle),
                      child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            )),
        IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Get.toNamed(Routes.marketplaceNotifications)),
        IconButton(icon: const Icon(Icons.monitor_heart_outlined), onPressed: () => Get.toNamed(Routes.marketplaceHealth)),
      ],
    );
  }

  Widget _buildLoading() => ListView(
        padding: const EdgeInsets.all(KasbySpacing.md),
        children: [KasbyShimmer.card(height: 160), const SizedBox(height: 16), KasbyShimmer.card(height: 200)],
      );

  Widget _sectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _catalogUnavailableBanner(String? message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KasbySpacing.md),
      child: Material(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KasbyRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(KasbyRadius.card),
          onTap: onRetry,
          child: Padding(
            padding: const EdgeInsets.all(KasbySpacing.md),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.orange),
                const SizedBox(width: KasbySpacing.sm),
                Expanded(
                  child: Text(
                    message ?? 'couldnt_load_data'.tr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                Text('retry'.tr, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickLinks() => Row(
        children: [
          Expanded(child: _linkChip(Icons.receipt_long_rounded, 'marketplace_orders'.tr, Routes.marketplaceOrders)),
          const SizedBox(width: KasbySpacing.sm),
          Expanded(child: _linkChip(Icons.emoji_events_rounded, 'marketplace_rewards'.tr, Routes.marketplaceRewards)),
        ],
      );

  Widget _linkChip(IconData icon, String label, String route) {
    return Material(
      color: AppColors.darkGold.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(KasbyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(KasbyRadius.card),
        onTap: () => Get.toNamed(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KasbySpacing.md, horizontal: KasbySpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.darkGold, size: 20),
              const SizedBox(width: KasbySpacing.sm),
              Flexible(child: Text(label, style: TextStyle(color: AppColors.darkGold, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listingRow(List<MarketplaceCatalogListing> listings, MarketplaceCartController cart, MarketplaceWishlistController wishlist) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: listings.length,
        itemBuilder: (_, i) => SizedBox(
          width: 170,
          child: Padding(
            padding: const EdgeInsets.only(right: KasbySpacing.md),
            child: MarketplaceProductCard(
              listing: listings[i],
              compact: true,
              isInWishlist: wishlist.isInWishlist(listings[i].variantId),
              onAddToCart: () => cart.addListing(listings[i]),
              onToggleWishlist: () => wishlist.toggleWishlist(listings[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _listingGrid(List<MarketplaceCatalogListing> listings, MarketplaceCartController cart, MarketplaceWishlistController wishlist) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: KasbySpacing.md,
        mainAxisSpacing: KasbySpacing.md,
      ),
      itemCount: listings.length,
      itemBuilder: (_, i) {
        final l = listings[i];
        return MarketplaceProductCard(
          listing: l,
          isInWishlist: wishlist.isInWishlist(l.variantId),
          onAddToCart: () => cart.addListing(l),
          onToggleWishlist: () => wishlist.toggleWishlist(l),
        );
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
