import 'package:get/get.dart';
import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';

class SocialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SocialNetworkController>(() => SocialNetworkController());
  }
}
