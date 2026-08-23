import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Centralized notification deep-link router for the Kasby user app.
class NotificationNavigationService {
  NotificationNavigationService._();

  static String? _lastNavigationKey;
  static Map<String, String>? _pendingPayload;

  /// All registered user-app routes (must match [AppPages.routes]).
  static final _knownRoutes = {
    Routes.splash,
    Routes.onboarding,
    Routes.login,
    Routes.register,
    Routes.otp,
    Routes.forgotPassword,
    Routes.home,
    Routes.investmentPlans,
    Routes.investmentDetails,
    Routes.myInvestments,
    Routes.wallet,
    Routes.deposit,
    Routes.withdraw,
    Routes.agents,
    Routes.spinWheel,
    Routes.dailyCheckIn,
    Routes.subscription,
    Routes.notifications,
    Routes.profile,
    Routes.support,
    Routes.legal,
    Routes.agentDetails,
    Routes.transfer,
    Routes.loan,
    Routes.editProfile,
    Routes.friendRequests,
    Routes.agencyApply,
    Routes.myTeam,
    Routes.kyc,
    Routes.supportChat,
    Routes.socialChat,
    Routes.changePassword,
    Routes.allTransactions,
    Routes.transactionDetails,
    Routes.personalProfile,
    Routes.lockScreen,
    Routes.agentDashboard,
    Routes.profileUpdate,
    Routes.qrScanner,
    Routes.myQr,
    Routes.store,
    Routes.storeOrders,
  };

  static Future<void> navigateFromPayload(
    Map<String, dynamic> rawData, {
    bool fromUserTap = true,
  }) async {
    final data = rawData.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    if (data['type'] == 'otp_verification') return;

    debugPrint(
      '[PROFIT_NAVIGATION] PAYLOAD RECEIVED -> type: ${data['type']} | entity_id: ${data['entity_id']} | route: ${data['route']} | fromUserTap: $fromUserTap',
    );
    SafeGetx.debugTrace(
      className: 'NotificationNavigationService',
      method: 'navigateFromPayload',
      feature: 'Core',
      status: 'INFO',
      params: {'type': data['type'] ?? 'unknown', 'fromUserTap': fromUserTap},
    );

    if (!SupabaseService.isLoggedIn) {
      _pendingPayload = data;
      return;
    }

    await _executeNavigation(data, fromUserTap: fromUserTap);
  }

  /// Call after login/splash to drain a cold-start notification.
  static Future<void> processPendingNavigation() async {
    final pending = _pendingPayload;
    if (pending == null || !SupabaseService.isLoggedIn) return;
    _pendingPayload = null;
    await _executeNavigation(pending, fromUserTap: true);
  }

  /// Navigate from an in-app notification list item.
  static Future<void> navigateFromModel(NotificationModel notification) async {
    await navigateFromPayload({
      'type': notification.type,
      'id': notification.id,
      'route':
          notification.deepLink ??
          resolveRoute(
            type: notification.type,
            deepLink: notification.deepLink,
            entityType: notification.entityType,
          ),
      'entity_type': notification.entityType ?? '',
      'entity_id': notification.entityId ?? '',
      'target_user_id': notification.targetUserId ?? '',
      'deep_link': notification.deepLink ?? '',
    }, fromUserTap: true);
  }

