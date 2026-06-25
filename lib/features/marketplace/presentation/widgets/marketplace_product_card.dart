import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/routes/app_routes.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import 'marketplace_badge.dart';

class MarketplaceProductCard extends StatelessWidget {
  final MarketplaceCatalogListing listing;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleWishlist;
  final bool isInWishlist;
  final bool compact;

  const MarketplaceProductCard({
    super.key,
    required this.listing,
    this.onAddToCart,
    this.onToggleWishlist,
    this.isInWishlist = false,
    this.compact = false,
  });

  String get _locale => Get.locale?.languageCode ?? 'en';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.marketplaceProduct, arguments: listing.productId),
      child: KasbyCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(KasbyRadius.card)),
                  child: AspectRatio(
                    aspectRatio: compact ? 1.2 : 1,
                    child: Image.network(
                      listing.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: Icon(Icons.image, color: AppColors.darkGold),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: KasbySpacing.sm,
                  left: KasbySpacing.sm,
                  child: Row(
                    children: [
                      if (listing.isFeatured) MarketplaceBadge.featured(),
                      if (listing.isPopular) ...[
                        if (listing.isFeatured) const SizedBox(width: 4),
                        MarketplaceBadge.popular(),
                      ],
                      if (listing.hasDiscount) ...[
                        const SizedBox(width: 4),
                        MarketplaceBadge.discount(listing.discountPercent),
                      ],
                    ],
                  ),
                ),
                if (onToggleWishlist != null)
                  Positioned(
                    top: KasbySpacing.sm,
                    right: KasbySpacing.sm,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      icon: Icon(
                        isInWishlist ? Icons.favorite : Icons.favorite_border,
                        color: isInWishlist ? Colors.redAccent : Colors.white,
                        size: 20,
                      ),
                      onPressed: onToggleWishlist,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(KasbySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.localizedDisplayName(_locale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: KasbySpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: AppColors.darkGold),
                      Text(' ${listing.rating}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: KasbySpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: MarketplacePriceDisplay(listing: listing)),
                      if (onAddToCart != null && listing.isAvailable)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.add_shopping_cart_rounded, color: AppColors.darkGold),
                          onPressed: onAddToCart,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplacePriceDisplay extends StatelessWidget {
  final MarketplaceCatalogListing listing;
  final TextStyle? priceStyle;
  final bool showKsp;

  const MarketplacePriceDisplay({
    super.key,
    required this.listing,
    this.priceStyle,
    this.showKsp = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = priceStyle ??
        TextStyle(color: AppColors.darkGold, fontWeight: FontWeight.bold, fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('\$${listing.walletPrice.toStringAsFixed(2)}', style: style),
            if (listing.hasDiscount) ...[
              const SizedBox(width: KasbySpacing.sm),
              Text(
                '\$${listing.originalPrice!.toStringAsFixed(2)}',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                  fontSize: (style.fontSize ?? 16) - 2,
                ),
              ),
            ],
          ],
        ),
        if (showKsp && listing.kspPrice != null)
          Text(
            '${listing.kspPrice!.toStringAsFixed(0)} KSP',
            style: TextStyle(color: AppColors.darkGold.withValues(alpha: 0.7), fontSize: 12),
          ),
      ],
    );
  }
}
