import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/store_service.dart';

class StoreOrderController extends GetxController {
  static StoreOrderController get to => Get.find();

  final StoreService storeService;

  StoreOrderController({required this.storeService});

  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    isLoading.value = true;
    error.value = '';
    try {
      final list = await storeService.getOrderHistory();
      orders.assignAll(list);
    } catch (e) {
      _log('Error fetching orders: $e', isError: true);
      error.value = 'تعذر تحميل سجل الطلبات';
    } finally {
      isLoading.value = false;
    }
  }

  void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      print('[STORE_ORDER_CONTROLLER] ${isError ? '❌' : 'ℹ️'} $message');
    }
  }
}
