import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/routes/app_routes.dart';
import '../../domain/models/marketplace_product.dart';
import '../../domain/models/marketplace_product_variant.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_wishlist_controller.dart';
import '../widgets/marketplace_product_card.dart';
import '../widgets/marketplace_variant_selector.dart';

class MarketplaceProductDetailView extends StatefulWidget {
  const MarketplaceProductDetailView({super.key});

  @override
  State<MarketplaceProductDetailView> createState() =>
      _MarketplaceProductDetailViewState();
}

class _MarketplaceProductDetailViewState extends State<MarketplaceProductDetailView> {
  final _repo = MarketplaceRepository();
  MarketplaceProduct? product;
  MarketplaceProductVariant? selectedVariant;
  MarketplaceCatalogListing? selectedListing;
  List<MarketplaceCatalogListing> related = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final productId = Get.arguments as String;
    product = await _repo.getProductDetail(productId);
    if (product != null && product!.variants.isNotEmpty) {
      selectedVariant = product!.defaultVariant;
      await _refreshListing();
    }
    related = await _repo.getRelatedListings(productId);
    setState(() => isLoading = false);
  }

  Future<void> _refreshListing() async {
    if (product == null || selectedVariant == null) return;
    selectedListing = await _repo.getListingForProductVariant(
      product!.id,
      selectedVariant!.id,
    );
    await _repo.trackVariantView(selectedVariant!.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(KasbySpacing.md),
          child: KasbyShimmer.card(height: 300),
        ),
      );
    }
    if (product == null || selectedVariant == null || selectedListing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('marketplace_product_not_found'.tr)),
      );
    }

    final p = product!;
    final v = selectedVariant!;
    final listing = selectedListing!;
    final locale = Get.locale?.languageCode ?? 'en';
    final cart = MarketplaceCartController.to;
    final wishlist = MarketplaceWishlistController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                p.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.surface),
              ),
            ),
            actions: [
              Obx(() => IconButton(
                    icon: Icon(
                      wishlist.isInWishlist(listing.variantId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: wishlist.isInWishlist(listing.variantId)
                          ? Colors.redAccent
                          : null,
                    ),
                    onPressed: () => wishlist.toggleWishlist(listing),
                  )),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KasbySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.localizedName(locale),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: KasbySpacing.sm),
                  Text('marketplace_select_variant'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: KasbySpacing.sm),
                  MarketplaceVariantSelector(
                    variants: p.variants,
                    selected: selectedVariant,
                    onSelected: (variant) async {
                      selectedVariant = variant;
                      await _refreshListing();
                    },
                  ),
                  const SizedBox(height: KasbySpacing.md),
                  MarketplacePriceDisplay(
                    listing: listing,
                    priceStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGold,
                    ),
                  ),
                  const SizedBox(height: KasbySpacing.lg),
                  _section('marketplace_description'.tr, p.localizedDescription(locale)),
                  _section('marketplace_instructions'.tr, p.localizedInstructions(locale)),
                  _section('marketplace_terms'.tr, p.localizedTerms(locale)),
                  _section('marketplace_estimated_delivery'.tr, v.estimatedDelivery),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: KasbySpacing.lg),
                    Text('marketplace_related'.tr,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: KasbySpacing.sm),
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: related.length,
                        itemBuilder: (_, i) => SizedBox(
                          width: 160,
                          child: Padding(
                            padding: const EdgeInsets.only(right: KasbySpacing.md),
                            child: MarketplaceProductCard(listing: related[i], compact: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KasbySpacing.md),
          child: Row(
            children: [
              Expanded(
                child: KasbyButton(
                  text: 'marketplace_add_to_cart'.tr,
                  icon: Icons.add_shopping_cart_rounded,
                  isSecondary: true,
                  onPressed: v.isAvailable ? () => cart.addListing(listing) : null,
                ),
              ),
              const SizedBox(width: KasbySpacing.sm),
              Expanded(
                child: KasbyButton(
                  text: 'marketplace_buy_now'.tr,
                  onPressed: v.isAvailable
                      ? () async {
                          await cart.addListing(listing);
                          Get.toNamed(Routes.marketplaceCheckout);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KasbySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: KasbySpacing.sm),
          Text(body, style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        ],
      ),
    );
  }
}
