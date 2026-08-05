import 'package:flutter/foundation.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/store/domain/models/store_banner_model.dart';
import 'package:kasby/features/store/domain/models/store_category_model.dart';
import 'package:kasby/features/store/domain/models/store_order_model.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';

class StoreService {
  final _client = SupabaseService.client;

  Future<List<StoreBannerModel>> fetchBanners() async {
    try {
      final response = await _client
          .from('marketplace_banners')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = (response as List<dynamic>)
          .map((e) => StoreBannerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching banners: $e');
      return [];
    }
  }

  Future<List<StoreCategoryModel>> fetchCategories() async {
    try {
      final response = await _client
          .from('marketplace_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = (response as List<dynamic>)
          .map((e) => StoreCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching categories: $e');
      return [];
    }
  }

  Future<List<StoreProductModel>> fetchProducts({
    String? categoryId,
    bool? isTopSelling,
    bool? isFeatured,
    bool? isNew,
  }) async {
    try {
      var query = _client
          .from('marketplace_products')
          .select()
          .eq('is_active', true);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      if (isTopSelling == true) {
        query = query.eq('is_top_selling', true);
      }
      if (isFeatured == true) {
        query = query.eq('is_featured', true);
      }
      if (isNew == true) {
        query = query.eq('is_new', true);
      }

      final response = await query.order('sort_order', ascending: true);
      final rawList = response as List<dynamic>;
      if (rawList.isEmpty) return [];

      final productIds = rawList.map((e) => e['id'] as String).toList();
      final stockMap = await fetchStockCounts(productIds);

      return rawList.map((e) {
        final json = e as Map<String, dynamic>;
        final pid = json['id'] as String;
        return StoreProductModel.fromJson(json, stock: stockMap[pid] ?? 0);
      }).toList();
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching products: $e');
      return [];
    }
  }

  Future<Map<String, int>> fetchStockCounts(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    try {
      final response = await _client
          .from('marketplace_digital_codes')
          .select('product_id')
          .inFilter('product_id', productIds)
          .eq('is_used', false);

      final counts = <String, int>{};
      for (final item in response as List<dynamic>) {
        final pid = item['product_id'] as String;
        counts[pid] = (counts[pid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching stock counts: $e');
      return {};
    }
  }

  Future<List<StoreOrderModel>> fetchOrders() async {
    final userId = SupabaseService.userId;
    if (userId == null) return [];
    try {
      final response = await _client
          .from('marketplace_orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) => StoreOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error fetching orders: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> buyProduct({
    required String productId,
    required String paymentMethod,
  }) async {
    try {
      final response = await _client.rpc(
        'fn_marketplace_buy_product',
        params: {
          'p_product_id': productId,
          'p_payment_method': paymentMethod,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[STORE_SERVICE] Error buying product: $e');
      return {
        'success': false,
        'error': 'exception',
        'message_ar': 'حدث خطأ أثناء إجراء الشراء: $e',
      };
    }
  }
}
