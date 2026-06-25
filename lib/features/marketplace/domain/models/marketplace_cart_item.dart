import 'marketplace_catalog_listing.dart';

class MarketplaceCartItem {
  final MarketplaceCatalogListing listing;
  final int quantity;

  const MarketplaceCartItem({
    required this.listing,
    this.quantity = 1,
  });

  String get variantId => listing.variantId;

  double get walletSubtotal => listing.walletPrice * quantity;

  double? get kspSubtotal =>
      listing.kspPrice != null ? listing.kspPrice! * quantity : null;

  MarketplaceCartItem copyWith({
    MarketplaceCatalogListing? listing,
    int? quantity,
  }) {
    return MarketplaceCartItem(
      listing: listing ?? this.listing,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'variant_id': listing.variantId,
        'quantity': quantity,
      };
}