  /// Parse local-notification payload string (JSON-encoded FCM data).
  static Future<void> navigateFromLocalPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        await navigateFromPayload(decoded, fromUserTap: true);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationNavigationService',
        method: 'navigateFromLocalPayload',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static String resolveRoute({
    required String? type,
    String? deepLink,
    String? entityType,
  }) {
    if (deepLink != null && deepLink.isNotEmpty) {
      return _normalizeUserRoute(deepLink);
    }

    switch (type) {
      case 'deposit_submitted':
      case 'deposit_approved':
      case 'deposit_rejected':
        return Routes.deposit;
      case 'withdrawal_requested':
      case 'withdrawal_approved':
      case 'withdrawal_rejected':
      case 'withdrawal_completed':
        return Routes.withdraw;
      case 'transfer_received':
      case 'transfer_sent':
        return Routes.wallet;
      case 'loan_requested':
      case 'loan_approved':
      case 'loan_rejected':
      case 'loan_repayment_due':
      case 'loan_overdue':
      case 'loan_paid':
        return Routes.loan;
      case 'investment_created':
      case 'daily_profit':
      case 'investment_matured':
      case 'investment_cancelled':
        return Routes.myInvestments;
      case 'referral_bonus':
      case 'reward':
        return Routes.myTeam;
      case 'kyc_approved':
      case 'kyc_rejected':
        return Routes.kyc;
      case 'account_flagged':
      case 'account_frozen':
      case 'account_unblocked':
      case 'profile_updated':
      case 'account_deleted':
      case 'role_upgraded':
        return Routes.personalProfile;
      case 'social_friend_request':
      case 'social_friend_accepted':
      case 'social_friend_removed':
        return Routes.friendRequests;
      case 'social_chat':
        return Routes.socialChat;
      case 'chat_admin_reply':
      case 'chat_new_message':
      case 'chat_resolved':
      case 'chat_escalated':
      case 'admin_new_chat':
        return Routes.supportChat;
      case 'agent_deposit_pending':
      case 'agent_withdrawal_pending':
      case 'agent_role_change':
        return Routes.agentDashboard;
      case 'store_purchase':
      case 'store_order':
        return Routes.storeOrders;
      case 'check_in_reminder':
        return Routes.dailyCheckIn;
      case 'announcement':
      case 'maintenance':
      case 'security_alert':
      case 'system':
      case 'info':
      case 'warning':
      case 'notification':
      case 'success':
      case 'critical':
        return Routes.notifications;
      default:
        if (entityType == 'transaction') return Routes.transactionDetails;
        if (entityType == 'conversation') return Routes.supportChat;
        if (entityType == 'investment') return Routes.myInvestments;
        if (entityType == 'store_order') return Routes.storeOrders;
        return Routes.notifications;
    }
  }

  static String _normalizeUserRoute(String route) {
    final normalized = route.startsWith('/') ? route : '/$route';
    const mapping = {
      '/deposit': Routes.deposit,
      '/withdraw': Routes.withdraw,
      '/wallet': Routes.wallet,
      '/loan': Routes.loan,
      '/investments': Routes.myInvestments,
      '/my-investments': Routes.myInvestments,
      '/investment-plans': Routes.investmentPlans,
      '/investment-details': Routes.investmentDetails,
      '/my-team': Routes.myTeam,
      '/kyc': Routes.kyc,
      '/friend-requests': Routes.friendRequests,
      '/social-chat': Routes.socialChat,
      '/support-chat': Routes.supportChat,
      '/chat': Routes.supportChat,
      '/notifications': Routes.notifications,
      '/agent-dashboard': Routes.agentDashboard,
      '/ksp-wallet': Routes.spinWheel,
      '/my-qr': Routes.myQr,
      '/qr-scanner': Routes.qrScanner,
      '/profile': Routes.profile,
      '/transaction-details': Routes.transactionDetails,
      '/daily-check-in': Routes.dailyCheckIn,
      '/all-transactions': Routes.allTransactions,
      '/transfer': Routes.transfer,
      '/spin-wheel': Routes.spinWheel,
      '/store': Routes.store,
      '/store-orders': Routes.storeOrders,
      '/home': Routes.home,
    };
    return mapping[normalized] ?? normalized;
  }

  static bool _isKnownRoute(String route) => _knownRoutes.contains(route);

  /// Resolves a route string, falling back to type-based resolution when unknown.
  static String _resolveSafeRoute(Map<String, String> data) {
    var route = data['route'];
    if (route != null && route.isNotEmpty) {
      route = _normalizeUserRoute(route);
      if (_isKnownRoute(route)) return route;
      SafeGetx.debugTrace(
        className: 'NotificationNavigationService',
        method: '_resolveSafeRoute',
        feature: 'Core',
        status: 'WARN',
        message: 'Unknown deep link route — resolving from notification type',
        params: {'requestedRoute': route, 'type': data['type'] ?? 'unknown'},
      );
    }

    final resolved = resolveRoute(
      type: data['type'],
      deepLink: data['deep_link'],
      entityType: data['entity_type'],
    );
    if (_isKnownRoute(resolved)) return resolved;

    SafeGetx.debugTrace(
      className: 'NotificationNavigationService',
      method: '_resolveSafeRoute',
      feature: 'Core',
      status: 'WARN',
      message: 'Falling back to notifications list',
      params: {'type': data['type'] ?? 'unknown'},
    );
    return Routes.notifications;
  }

