import 'package:get/get.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceWishlistController extends GetxController {
  static MarketplaceWishlistController get to => Get.find();

  final MarketplaceRepository _repo;

  MarketplaceWishlistController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final wishlistListings = <MarketplaceCatalogListing>[].obs;
  final wishlistIds = <String>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadWishlist();
  }

  Future<void> loadWishlist() async {
    isLoading.value = true;
    try {
      wishlistIds.value = await _repo.getWishlistIds();
      wishlistListings.value = await _repo.loadWishlist();
    } finally {
      isLoading.value = false;
    }
  }

  bool isInWishlist(String variantId) => wishlistIds.contains(variantId);

  Future<void> toggleWishlist(MarketplaceCatalogListing listing) async {
    if (isInWishlist(listing.variantId)) {
      wishlistIds.remove(listing.variantId);
      wishlistListings.removeWhere((l) => l.variantId == listing.variantId);
    } else {
      wishlistIds.add(listing.variantId);
      wishlistListings.add(listing);
    }
    await _repo.saveWishlistIds(wishlistIds.toList());
  }
}
