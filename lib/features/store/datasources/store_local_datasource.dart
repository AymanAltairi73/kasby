import 'package:kasby/core/services/supabase_service.dart';

class StoreLocalDatasource {
  Future<Map<String, dynamic>> beginCheckout({
    required String idempotencyKey,
    required String paymentMethod,
    required double subtotal,
    required double discount,
    required double total,
    String? couponCode,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await SupabaseService.client.rpc(
      'fn_marketplace_begin_checkout',
      params: {
        'p_idempotency_key': idempotencyKey,
        'p_payment_method': paymentMethod,
        'p_subtotal': subtotal,
        'p_discount': discount,
        'p_total': total,
        'p_coupon_code': couponCode,
        'p_items': items,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> completeOrder({
    required String orderId,
    String? providerOrderId,
    String? deliveryCode,
    String? deliveryInfo,
    List<Map<String, dynamic>> itemUpdates = const [],
  }) async {
    final response = await SupabaseService.client.rpc(
      'fn_marketplace_complete_order',
      params: {
        'p_order_id': orderId,
        'p_provider_order_id': providerOrderId,
        'p_delivery_code': deliveryCode,
        'p_delivery_info': deliveryInfo,
        'p_item_updates': itemUpdates,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> refundOrder({
    required String orderId,
    required String reason,
  }) async {
    final response = await SupabaseService.client.rpc(
      'fn_marketplace_refund_order',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final userId = SupabaseService.userId;
    if (userId == null) return [];

    final response = await SupabaseService.client
        .from('marketplace_orders')
        .select('*, marketplace_order_items(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final userId = SupabaseService.userId;
    if (userId == null) return null;

    final response = await SupabaseService.client
        .from('marketplace_orders')
        .select('*, marketplace_order_items(*)')
        .eq('id', orderId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Map<String, dynamic>.from(response as Map);
  }
}
