import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kasby/core/utils/safe_getx.dart';

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
class NetworkService extends GetxService with WidgetsBindingObserver {
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
  Timer? _offlineConfirmTimer;
  int _consecutiveOfflineChecks = 0;
  bool _hasNetworkAdapter = true;

  /// Whether the device currently has internet access.
  bool get hasConnection => isConnected.value;

  // ─────────── Lifecycle ───────────

  /// Initialize the service. Call via Get.putAsync().
  Future<NetworkService> init() async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(
      className: 'NetworkService',
      method: 'init',
      feature: 'Core',
      status: 'INFO',
    );

    _internetChecker = InternetConnection.createInstance(
      checkInterval: const Duration(seconds: 15),
      useDefaultOptions: false,
      customCheckOptions: _buildCheckOptions(),
    );

    WidgetsBinding.instance.addObserver(this);

    // 1. Check initial adapter state
    try {
      final initialResults = await _connectivity.checkConnectivity();
      _hasNetworkAdapter =
          initialResults.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _hasNetworkAdapter = true;
    }

    // 2. Check initial internet state
    await _checkConnection();

    // 3. Listen to connectivity changes (WiFi on/off, mobile data, etc.)
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) => _onConnectivityChanged(results),
    );

    // 4. Listen to actual internet availability
    _internetSub = _internetChecker.onStatusChange.listen(
      (status) => _onInternetStatusChanged(status),
    );

    SafeGetx.debugTrace(
      className: 'NetworkService',
      method: 'init',
      feature: 'Core',
      status: 'SUCCESS',
      params: {'online': isConnected.value},
      durationMs: stopwatch.elapsedMilliseconds,
    );

    // 5. Start periodic speed checks
    _startSpeedChecks();

    return this;
  }

  List<InternetCheckOption> _buildCheckOptions() {
    final options = <InternetCheckOption>[];

    if (dotenv.isInitialized) {
      final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
      if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
        options.add(
          InternetCheckOption(
            uri: Uri.parse('$supabaseUrl/auth/v1/health'),
            timeout: const Duration(seconds: 8),
          ),
        );
      }
    }

    options.addAll([
      InternetCheckOption(
        uri: Uri.parse('https://one.one.one.one'),
        timeout: const Duration(seconds: 8),
      ),
      InternetCheckOption(
        uri: Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'),
        timeout: const Duration(seconds: 8),
      ),
    ]);

    return options;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consecutiveOfflineChecks = 0;
      _checkConnection();
    }
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'NetworkService',
      method: 'onClose',
      feature: 'Core',
      status: 'INFO',
    );
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _internetSub?.cancel();
    _retryTimer?.cancel();
    _speedCheckTimer?.cancel();
    _offlineConfirmTimer?.cancel();
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

      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (latency < 150) {
        connectionQuality.value = ConnectionQuality.good;
      } else if (latency < 500) {
        connectionQuality.value = ConnectionQuality.weak;
      } else {
        connectionQuality.value = ConnectionQuality.weak;
      }
    } catch (e, stack) {
      connectionQuality.value = ConnectionQuality.unknown;
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: '_checkConnectionQuality',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ─────────── Core Logic ───────────

  /// Manually check current connection status.
  Future<void> _checkConnection() async {
    connectionStatus.value = ConnectionStatus.checking;
    try {
      if (!_hasNetworkAdapter) {
        _applyConnectivityResult(false);
        return;
      }

      final hasInternet = await _internetChecker.hasInternetAccess;
      _applyConnectivityResult(hasInternet);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: '_checkConnection',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      _applyConnectivityResult(false);
    }
  }

  /// Called when the network adapter changes (WiFi/Mobile/None).
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _hasNetworkAdapter = results.any((r) => r != ConnectivityResult.none);
    if (!_hasNetworkAdapter) {
      _consecutiveOfflineChecks = 2;
      _applyConnectivityResult(false);
    } else {
      _consecutiveOfflineChecks = 0;
      _checkConnection();
    }
  }

  /// Called when actual internet availability changes.
  void _onInternetStatusChanged(InternetStatus status) {
    _applyConnectivityResult(status == InternetStatus.connected);
  }

  void _applyConnectivityResult(bool online) {
    if (online) {
      _consecutiveOfflineChecks = 0;
      _offlineConfirmTimer?.cancel();
      _updateStatus(true);
      return;
    }

    _consecutiveOfflineChecks++;
    if (!_hasNetworkAdapter) {
      _scheduleOfflineConfirmation();
      return;
    }

    if (_consecutiveOfflineChecks >= 2) {
      _scheduleOfflineConfirmation();
    }
  }

  void _scheduleOfflineConfirmation() {
    _offlineConfirmTimer?.cancel();
    _offlineConfirmTimer = Timer(const Duration(seconds: 2), () async {
      if (!_hasNetworkAdapter) {
        _updateStatus(false);
        return;
      }
      try {
        final stillOffline = !await _internetChecker.hasInternetAccess;
        if (stillOffline) {
          _updateStatus(false);
        } else {
          _consecutiveOfflineChecks = 0;
          _updateStatus(true);
        }
      } catch (_) {
        _updateStatus(false);
      }
    });
  }

  /// Update all reactive state.
  void _updateStatus(bool online) {
    final wasOffline = !isConnected.value;
    isConnected.value = online;
    connectionStatus.value =
        online ? ConnectionStatus.connected : ConnectionStatus.disconnected;

    if (online && wasOffline) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: '_updateStatus',
        feature: 'Core',
        status: 'SUCCESS',
        message: 'Connection restored',
      );
      _retryTimer?.cancel();
    } else if (!online && !wasOffline) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: '_updateStatus',
        feature: 'Core',
        status: 'WARN',
        message: 'Connection lost',
      );
      _startRetryLoop();
    }
  }

  /// Periodically retry connection check when offline.
  void _startRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!isConnected.value) {
        _checkConnection();
      } else {
        _retryTimer?.cancel();
      }
    });
  }

  /// Force a manual retry (useful for retry buttons).
  Future<void> retryConnection() async {
    _consecutiveOfflineChecks = 0;
    await _checkConnection();
  }

  // ─────────── API Guard ───────────

  /// Wraps any async API call with a connectivity check.
  /// Returns `null` and shows a snackbar if offline.
  Future<T?> guardedRequest<T>(Future<T> Function() request) async {
    if (!isConnected.value) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: 'guardedRequest',
        feature: 'Core',
        status: 'WARN',
        message: 'Request blocked: offline',
      );
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

    final stopwatch = Stopwatch()..start();
    try {
      final result = await request();
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: 'guardedRequest',
        feature: 'Core',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return result;
    } on SocketException catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: 'guardedRequest',
        feature: 'Core',
        status: 'ERROR',
        message: 'SocketException — scheduling connectivity recheck',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      unawaited(_checkConnection());
      return null;
    } on TimeoutException catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: 'guardedRequest',
        feature: 'Core',
        status: 'ERROR',
        message: 'TimeoutException',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      return null;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NetworkService',
        method: 'guardedRequest',
        feature: 'Core',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Shortcut for accessing the service.
  static NetworkService get to => Get.find<NetworkService>();
}
