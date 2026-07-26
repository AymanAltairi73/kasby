import '../datasources/topup_remote_datasource.dart';
import '../datasources/store_local_datasource.dart';
import '../models/topup_service.dart';
import '../models/topup_order.dart';

import 'package:flutter/foundation.dart';

class StoreRepository {
  final TopupRemoteDatasource remoteDatasource;
  final StoreLocalDatasource localDatasource;

  StoreRepository({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  Future<List<TopupService>> getServices() async {
    final services = await remoteDatasource.getServices();
    
    debugPrint('==================================================');
    debugPrint('[STORE_REPOSITORY] STEP 3: Repository Result');
    debugPrint('[STORE_REPOSITORY] Services Received: ${services.length}');
    
    final totalProducts = services.fold(0, (sum, s) => sum + s.products.length);
    final categories = services.map((s) => s.flow).toSet().toList();
    
    debugPrint('[STORE_REPOSITORY] Total Products Received: $totalProducts');
    debugPrint('[STORE_REPOSITORY] Categories (Flows): $categories');
    debugPrint('==================================================');

    return services;
  }

  Future<TopupOrder> createRemoteOrder({
    required String idempotencyKey,
    required String sku,
    required String delivery,
    required Map<String, dynamic> player,
    String? callbackUrl,
  }) {
    return remoteDatasource.createOrder(
      idempotencyKey: idempotencyKey,
      sku: sku,
      delivery: delivery,
      player: player,
      callbackUrl: callbackUrl,
    );
  }

  Future<TopupOrder> getRemoteOrder(String id) {
    return remoteDatasource.getOrder(id);
  }

  Future<TopupOrder> confirmRemoteOrder(String id) {
    return remoteDatasource.confirmOrder(id);
  }

  Future<TopupOrder> declineRemoteOrder(String id) {
    return remoteDatasource.declineOrder(id);
  }

  Future<List<TopupOrder>> listRemoteOrders({
    String? status,
    String? sku,
    int limit = 50,
    String? cursor,
  }) {
    return remoteDatasource.listOrders(
      status: status,
      sku: sku,
      limit: limit,
      cursor: cursor,
    );
  }

  Future<Map<String, dynamic>> beginLocalCheckout({
    required String idempotencyKey,
    required String paymentMethod,
    required double subtotal,
    required double discount,
    required double total,
    String? couponCode,
    required List<Map<String, dynamic>> items,
  }) {
    return localDatasource.beginCheckout(
      idempotencyKey: idempotencyKey,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      discount: discount,
      total: total,
      couponCode: couponCode,
      items: items,
    );
  }

  Future<Map<String, dynamic>> completeLocalOrder({
    required String orderId,
    String? providerOrderId,
    String? deliveryCode,
    String? deliveryInfo,
    List<Map<String, dynamic>> itemUpdates = const [],
  }) {
    return localDatasource.completeOrder(
      orderId: orderId,
      providerOrderId: providerOrderId,
      deliveryCode: deliveryCode,
      deliveryInfo: deliveryInfo,
      itemUpdates: itemUpdates,
    );
  }

  Future<Map<String, dynamic>> refundLocalOrder({
    required String orderId,
    required String reason,
  }) {
    return localDatasource.refundOrder(
      orderId: orderId,
      reason: reason,
    );
  }

  Future<List<Map<String, dynamic>>> getLocalOrders() {
    return localDatasource.getOrders();
  }

  Future<Map<String, dynamic>?> getLocalOrder(String orderId) {
    return localDatasource.getOrder(orderId);
  }
}
