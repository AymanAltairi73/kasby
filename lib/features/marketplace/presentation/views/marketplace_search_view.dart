import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_search_controller.dart';
import '../controllers/marketplace_wishlist_controller.dart';
import '../widgets/marketplace_product_card.dart';

class MarketplaceSearchView extends StatelessWidget {
  const MarketplaceSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceSearchController());
    final cart = MarketplaceCartController.to;
    final wishlist = MarketplaceWishlistController.to;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'marketplace_search_hint'.tr, border: InputBorder.none),
          onChanged: controller.onQueryChanged,
        ),
      ),
      body: Obx(() {
        if (controller.suggestions.isNotEmpty && !controller.hasSearched.value) {
          return ListView(
            children: controller.suggestions.map((s) => ListTile(
              leading: const Icon(Icons.search),
              title: Text(s),
              onTap: () => controller.search(s),
            )).toList(),
          );
        }
        if (controller.isSearching.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.hasSearched.value) {
          return Center(child: Text('marketplace_search_prompt'.tr));
        }
        if (controller.results.isEmpty) {
          return Center(child: Text('marketplace_no_results'.tr));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: controller.results.length,
          itemBuilder: (_, i) {
            final l = controller.results[i];
            return MarketplaceProductCard(
              listing: l,
              isInWishlist: wishlist.isInWishlist(l.variantId),
              onAddToCart: () => cart.addListing(l),
              onToggleWishlist: () => wishlist.toggleWishlist(l),
            );
          },
        );
      }),
    );
  }
}
