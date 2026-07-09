import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/services/crash_reporting/crash_breadcrumb.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';

/// Safe wrappers around GetX navigation/snackbar APIs.
///
/// Get.snackbar before [GetMaterialApp] overlay is ready leaves a broken entry
/// in GetX's snackbar queue; subsequent [Get.back] then throws
/// [LateInitializationError] when trying to close it.
class SafeGetx {
  SafeGetx._();

  /// Structured debug trace for the User App (debug builds only).
  static void debugTrace({
    required String className,
    required String method,
    String status = 'INFO',
    String? feature,
    String? message,
    int? durationMs,
    Map<String, Object?>? params,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer(
      '[Kasby][UserApp][${feature ?? className}][$className][$method]\n'
      'STATUS: $status',
    );
    if (durationMs != null) buffer.write('\nDuration: ${durationMs}ms');
    if (message != null) buffer.write('\n$message');
    if (params != null && params.isNotEmpty) {
      for (final entry in params.entries) {
        buffer.write('\n${entry.key}: ${entry.value}');
      }
    }
    if (error != null) buffer.write('\nError: $error');
    if (stackTrace != null) buffer.write('\nStackTrace: $stackTrace');
    debugPrint(buffer.toString());
  }

  /// Logs GetX route transitions (deduped when GetX fires twice for the same hop).
  static String? _lastRouteLogKey;

  static void logRoute(Routing? routing) {
    if (routing == null) return;
    final key =
        '${routing.current}|${routing.previous}|${_safeArgs(routing.args)}';
    if (kDebugMode) {
      if (_lastRouteLogKey == key) return;
      _lastRouteLogKey = key;
      debugTrace(
        className: 'Navigation',
        method: 'routeChange',
        feature: 'Navigation',
        status: 'INFO',
        params: {
          'current': routing.current,
          'previous': routing.previous,
          'args': _safeArgs(routing.args),
        },
      );
    }
    unawaited(CrashReportingService.updateRouteContext(routing.current));
  }

  static String _safeArgs(dynamic args) {
    if (args == null) return 'none';
    final text = args.toString();
    return text.length > 200 ? '${text.substring(0, 200)}...' : text;
  }

  /// Wraps async work with duration, success/failure tracing (Supabase, RPC, business ops).
  static Future<T> traceAsync<T>({
    required String className,
    required String method,
    required Future<T> Function() operation,
    String? feature,
    Map<String, Object?>? params,
    Map<String, Object?>? Function(T result)? onSuccessParams,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugTrace(
        className: className,
        method: method,
        feature: feature ?? className,
        status: 'INFO',
        message: 'Operation started',
        params: params,
      );
    }
    try {
      final result = await operation();
      stopwatch.stop();
      if (kDebugMode) {
        final successParams = <String, Object?>{
          ...?params,
          ...?onSuccessParams?.call(result),
        };
        debugTrace(
          className: className,
          method: method,
          feature: feature ?? className,
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
          params: successParams.isEmpty ? null : successParams,
        );
        if (stopwatch.elapsedMilliseconds > 2000) {
          debugTrace(
            className: className,
            method: method,
            feature: 'Performance',
            status: 'WARNING',
            message: 'Slow operation detected',
            durationMs: stopwatch.elapsedMilliseconds,
            params: params,
          );
        }
      }
      return result;
    } catch (e, st) {
      stopwatch.stop();
      if (AccountRestrictionService.isRestrictionError(e) &&
          Get.isRegistered<AccountRestrictionService>()) {
        AccountRestrictionService.to.showRestrictionDialog();
      }
      if (kDebugMode) {
        debugTrace(
          className: className,
          method: method,
          feature: feature ?? className,
          status: 'FAILED',
          durationMs: stopwatch.elapsedMilliseconds,
          params: params,
          error: e,
          stackTrace: st,
        );
      } else {
        final category = CrashReportingService.categoryFromFeature(feature);
        if (e is PostgrestException ||
            e is AuthException ||
            e is FunctionException) {
          unawaited(CrashReportingService.recordSupabaseError(
            e,
            stack: st,
            operation: '$className.$method',
            category: category,
          ));
        } else if (e is SocketException || e is TimeoutException) {
          unawaited(CrashReportingService.recordNetworkError(
            e,
            st,
            operation: '$className.$method',
            isTimeout: e is TimeoutException,
          ));
        } else {
          unawaited(CrashReportingService.recordException(
            e,
            st,
            reason: '$className.$method',
            category: category,
            context: {
              'className': className,
              'method': method,
              ...?params,
            },
          ));
        }
      }
      rethrow;
    }
  }

  /// Blocks client-side writes when account is restricted (server still authoritative).
  static Future<T?> guardedWrite<T>({
    required Future<T> Function() operation,
    String? feature,
    bool showDialog = true,
  }) async {
    if (Get.isRegistered<AccountRestrictionService>() &&
        !AccountRestrictionService.to.checkWriteAccess(showDialog: showDialog)) {
      return null;
    }
    try {
      return await operation();
    } catch (e) {
      AccountRestrictionService.handleOperationError(e);
      rethrow;
    }
  }

  static bool get _hasOverlay {
    final overlay = Get.overlayContext;
    return overlay != null && overlay.mounted;
  }

  static void closeSnackbarIfOpen() {
    if (!Get.isSnackbarOpen) return;
    try {
      Get.closeCurrentSnackbar();
    } catch (_) {
      // Ignore broken snackbar controller state.
    }
  }

  /// Closes only the top overlay (dialog/bottom sheet) without popping routes.
  static void dismissOverlayIfOpen({bool closeSnackbar = false}) {
    if (closeSnackbar) closeSnackbarIfOpen();
    if (Get.isDialogOpen ?? false) {
      try {
        Get.back(closeOverlays: false);
        return;
      } catch (_) {}
    }
    if (Get.isBottomSheetOpen ?? false) {
      try {
        Get.back(closeOverlays: false);
      } catch (_) {}
    }
  }

  static void snackbar({
    required String title,
    required String message,
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Color? backgroundColor,
    Color? colorText,
    Widget? icon,
    EdgeInsets? margin,
    double? borderRadius,
    Duration? duration,
    OnTap? onTap,
  }) {
    if (!_hasOverlay) return;
    closeSnackbarIfOpen();
    try {
      Get.snackbar(
        title,
        message,
        snackPosition: snackPosition,
        backgroundColor: backgroundColor,
        colorText: colorText,
        icon: icon,
        margin: margin,
        borderRadius: borderRadius ?? 8,
        duration: duration ?? const Duration(seconds: 3),
        onTap: onTap,
      );
    } catch (_) {
      // Overlay not ready or snackbar failed to mount.
    }
  }

  static void back<T>({
    T? result,
    bool closeOverlays = true,
    bool canPop = true,
    int? id,
  }) {
    debugTrace(
      className: 'Navigation',
      method: 'back',
      feature: 'Navigation',
      status: 'INFO',
      params: {
        'from': Get.currentRoute,
        'result': result?.toString() ?? 'null',
      },
    );
    try {
      Get.back<T>(
        result: result,
        closeOverlays: closeOverlays,
        canPop: canPop,
        id: id,
      );
    } catch (_) {
      _navigatorPop<T>(result);
    }
  }

  static void _navigatorPop<T>(T? result) {
    closeSnackbarIfOpen();
    final context = Get.context;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }
}

extension SafeGetNavigation on GetInterface {
  void safeBack<T>({
    T? result,
    bool closeOverlays = true,
    bool canPop = true,
    int? id,
  }) {
    SafeGetx.back<T>(
      result: result,
      closeOverlays: closeOverlays,
      canPop: canPop,
      id: id,
    );
  }
}

/// Tracks screen open/close lifecycle for route-level observability.
class TrackedScreen extends StatefulWidget {
  final String screenName;
  final Widget child;

  const TrackedScreen({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<TrackedScreen> createState() => _TrackedScreenState();
}

class _TrackedScreenState extends State<TrackedScreen> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: widget.screenName,
      method: 'initState',
      feature: widget.screenName,
      status: 'INFO',
      message: 'Screen opened',
      params: {
        'route': Get.currentRoute,
        'hasArgs': Get.arguments != null,
      },
    );
    unawaited(CrashReportingService.updateRouteContext(
      Get.currentRoute,
      screenName: widget.screenName,
    ));
    unawaited(CrashReportingService.log(
      '${CrashBreadcrumb.screenOpened}: ${widget.screenName}',
    ));
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: widget.screenName,
      method: 'dispose',
      feature: widget.screenName,
      status: 'INFO',
      message: 'Screen closed',
      params: {'route': Get.currentRoute},
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
