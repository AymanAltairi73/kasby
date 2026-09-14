import 'package:get/get.dart';

/// DEPRECATED: Screen lock and lifecycle management have been unified in [SessionService].
/// This class is retained as a no-op stub to prevent breaking any residual references.
@Deprecated('Use SessionService')
class AppLifecycleLockService extends GetxService {
  static AppLifecycleLockService get to =>
      Get.isRegistered<AppLifecycleLockService>()
          ? Get.find<AppLifecycleLockService>()
          : Get.put(AppLifecycleLockService());
}
