import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import '../../domain/models/marketplace_brand.dart';
import '../../domain/models/marketplace_category.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/models/marketplace_filter_options.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_wishlist_controller.dart';
import '../widgets/marketplace_filter_sheet.dart';
import '../widgets/marketplace_product_card.dart';

class MarketplaceCategoryView extends StatefulWidget {
  const MarketplaceCategoryView({super.key});

  @override
  State<MarketplaceCategoryView> createState() => _MarketplaceCategoryViewState();
}

class _MarketplaceCategoryViewState extends State<MarketplaceCategoryView> {
  late MarketplaceCategory category;
  final _repo = MarketplaceRepository();
  final listings = <MarketplaceCatalogListing>[].obs;
  final brands = <MarketplaceBrand>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  String? loadErrorMessage;
  final filters = const MarketplaceFilterOptions().obs;
  String? selectedBrandId;

  @override
  void initState() {
    super.initState();
    category = Get.arguments as MarketplaceCategory;
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    isLoading.value = true;
    hasError.value = false;
    loadErrorMessage = null;
    try {
      if (refresh) await _repo.refreshCatalog();
      brands.value = await _repo.getBrands(categoryId: category.id);
      listings.value = await _repo.getCatalogListings(
        filters: filters.value.copyWith(categoryId: category.id, brandId: selectedBrandId),
      );
      if (!_repo.isCatalogAvailable) {
        hasError.value = true;
        loadErrorMessage = _repo.catalogLoadError;
      }
    } catch (e) {
      hasError.value = true;
      loadErrorMessage = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'en';
    final cart = MarketplaceCartController.to;
    final wishlist = MarketplaceWishlistController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(category.localizedName(locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => MarketplaceFilterSheet.show(
              currentSort: filters.value.sortBy,
              onSortChanged: (v) => filters.value = filters.value.copyWith(sortBy: v),
              onApply: _load,
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return GridView.builder(
            padding: const EdgeInsets.all(KasbySpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: KasbySpacing.md, mainAxisSpacing: KasbySpacing.md),
            itemCount: 4,
            itemBuilder: (_, __) => KasbyShimmer.card(height: 200),
          );
        }
        if (hasError.value) {
          return ErrorStateWidget(
            message: loadErrorMessage ?? 'couldnt_load_data'.tr,
            onRetry: () => _load(refresh: true),
          );
        }
        return Column(
          children: [
            if (brands.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.md, vertical: KasbySpacing.sm),
                  children: [
                    FilterChip(
                      label: Text('marketplace_all'.tr),
                      selected: selectedBrandId == null,
                      onSelected: (_) { selectedBrandId = null; _load(); },
                    ),
                    ...brands.map((b) => Padding(
                          padding: const EdgeInsets.only(left: KasbySpacing.sm),
                          child: FilterChip(
                            label: Text(b.localizedName(locale)),
                            selected: selectedBrandId == b.id,
                            onSelected: (_) { selectedBrandId = b.id; _load(); },
                          ),
                        )),
                  ],
                ),
              ),
            Expanded(
              child: listings.isEmpty
                  ? Center(child: Text('marketplace_no_products'.tr))
                  : RefreshIndicator(
                      color: AppColors.darkGold,
                      onRefresh: () => _load(refresh: true),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(KasbySpacing.md),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: KasbySpacing.md, mainAxisSpacing: KasbySpacing.md),
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
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
