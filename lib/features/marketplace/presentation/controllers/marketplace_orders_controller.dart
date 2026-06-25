import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import '../../domain/models/marketplace_order.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceOrdersController extends GetxController {
  final MarketplaceRepository _repo;

  MarketplaceOrdersController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final orders = <MarketplaceOrder>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final filterStatus = Rxn<MarketplaceOrderStatus>();

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      orders.value = await _repo.getOrders(
        status: filterStatus.value,
        userId: SupabaseService.userId,
      );
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(MarketplaceOrderStatus? status) {
    filterStatus.value = status;
    loadOrders();
  }

  Future<MarketplaceOrder?> getOrderDetail(String id) => _repo.getOrderById(id);

  Future<Map<String, dynamic>?> refreshOrderStatus(String orderId) =>
      _repo.refreshOrderProviderStatus(orderId);
}
