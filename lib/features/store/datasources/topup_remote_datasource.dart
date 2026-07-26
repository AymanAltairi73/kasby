import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/store_config.dart';
import '../models/topup_service.dart';
import '../models/topup_order.dart';

import 'package:flutter/foundation.dart';

class TopupRemoteDatasource {
  Future<List<TopupService>> getServices() async {
    final url = '${StoreConfig.baseUrl}/api/v1/services';
    final headers = StoreConfig.headers;

    debugPrint('==================================================');
    debugPrint('[TOPUP_REMOTE_DS] STEP 1: API Request');
    debugPrint('[TOPUP_REMOTE_DS] URL: $url');
    debugPrint('[TOPUP_REMOTE_DS] Headers: $headers');
    debugPrint('[TOPUP_REMOTE_DS] Authorization: ${headers['Authorization']}');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    debugPrint('[TOPUP_REMOTE_DS] HTTP Status: ${response.statusCode}');
    debugPrint('[TOPUP_REMOTE_DS] Raw JSON Response:\n${response.body}');
    debugPrint('==================================================');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['services'] as List? ?? [];

      debugPrint('[TOPUP_REMOTE_DS] STEP 2: JSON Parsing');
      debugPrint('[TOPUP_REMOTE_DS] Raw Services Count in JSON: ${list.length}');

      final parsedList = <TopupService>[];
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final service = TopupService.fromJson(item);
        parsedList.add(service);

        debugPrint('[TOPUP_REMOTE_DS] Service [$i]: name="${service.name}", slug="${service.slug}", flow="${service.flow}", enabled=${service.enabled}, productsCount=${service.products.length}');
        for (var j = 0; j < service.products.length; j++) {
          final p = service.products[j];
          debugPrint('   -> Product [$j]: sku="${p.sku}", game="${p.game}", label="${p.productLabel}", region="${p.region}", deliveryOptionsCount=${p.deliveryOptions.length}');
        }
      }

      return parsedList;
    } else {
      throw Exception('Failed to load services: ${response.statusCode} - ${response.body}');
    }
  }

  Future<TopupOrder> createOrder({
    required String idempotencyKey,
    required String sku,
    required String delivery, // 'direct' or 'voucher'
    required Map<String, dynamic> player,
    String? callbackUrl,
  }) async {
    final body = {
      'sku': sku,
      'player': player,
      'delivery': delivery,
      if (callbackUrl != null) 'callback_url': callbackUrl,
    };

    final headers = {
      ...StoreConfig.headers,
      'Idempotency-Key': idempotencyKey,
    };

    final response = await http.post(
      Uri.parse('${StoreConfig.baseUrl}/api/v1/orders'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return TopupOrder.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create order: ${response.statusCode} - ${response.body}');
    }
  }

  Future<TopupOrder> getOrder(String id) async {
    final response = await http.get(
      Uri.parse('${StoreConfig.baseUrl}/api/v1/orders/$id'),
      headers: StoreConfig.headers,
    );

    if (response.statusCode == 200) {
      return TopupOrder.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to get order: ${response.statusCode} - ${response.body}');
    }
  }

  Future<TopupOrder> confirmOrder(String id) async {
    final response = await http.post(
      Uri.parse('${StoreConfig.baseUrl}/api/v1/orders/$id/confirm'),
      headers: StoreConfig.headers,
    );

    if (response.statusCode == 200) {
      return TopupOrder.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to confirm order: ${response.statusCode} - ${response.body}');
    }
  }

  Future<TopupOrder> declineOrder(String id) async {
    final response = await http.post(
      Uri.parse('${StoreConfig.baseUrl}/api/v1/orders/$id/decline'),
      headers: StoreConfig.headers,
    );

    if (response.statusCode == 200) {
      return TopupOrder.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to decline order: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<TopupOrder>> listOrders({
    String? status,
    String? sku,
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (sku != null && sku.isNotEmpty) 'sku': sku,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = Uri.parse('${StoreConfig.baseUrl}/api/v1/orders').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: StoreConfig.headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['orders'] as List? ?? [];
      return list.map((e) => TopupOrder.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to list orders: ${response.statusCode} - ${response.body}');
    }
  }
}

