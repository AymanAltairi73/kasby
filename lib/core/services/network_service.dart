import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// حالة الاتصال بالإنترنت
enum ConnectionStatus {
  /// متصل بالإنترنت
  connected,

  /// منقطع عن الإنترنت
  disconnected,

  /// جاري التحقق
  checking,
}

/// جودة الاتصال بالإنترنت
enum ConnectionQuality {
  /// جيدة - سرعة عالية
  good,

  /// ضعيفة - بطيئة
  weak,

  /// غير معروفة
  unknown,
}

/// خدمة مركزية لإدارة حالة الاتصال بالإنترنت.
/// تعمل مع جميع أنواع الشبكات (WiFi, 4G/5G, Starlink, etc.)
/// لا تقيّد نوع الشبكة — فقط تتحقق من وجود اتصال فعلي.
class NetworkService extends GetxService {
  // ─────────── State ───────────
  final connectionStatus = ConnectionStatus.checking.obs;
  final isConnected = true.obs;
  final connectionQuality = ConnectionQuality.unknown.obs;

  // ─────────── Internal ───────────
  final Connectivity _connectivity = Connectivity();
  late final InternetConnection _internetChecker;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InternetStatus>? _internetSub;
  Timer? _retryTimer;
  Timer? _speedCheckTimer;

  /// Whether the device currently has internet access.
  bool get hasConnection => isConnected.value;

  // ─────────── Lifecycle ───────────

  /// Initialize the service. Call via Get.putAsync().
  Future<NetworkService> init() async {
    _internetChecker = InternetConnection.createInstance(
      checkInterval: const Duration(seconds: 10),
    );

    // 1. Check initial state
    await _checkConnection();

    // 2. Listen to connectivity changes (WiFi on/off, mobile data, etc.)
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) => _onConnectivityChanged(results),
    );

    // 3. Listen to actual internet availability
    _internetSub = _internetChecker.onStatusChange.listen(
      (status) => _onInternetStatusChanged(status),
    );

    debugPrint('[NetworkService] ✓ Initialized. Online: ${isConnected.value}');

    // 4. Start periodic speed checks
    _startSpeedChecks();

    return this;
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    _internetSub?.cancel();
    _retryTimer?.cancel();
    _speedCheckTimer?.cancel();
    super.onClose();
  }

  /// بدء فحص دوري لجودة الاتصال
  void _startSpeedChecks() {
    _speedCheckTimer?.cancel();
    _speedCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected.value) {
        _checkConnectionQuality();
      }
    });
  }

  /// فحص جودة الاتصال عن طريق قياس زمن الاستجابة
  Future<void> _checkConnectionQuality() async {
    try {
      final stopwatch = Stopwatch()..start();

      // محاولة الاتصال بـ Google DNS أو أي endpoint موثوق
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 5));
      socket.destroy();

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      // تحديد الجودة بناءً على زمن الاستجابة
      if (latency < 150) {
        connectionQuality.value = ConnectionQuality.good;
        debugPrint('[NetworkService] ✓ Connection quality: GOOD (${latency}ms)');
      } else if (latency < 500) {
        connectionQuality.value = ConnectionQuality.weak;
        debugPrint('[NetworkService] ⚠ Connection quality: WEAK (${latency}ms)');
      } else {
        connectionQuality.value = ConnectionQuality.weak;
        debugPrint('[NetworkService] ⚠ Connection quality: POOR (${latency}ms)');
      }
    } catch (e) {
      connectionQuality.value = ConnectionQuality.unknown;
      debugPrint('[NetworkService] ✗ Speed check failed: $e');
    }
  }

  // ─────────── Core Logic ───────────

  /// Manually check current connection status.
  Future<void> _checkConnection() async {
    connectionStatus.value = ConnectionStatus.checking;
    try {
      final hasInternet = await _internetChecker.hasInternetAccess;
      _updateStatus(hasInternet);
    } catch (e) {
      _updateStatus(false);
      debugPrint('[NetworkService] ✗ Check failed: $e');
    }
  }

  /// Called when the network adapter changes (WiFi/Mobile/None).
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasAnyConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasAnyConnection) {
      _updateStatus(false);
    } else {
      // Network adapter connected, verify actual internet
      _checkConnection();
    }
  }

  /// Called when actual internet availability changes.
  void _onInternetStatusChanged(InternetStatus status) {
    _updateStatus(status == InternetStatus.connected);
  }

  /// Update all reactive state.
  void _updateStatus(bool online) {
    final wasOffline = !isConnected.value;
    isConnected.value = online;
    connectionStatus.value =
        online ? ConnectionStatus.connected : ConnectionStatus.disconnected;

    if (online && wasOffline) {
      debugPrint('[NetworkService] ✓ Connection restored.');
      _retryTimer?.cancel();
    } else if (!online && !wasOffline) {
      debugPrint('[NetworkService] ✗ Connection lost.');
      _startRetryLoop();
    }
  }

  /// Periodically retry connection check when offline.
  void _startRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!isConnected.value) {
        _checkConnection();
      } else {
        _retryTimer?.cancel();
      }
    });
  }

  /// Force a manual retry (useful for retry buttons).
  Future<void> retryConnection() async {
    await _checkConnection();
  }

  // ─────────── API Guard ───────────

  /// Wraps any async API call with a connectivity check.
  /// Returns `null` and shows a snackbar if offline.
  ///
  /// Usage:
  /// ```dart
  /// final result = await NetworkService.to.guardedRequest(() async {
  ///   return await SupabaseService.client.from('profiles').select();
  /// });
  /// ```
  Future<T?> guardedRequest<T>(Future<T> Function() request) async {
    if (!isConnected.value) {
      Get.snackbar(
        'no_internet'.tr.isNotEmpty ? 'no_internet'.tr : 'لا يوجد اتصال',
        'check_connection'.tr.isNotEmpty
            ? 'check_connection'.tr
            : 'يرجى التحقق من اتصالك بالإنترنت.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return null;
    }

    try {
      return await request();
    } on SocketException {
      _updateStatus(false);
      return null;
    } on TimeoutException {
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Shortcut for accessing the service.
  static NetworkService get to => Get.find<NetworkService>();
}
