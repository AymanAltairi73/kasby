import 'dart:math';
import 'package:flutter/foundation.dart';
import '../repositories/store_repository.dart';
import '../models/topup_service.dart';
import '../models/topup_order.dart';
import '../models/store_cart_item.dart';

class StorePurchaseResult {
  final bool success;
  final String message;
  final String? localOrderId;
  final TopupOrder? remoteOrder;

  StorePurchaseResult({
    required this.success,
    required this.message,
    this.localOrderId,
    this.remoteOrder,
  });
}

class StoreService {
  final StoreRepository repository;

  StoreService({required this.repository});

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    return '${_toHex(values.sublist(0, 4))}-${_toHex(values.sublist(4, 6))}-${_toHex(values.sublist(6, 8))}-${_toHex(values.sublist(8, 10))}-${_toHex(values.sublist(10, 16))}';
  }

  String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<TopupService>> fetchCatalog() async {
    try {
      return await repository.getServices();
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching catalog: $e');
      rethrow;
    }
  }

  /// Atomic Purchase Execution:
  /// 1. Reserve wallet balance in Supabase (local order creation).
  /// 2. Post order to TopUp.dev with Idempotency Key.
  /// 3. Confirm order on TopUp success OR Rollback/Refund local balance on TopUp failure.
  Future<StorePurchaseResult> processCartItemCheckout({
    required StoreCartItem item,
    required String paymentMethod, // 'wallet' or 'ksp'
  }) async {
    final idempotencyKey = _generateUuid();
    final priceUsd = item.deliveryOption.priceCents / 100.0;
    final totalAmount = priceUsd * item.quantity;

    // Prepare local order items structure
    final localItems = [
      {
        'variant_id': item.product.sku,
        'product_id': item.product.game,
        'brand_id': item.product.game,
        'variant_name_en': item.product.productLabel,
        'variant_name_ar': item.product.productLabel,
        'product_name_en': item.product.game,
        'product_name_ar': item.product.game,
        'brand_name_en': item.product.game,
        'brand_name_ar': item.product.game,
        'image_url': '',
        'quantity': item.quantity,
        'unit_price': priceUsd,
        'discount_amount': 0.0,
        'total_price': totalAmount,
        'provider_sku': item.product.sku,
      }
    ];

    // STEP 1: Reserve local wallet balance & create local order
    Map<String, dynamic> localResult;
    try {
      localResult = await repository.beginLocalCheckout(
        idempotencyKey: idempotencyKey,
        paymentMethod: paymentMethod,
        subtotal: totalAmount,
        discount: 0.0,
        total: totalAmount,
        items: localItems,
      );
    } catch (e) {
      debugPrint('[STORE_SERVICE] Local reservation failed: $e');
      return StorePurchaseResult(
        success: false,
        message: 'فشلت عملية حجز الرصيد: $e',
      );
    }

    if (localResult['success'] != true) {
      final err = localResult['error'] as String? ?? 'فشلت عملية الدفع';
      return StorePurchaseResult(
        success: false,
        message: err,
      );
    }

    final localOrderId = localResult['order_id'] as String;

    // STEP 2: Call TopUp.dev API
    try {
      final playerMap = <String, dynamic>{
        ...item.playerInput,
      };

      final remoteOrder = await repository.createRemoteOrder(
        idempotencyKey: idempotencyKey,
        sku: item.product.sku,
        delivery: item.deliveryOption.delivery,
        player: playerMap,
      );

      // Check remote status
      if (remoteOrder.status == 'fulfilled' ||
          remoteOrder.status == 'processing' ||
          remoteOrder.status == 'queued' ||
          remoteOrder.status == 'awaiting_confirmation') {
        // STEP 3a: Success -> Complete Local Order
        await repository.completeLocalOrder(
          orderId: localOrderId,
          providerOrderId: remoteOrder.id,
          deliveryCode: remoteOrder.deliveredCode,
          deliveryInfo: remoteOrder.status,
        );

        return StorePurchaseResult(
          success: true,
          message: remoteOrder.status == 'fulfilled'
              ? 'تم تنفيذ الطلب بنجاح'
              : 'الطلب قيد المعالجة لدى المزود',
          localOrderId: localOrderId,
          remoteOrder: remoteOrder,
        );
      } else {
        // Remote order was created but rejected/failed immediately
        final errorMsg = remoteOrder.errorMessage ?? 'فشل تنفيذ الطلب لدى المزود';
        await repository.refundLocalOrder(
          orderId: localOrderId,
          reason: 'TopUp.dev order status: ${remoteOrder.status} ($errorMsg)',
        );

        return StorePurchaseResult(
          success: false,
          message: errorMsg,
          localOrderId: localOrderId,
          remoteOrder: remoteOrder,
        );
      }
    } catch (e) {
      debugPrint('[STORE_SERVICE] TopUp.dev call exception: $e. Initiating rollback...');
      // STEP 3b: Failure -> Rollback & Refund Local Balance
      try {
        await repository.refundLocalOrder(
          orderId: localOrderId,
          reason: 'Exception calling TopUp.dev: $e',
        );
      } catch (refundErr) {
        debugPrint('[STORE_SERVICE] CRITICAL: Refund failed: $refundErr');
      }

      return StorePurchaseResult(
        success: false,
        message: 'حدث خطأ أثناء الاتصال بالمزود وتم إرجاع المبلغ إلى محفظتك.',
        localOrderId: localOrderId,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getOrderHistory() async {
    return repository.getLocalOrders();
  }
}