  static Future<void> _executeNavigation(
    Map<String, String> data, {
    required bool fromUserTap,
  }) async {
    if (!fromUserTap) return;

    final route = _resolveSafeRoute(data);

    SafeGetx.debugTrace(
      className: 'NotificationNavigationService',
      method: '_executeNavigation',
      feature: 'Core',
      status: 'INFO',
      params: {'route': route, 'type': data['type'] ?? 'unknown'},
    );

    final navKey = '${route}_${data['id']}_${data['entity_id']}';
    if (_lastNavigationKey == navKey) return;
    _lastNavigationKey = navKey;

    await Future.delayed(const Duration(milliseconds: 350));

    if (Get.currentRoute == route &&
        data['entity_id']?.isEmpty != false &&
        data['target_user_id']?.isEmpty != false) {
      return;
    }

    try {
      final args = await _buildArguments(data, route);
      debugPrint(
        '[PROFIT_NAVIGATION] NOTIFICATION TAP -> type: ${data['type']} | investment_id: ${data['entity_id']} | route: $route',
      );
      debugPrint(
        '[PROFIT_NAVIGATION] NAVIGATING -> target: $route | arguments: $args',
      );
      if (args != null) {
        await Get.toNamed(route, arguments: args);
      } else {
        await Get.toNamed(route);
      }
      SafeGetx.debugTrace(
        className: 'NotificationNavigationService',
        method: '_executeNavigation',
        feature: 'Core',
        status: 'SUCCESS',
        params: {'route': route},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationNavigationService',
        method: '_executeNavigation',
        feature: 'Core',
        status: 'FAILED',
        params: {'route': route},
        error: e,
        stackTrace: stack,
      );
    }
  }

  static Future<Map<String, dynamic>?> _buildArguments(
    Map<String, String> data,
    String route,
  ) async {
    final entityType = data['entity_type'] ?? '';
    final entityId = data['entity_id'] ?? '';
    final targetUserId = data['target_user_id'] ?? '';

    if (route == Routes.socialChat && targetUserId.isNotEmpty) {
      return {'friendId': targetUserId};
    }

    if (route == Routes.supportChat) {
      final args = <String, dynamic>{};
      if (entityType == 'conversation' && entityId.isNotEmpty) {
        args['conversation_id'] = entityId;
      }
      return args.isEmpty ? null : args;
    }

    if (route == Routes.transactionDetails && entityId.isNotEmpty) {
      final tx = await _fetchTransaction(entityId);
      if (tx != null) return {'transaction': tx};
      return null;
    }

    if (entityType == 'transaction' && entityId.isNotEmpty) {
      final tx = await _fetchTransaction(entityId);
      if (tx != null) {
        return {'transaction': tx};
      }
    }

    if (route == Routes.myInvestments ||
        entityType == 'investment' ||
        data['type'] == 'daily_profit') {
      if (entityId.isNotEmpty) {
        return {'investment_id': entityId, 'from_notification': true};
      }
    }

    if (route == Routes.storeOrders ||
        entityType == 'store_order' ||
        data['type'] == 'store_purchase') {
      final orderId = entityId.isNotEmpty ? entityId : (data['order_id'] ?? '');
      if (orderId.isNotEmpty) {
        return {'order_id': orderId, 'from_notification': true};
      }
    }

    return null;
  }

  static Future<TransactionModel?> _fetchTransaction(String id) async {
    try {
      final response = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return TransactionModel.fromJson(response);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationNavigationService',
        method: '_fetchTransaction',
        feature: 'Core',
        status: 'ERROR',
        params: {'id': id},
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }
}
