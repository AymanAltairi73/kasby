import 'package:get/get.dart';
import '../datasources/topup_remote_datasource.dart';
import '../datasources/store_local_datasource.dart';
import '../repositories/store_repository.dart';
import '../services/store_service.dart';
import '../controllers/store_controller.dart';
import '../controllers/store_cart_controller.dart';
import '../controllers/store_order_controller.dart';

class StoreBinding extends Bindings {
  @override
  void dependencies() {
    final remoteDs = TopupRemoteDatasource();
    final localDs = StoreLocalDatasource();
    final repository = StoreRepository(
      remoteDatasource: remoteDs,
      localDatasource: localDs,
    );
    final service = StoreService(repository: repository);

    Get.lazyPut<StoreCartController>(() => StoreCartController(), fenix: true);
    Get.lazyPut<StoreController>(() => StoreController(storeService: service), fenix: true);
    Get.lazyPut<StoreOrderController>(() => StoreOrderController(storeService: service), fenix: true);
  }
}
