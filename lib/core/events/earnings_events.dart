import 'package:get/get.dart';

/// Global event service for earnings updates
/// Provides a simple callback-based mechanism for automatic refresh
class EarningsEventService extends GetxService {
  static EarningsEventService get to => Get.find();

  // List of callbacks to notify when earnings are updated
  final List<Function()> _callbacks = [];

  /// Register a callback to be called when earnings are updated
  void onEarningsUpdated(Function() callback) {
    _callbacks.add(callback);
  }

  /// Unregister a callback
  void removeCallback(Function() callback) {
    _callbacks.remove(callback);
  }

  /// Trigger an earnings update event
  /// This will notify all registered callbacks
  void triggerEarningsUpdate({String? source}) {
    // Call all registered callbacks
    for (final callback in _callbacks) {
      try {
        callback();
      } catch (e) {
        // Ignore errors in callbacks to prevent cascading failures
      }
    }
  }
}
