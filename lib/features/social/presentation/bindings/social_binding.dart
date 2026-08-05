import 'package:get/get.dart';
import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';
import 'package:kasby/features/agent_chat/presentation/controllers/agent_conversations_controller.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';

class SocialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SocialNetworkController>(() => SocialNetworkController());
    if (Get.isRegistered<AuthController>() &&
        AuthController.to.userRole == 'agent') {
      Get.lazyPut<AgentConversationsController>(
        () => AgentConversationsController(),
      );
    }
  }
}
