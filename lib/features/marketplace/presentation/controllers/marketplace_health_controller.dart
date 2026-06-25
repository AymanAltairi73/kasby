import 'package:get/get.dart';

import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/services/marketplace_health_service.dart';

class MarketplaceHealthController extends GetxController {
  MarketplaceHealthController({
    MarketplaceRepository? repository,
    MarketplaceHealthService? healthService,
  })  : _repo = repository ?? MarketplaceRepository(),
        _health = healthService ?? MarketplaceHealthService();

  final MarketplaceRepository _repo;
  final MarketplaceHealthService _health;

  final isLoading = true.obs;
  final hasError = false.obs;
  final healthData = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    refreshHealth();
  }

  Future<void> refreshHealth() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final providerHealth = await _repo.getMarketplaceHealth();
      final dashboard = await _health.getDashboardData();
      healthData.value = {
        ...providerHealth,
        'dashboard': dashboard,
      };
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}
