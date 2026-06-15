import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../controllers/support_controller.dart';
import '../controllers/support_chat_controller.dart';

class SupportBinding extends Bindings {
  @override
  void dependencies() {
    SafeGetx.debugTrace(
      className: 'SupportBinding',
      method: 'dependencies',
      feature: 'Support',
      status: 'INFO',
      message: 'Binding controllers',
      params: {
        'controllers': 'SupportController, SupportChatController',
      },
    );
    Get.lazyPut<SupportController>(() => SupportController());
    Get.lazyPut<SupportChatController>(() => SupportChatController(), fenix: true);
  }
}
