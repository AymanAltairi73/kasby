import 'topup_product.dart';
import 'topup_delivery_option.dart';

class StoreCartItem {
  final TopupProduct product;
  final TopupDeliveryOption deliveryOption;
  final int quantity;
  final Map<String, String> playerInput;

  StoreCartItem({
    required this.product,
    required this.deliveryOption,
    required this.quantity,
    required this.playerInput,
  });

  factory StoreCartItem.fromJson(Map<String, dynamic> json) {
    return StoreCartItem(
      product: TopupProduct.fromJson(json['product'] as Map<String, dynamic>),
      deliveryOption: TopupDeliveryOption.fromJson(json['delivery_option'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      playerInput: json['player_input'] != null
          ? Map<String, String>.from(json['player_input'] as Map)
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'delivery_option': deliveryOption.toJson(),
      'quantity': quantity,
      'player_input': playerInput,
    };
  }

  StoreCartItem copyWith({
    TopupProduct? product,
    TopupDeliveryOption? deliveryOption,
    int? quantity,
    Map<String, String>? playerInput,
  }) {
    return StoreCartItem(
      product: product ?? this.product,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      quantity: quantity ?? this.quantity,
      playerInput: playerInput ?? this.playerInput,
    );
  }
}
