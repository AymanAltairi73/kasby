import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_cart_item.dart';
import '../models/marketplace_order.dart';
import '../reloadly/reloadly_catalog_mapper.dart';

/// Wallet / KSP settlement via Supabase RPC (idempotent, with rollback).
class MarketplaceSettlementService {
  MarketplaceSettlementService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<SettlementResult> beginCheckout({
    required String idempotencyKey,
    required MarketplacePaymentMethod paymentMethod,
    required double subtotal,
    required double discount,
    required double total,
    String? couponCode,
    required List<MarketplaceCartItem> items,
  }) async {
    final itemsJson = items.map(_itemToJson).toList();

    final raw = await _supabase.rpc(
      'fn_marketplace_begin_checkout',
      params: {
        'p_idempotency_key': idempotencyKey,
        'p_payment_method': paymentMethod.name,
        'p_subtotal': subtotal,
        'p_discount': discount,
        'p_total': total,
        'p_coupon_code': couponCode,
        'p_items': itemsJson,
      },
    );

    final map = Map<String, dynamic>.from(raw as Map);
    if (map['success'] != true) {
      throw SettlementException(
        map['error']?.toString() ?? 'Checkout settlement failed',
        orderId: map['order_id']?.toString(),
      );
    }

    return SettlementResult(
      orderId: map['order_id'] as String,
      transactionId: map['transaction_id'] as String?,
      idempotent: map['idempotent'] == true,
      paymentStatus: map['payment_status']?.toString() ?? 'paid',
      status: map['status']?.toString() ?? 'processing',
    );
  }

  Future<void> completeOrder({
    required String orderId,
    int? providerTransactionId,
    String? deliveryCode,
    String? deliveryInfo,
    List<ItemFulfillmentUpdate> itemUpdates = const [],
  }) async {
    final raw = await _supabase.rpc(
      'fn_marketplace_complete_order',
      params: {
        'p_order_id': orderId,
        'p_provider_transaction_id': providerTransactionId,
        'p_delivery_code': deliveryCode,
        'p_delivery_info': deliveryInfo,
        'p_item_updates': itemUpdates.map((e) => e.toJson()).toList(),
      },
    );

    final map = Map<String, dynamic>.from(raw as Map);
    if (map['success'] != true) {
      throw SettlementException(map['error']?.toString() ?? 'Complete order failed');
    }
  }

  Future<void> refundOrder({
    required String orderId,
    String reason = 'Provider fulfillment failed',
  }) async {
    final raw = await _supabase.rpc(
      'fn_marketplace_refund_order',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
      },
    );

    final map = Map<String, dynamic>.from(raw as Map);
    if (map['success'] != true) {
      throw SettlementException(map['error']?.toString() ?? 'Refund failed');
    }
  }

  Map<String, dynamic> _itemToJson(MarketplaceCartItem item) {
    final l = item.listing;
    final parsed = ReloadlyCatalogMapper.parseVariantSku(l.variantId);
    return {
      'variant_id': l.variantId,
      'product_id': l.productId,
      'brand_id': l.brandId,
      'variant_name_en': l.variantNameEn,
      'variant_name_ar': l.variantNameAr,
      'product_name_en': l.productNameEn,
      'product_name_ar': l.productNameAr,
      'brand_name_en': l.brandNameEn,
      'brand_name_ar': l.brandNameAr,
      'image_url': l.imageUrl,
      'quantity': item.quantity,
      'unit_price': l.walletPrice,
      'discount_amount': 0,
      'total_price': item.walletSubtotal,
      if (parsed != null) 'provider_product_id': parsed.productId.toString(),
      if (parsed != null)
        'provider_sku': '${parsed.productId}:${parsed.unitPrice.toStringAsFixed(2)}',
    };
  }
}

class SettlementResult {
  final String orderId;
  final String? transactionId;
  final bool idempotent;
  final String paymentStatus;
  final String status;

  const SettlementResult({
    required this.orderId,
    this.transactionId,
    this.idempotent = false,
    required this.paymentStatus,
    required this.status,
  });
}

class ItemFulfillmentUpdate {
  final String itemId;
  final int? providerTransactionId;
  final List<Map<String, dynamic>> redeemCodes;
  final String fulfillmentStatus;

  const ItemFulfillmentUpdate({
    required this.itemId,
    this.providerTransactionId,
    this.redeemCodes = const [],
    this.fulfillmentStatus = 'delivered',
  });

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        if (providerTransactionId != null)
          'provider_transaction_id': providerTransactionId,
        'redeem_codes': redeemCodes,
        'fulfillment_status': fulfillmentStatus,
      };
}

class SettlementException implements Exception {
  SettlementException(this.message, {this.orderId});

  final String message;
  final String? orderId;

  @override
  String toString() => message;
}
