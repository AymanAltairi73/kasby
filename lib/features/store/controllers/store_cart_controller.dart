import 'package:get/get.dart';
import '../models/store_cart_item.dart';
import '../models/topup_product.dart';
import '../models/topup_delivery_option.dart';

class StoreCartController extends GetxController {
  static StoreCartController get to => Get.find();

  final RxList<StoreCartItem> cartItems = <StoreCartItem>[].obs;

  int get itemCount => cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get totalUsd {
    return cartItems.fold(0.0, (sum, item) {
      final price = item.deliveryOption.priceCents / 100.0;
      return sum + (price * item.quantity);
    });
  }

  void addToCart({
    required TopupProduct product,
    required TopupDeliveryOption deliveryOption,
    required Map<String, String> playerInput,
    int quantity = 1,
  }) {
    // Check if item with same SKU and player input already exists
    final index = cartItems.indexWhere(
      (item) =>
          item.product.sku == product.sku &&
          item.deliveryOption.delivery == deliveryOption.delivery &&
          _mapsEqual(item.playerInput, playerInput),
    );

    if (index >= 0) {
      final existing = cartItems[index];
      cartItems[index] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      cartItems.add(
        StoreCartItem(
          product: product,
          deliveryOption: deliveryOption,
          quantity: quantity,
          playerInput: Map.from(playerInput),
        ),
      );
    }
  }

  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < cartItems.length) {
      if (quantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index] = cartItems[index].copyWith(quantity: quantity);
      }
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < cartItems.length) {
      cartItems.removeAt(index);
    }
  }

  void clearCart() {
    cartItems.clear();
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (b[key] != a[key]) return false;
    }
    return true;
  }
}
