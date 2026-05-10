import 'package:get/get.dart';
import '../../data/services/chat_storage_service.dart';

class SupportController extends GetxController {
  final ChatStorageService _storage = ChatStorageService();
  final _unreadCount = 0.obs;

  int get unreadCount => _unreadCount.value;

  @override
  void onInit() {
    super.onInit();
    loadUnreadCount();
  }

  Future<void> loadUnreadCount() async {
    _unreadCount.value = await _storage.getUnreadCount();
  }

  Future<void> incrementUnreadCount() async {
    _unreadCount.value++;
    await _storage.setUnreadCount(_unreadCount.value);
  }

  Future<void> clearUnreadCount() async {
    _unreadCount.value = 0;
    // Clearing local count, Supabase messages already marked read in SupportChatController
    await _storage.clearUnreadCount();
  }
}
