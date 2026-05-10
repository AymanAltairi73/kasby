import 'package:get/get.dart';
import '../controllers/support_controller.dart';
import '../controllers/support_chat_controller.dart';

class SupportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupportController>(() => SupportController());
    Get.lazyPut<SupportChatController>(() => SupportChatController());
  }
}
