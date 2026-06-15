import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../data/services/chat_storage_service.dart';

class SupportController extends GetxController {
  final ChatStorageService _storage = ChatStorageService();
  final _unreadCount = 0.obs;

  int get unreadCount => _unreadCount.value;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'SupportController',
      method: 'onInit',
      feature: 'Support',
      status: 'INFO',
    );
    super.onInit();
    loadUnreadCount();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'SupportController',
      method: 'onClose',
      feature: 'Support',
      status: 'INFO',
    );
    super.onClose();
  }

  Future<void> loadUnreadCount() async {
    _unreadCount.value = await _storage.getUnreadCount();
    SafeGetx.debugTrace(
      className: 'SupportController',
      method: 'loadUnreadCount',
      feature: 'Support',
      status: 'SUCCESS',
      params: {'count': _unreadCount.value},
    );
  }

  Future<void> incrementUnreadCount() async {
    _unreadCount.value++;
    await _storage.setUnreadCount(_unreadCount.value);
    SafeGetx.debugTrace(
      className: 'SupportController',
      method: 'incrementUnreadCount',
      feature: 'Support',
      status: 'INFO',
      params: {'count': _unreadCount.value},
    );
  }

  Future<void> clearUnreadCount() async {
    _unreadCount.value = 0;
    // Clearing local count, Supabase messages already marked read in SupportChatController
    await _storage.clearUnreadCount();
    SafeGetx.debugTrace(
      className: 'SupportController',
      method: 'clearUnreadCount',
      feature: 'Support',
      status: 'INFO',
    );
  }
}
