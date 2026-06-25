import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/marketplace_cart_controller.dart';
import '../controllers/marketplace_wishlist_controller.dart';
import '../widgets/marketplace_product_card.dart';

class MarketplaceWishlistView extends StatelessWidget {
  const MarketplaceWishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = MarketplaceWishlistController.to;
    final cart = MarketplaceCartController.to;

    return Scaffold(
      appBar: AppBar(title: Text('marketplace_wishlist'.tr)),
      body: Obx(() {
        if (wishlist.wishlistListings.isEmpty) {
          return Center(child: Text('marketplace_wishlist_empty'.tr));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: wishlist.wishlistListings.length,
          itemBuilder: (_, i) {
            final l = wishlist.wishlistListings[i];
            return MarketplaceProductCard(
              listing: l,
              isInWishlist: true,
              onAddToCart: () => cart.addListing(l),
              onToggleWishlist: () => wishlist.toggleWishlist(l),
            );
          },
        );
      }),
    );
  }
}
