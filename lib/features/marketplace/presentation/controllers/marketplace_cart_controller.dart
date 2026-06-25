import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../domain/models/marketplace_cart_item.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceCartController extends GetxController {
  static MarketplaceCartController get to => Get.find();

  final MarketplaceRepository _repo;

  MarketplaceCartController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final cartItems = <MarketplaceCartItem>[].obs;
  final isLoading = false.obs;

  int get itemCount => cartItems.fold(0, (sum, i) => sum + i.quantity);

  double get walletSubtotal =>
      cartItems.fold(0.0, (sum, i) => sum + i.walletSubtotal);

  double? get kspSubtotal {
    if (cartItems.any((i) => i.listing.kspPrice == null)) return null;
    return cartItems.fold<double>(0.0, (sum, i) => sum + i.kspSubtotal!);
  }

  bool get isEmpty => cartItems.isEmpty;

  @override
  void onInit() {
    super.onInit();
    loadCart();
  }

  Future<void> loadCart() async {
    isLoading.value = true;
    try {
      cartItems.value = await _repo.loadCart();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _persist() => _repo.saveCart(cartItems.toList());

  Future<void> addListing(MarketplaceCatalogListing listing, {int quantity = 1}) async {
    final idx = cartItems.indexWhere((i) => i.variantId == listing.variantId);
    if (idx >= 0) {
      cartItems[idx] = cartItems[idx].copyWith(quantity: cartItems[idx].quantity + quantity);
    } else {
      cartItems.add(MarketplaceCartItem(listing: listing, quantity: quantity));
    }
    cartItems.refresh();
    await _persist();
    SafeGetx.snackbar(title: 'marketplace'.tr, message: 'marketplace_added_to_cart'.tr);
  }

  Future<void> removeItem(String variantId) async {
    cartItems.removeWhere((i) => i.variantId == variantId);
    await _persist();
  }

  Future<void> updateQuantity(String variantId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(variantId);
      return;
    }
    final idx = cartItems.indexWhere((i) => i.variantId == variantId);
    if (idx >= 0) {
      cartItems[idx] = cartItems[idx].copyWith(quantity: quantity);
      cartItems.refresh();
      await _persist();
    }
  }

  Future<void> clearCart() async {
    cartItems.clear();
    await _persist();
  }
}
