import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_order.dart';

/// Reads/writes marketplace orders from Supabase (no in-memory store).
class MarketplaceOrderStore {
  MarketplaceOrderStore({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<MarketplaceOrder>> getOrders({
    required String userId,
    MarketplaceOrderStatus? status,
  }) async {
    var query = _supabase
        .from('marketplace_orders')
        .select('*, marketplace_order_items(*)')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _mapOrder(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<MarketplaceOrder?> getOrderById({
    required String userId,
    required String orderId,
  }) async {
    final row = await _supabase
        .from('marketplace_orders')
        .select('*, marketplace_order_items(*)')
        .eq('id', orderId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _mapOrder(Map<String, dynamic>.from(row));
  }

  Future<List<PersistedOrderItem>> getOrderItems(String orderId) async {
    final rows = await _supabase
        .from('marketplace_order_items')
        .select()
        .eq('order_id', orderId);

    return (rows as List)
        .map(
          (r) => PersistedOrderItem.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> getHealthSummary() async {
    final health = await _supabase
        .from('marketplace_provider_health')
        .select()
        .order('checked_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final failedCount = await _supabase
        .from('marketplace_api_request_log')
        .select('id')
        .eq('success', false)
        .gte(
          'created_at',
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String(),
        );

    final failures = (failedCount as List).length;

    return {
      'latest_health': health,
      'failed_requests_24h': failures,
    };
  }

  MarketplaceOrder _mapOrder(Map<String, dynamic> row) {
    final itemsRaw = row['marketplace_order_items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map(
          (e) => MarketplaceOrderItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final timelineRaw = row['timeline'] as List<dynamic>? ?? [];
    final timeline = timelineRaw
        .map(
          (e) => MarketplaceOrderTimelineEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return MarketplaceOrder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      items: items,
      subtotalAmount: (row['subtotal_amount'] as num).toDouble(),
      discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total_amount'] as num).toDouble(),
      couponCode: row['coupon_code'] as String?,
      paymentMethod: MarketplacePaymentMethod.values.firstWhere(
        (m) => m.name == row['payment_method'],
        orElse: () => MarketplacePaymentMethod.wallet,
      ),
      status: MarketplaceOrderStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => MarketplaceOrderStatus.pending,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      deliveryCode: row['delivery_code'] as String?,
      deliveryInfo: row['delivery_info'] as String?,
      notes: row['notes'] as String?,
      timeline: timeline,
      providerTransactionId: row['provider_transaction_id']?.toString(),
      paymentStatus: row['payment_status'] as String?,
      deliveryStatus: row['delivery_status'] as String?,
      walletTransactionId: row['wallet_transaction_id'] as String?,
      providerName: row['provider_name'] as String?,
    );
  }
}

class PersistedOrderItem {
  final String id;
  final String orderId;
  final String variantId;
  final int? providerProductId;
  final String? providerSku;

  const PersistedOrderItem({
    required this.id,
    required this.orderId,
    required this.variantId,
    this.providerProductId,
    this.providerSku,
  });

  factory PersistedOrderItem.fromJson(Map<String, dynamic> json) {
    return PersistedOrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      variantId: json['variant_id'] as String,
      providerProductId: (json['provider_product_id'] as num?)?.toInt(),
      providerSku: json['provider_sku'] as String?,
    );
  }
}
