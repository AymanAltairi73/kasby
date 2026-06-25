import 'package:supabase_flutter/supabase_flutter.dart';
import 'reloadly_config.dart';
import 'reloadly_models.dart';

/// HTTP client for Reloadly Gift Cards API — all calls via `reloadly-proxy`.
class ReloadlyApiClient {
  ReloadlyApiClient({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> _invoke(
    String action, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? body,
  }) async {
    if (!ReloadlyConfig.useEdgeProxy) {
      throw ReloadlyApiException(
        'Reloadly edge proxy disabled. '
        'Set RELOADLY_USE_EDGE_PROXY=true and deploy reloadly-proxy.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'reloadly-proxy',
        body: {
          'action': action,
          if (params != null) 'params': params,
          if (body != null) 'payload': body,
          'environment': ReloadlyConfig.environment,
        },
      );

      if (response.status != 200) {
        final data = response.data;
        final message = data is Map
            ? data['error']?.toString() ?? data['message']?.toString()
            : null;
        throw ReloadlyApiException(
          message ?? 'Reloadly proxy error (${response.status})',
          statusCode: response.status,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw ReloadlyApiException('Invalid Reloadly proxy response shape');
      }
      if (data['error'] != null) {
        throw ReloadlyApiException(data['error'].toString());
      }
      return data;
    } on ReloadlyApiException {
      rethrow;
    } on FunctionException catch (e) {
      throw ReloadlyApiException(
        e.reasonPhrase ?? e.details?.toString() ?? 'Reloadly proxy unavailable',
        statusCode: e.status,
      );
    } catch (e) {
      throw ReloadlyApiException(e.toString());
    }
  }

  List<ReloadlyProductDto> _parseProducts(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ReloadlyProductDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /products
  Future<List<ReloadlyProductDto>> getProducts({
    String? productName,
    String? countryCode,
    bool includeFixed = true,
    bool includeRange = true,
  }) async {
    final result = await _invoke(
      'get_products',
      params: {
        if (productName != null && productName.isNotEmpty)
          'productName': productName,
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode,
        'includeFixed': includeFixed,
        'includeRange': includeRange,
      },
    );
    return _parseProducts(result['products']);
  }

  /// GET /products/{productId}
  Future<ReloadlyProductDto?> getProductById(int productId) async {
    final result = await _invoke(
      'get_product',
      params: {'productId': productId},
    );
    final raw = result['product'];
    if (raw is! Map) return null;
    return ReloadlyProductDto.fromJson(Map<String, dynamic>.from(raw));
  }

  /// GET /countries/{countryCode}/products
  Future<List<ReloadlyProductDto>> getProductsByCountry(String countryCode) async {
    final result = await _invoke(
      'get_products_by_country',
      params: {'countryCode': countryCode},
    );
    return _parseProducts(result['products']);
  }

  /// Full catalog sync (validate_catalog / sync_catalog)
  Future<ReloadlyCatalogSyncResult> syncCatalog() async {
    final result = await _invoke('sync_catalog');
    return ReloadlyCatalogSyncResult.fromJson(result);
  }

  /// POST /orders
  Future<ReloadlyOrderResponseDto> placeOrder({
    required int productId,
    required double unitPrice,
    required int quantity,
    required String recipientEmail,
    required String senderName,
    required String customIdentifier,
    String? countryCode,
  }) async {
    final result = await _invoke(
      'place_order',
      body: {
        'productId': productId,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'recipientEmail': recipientEmail,
        'senderName': senderName,
        'customIdentifier': customIdentifier,
        if (countryCode != null) 'countryCode': countryCode,
      },
    );
    final raw = result['order'];
    if (raw is! Map) {
      throw ReloadlyApiException('Missing order payload from Reloadly');
    }
    return ReloadlyOrderResponseDto.fromJson(Map<String, dynamic>.from(raw));
  }

  /// GET /orders/transactions/{transactionId}/cards
  Future<List<ReloadlyRedeemCodeDto>> getRedeemCodes(int transactionId) async {
    final result = await _invoke(
      'get_redeem_codes',
      params: {'transactionId': transactionId},
    );
    final raw = result['cards'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ReloadlyRedeemCodeDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /reports/transactions/{transactionId}
  Future<ReloadlyTransactionDto?> getTransaction(int transactionId) async {
    final result = await _invoke(
      'get_transaction',
      params: {'transactionId': transactionId},
    );
    final raw = result['transaction'];
    if (raw is! Map) return null;
    return ReloadlyTransactionDto.fromJson(Map<String, dynamic>.from(raw));
  }

  /// GET /reports/transactions
  Future<List<ReloadlyTransactionDto>> getTransactions({
    String? startDate,
    String? endDate,
  }) async {
    final result = await _invoke(
      'get_transactions',
      params: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    final raw = result['transactions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ReloadlyTransactionDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /redeem-instructions
  Future<List<ReloadlyRedeemInstructionDto>> getRedeemInstructions() async {
    final result = await _invoke('get_redeem_instructions');
    final raw = result['instructions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) =>
            ReloadlyRedeemInstructionDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /redeem-instructions/{brandId}
  Future<ReloadlyRedeemInstructionDto?> getRedeemInstructionsByBrand(
    int brandId,
  ) async {
    final result = await _invoke(
      'get_redeem_instructions_by_brand',
      params: {'brandId': brandId},
    );
    final raw = result['instruction'];
    if (raw is! Map) return null;
    return ReloadlyRedeemInstructionDto.fromJson(Map<String, dynamic>.from(raw));
  }

  /// GET /discounts
  Future<List<Map<String, dynamic>>> getDiscounts({int? size, int? page}) async {
    final result = await _invoke(
      'get_discounts',
      params: {
        if (size != null) 'size': size,
        if (page != null) 'page': page,
      },
    );
    final raw = result['discounts'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// GET /products/{productId}/discounts
  Future<Map<String, dynamic>?> getProductDiscount(int productId) async {
    final result = await _invoke(
      'get_product_discount',
      params: {'productId': productId},
    );
    final raw = result['discount'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Composite health probe
  Future<Map<String, dynamic>> getHealthStatus() async {
    final result = await _invoke('health_check');
    return Map<String, dynamic>.from(result);
  }
}

class ReloadlyApiException implements Exception {
  ReloadlyApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  bool get isCredentialsMissing =>
      message.toLowerCase().contains('credential') ||
      message.toLowerCase().contains('not configured');
}
