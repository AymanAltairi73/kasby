import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kasby/core/utils/safe_getx.dart';
import 'supabase_service.dart';

/// PresenceService — tracks online users and manages real-time presence for the User App.
class PresenceService extends GetxService with WidgetsBindingObserver {
  // Map of userId -> presence data
  final onlineUsers = <String, Map<String, dynamic>>{}.obs;
  RealtimeChannel? _presenceChannel;

  static String _truncateId(String? id) {
    if (id == null || id.isEmpty) return 'none';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }
  
  // Getters for UI
  int get onlineCount => onlineUsers.length;
  bool isUserOnline(String userId) => onlineUsers.containsKey(userId);
  
  DateTime? getLastSeen(String userId) {
    final userData = onlineUsers[userId];
    if (userData != null && userData['last_seen_at'] != null) {
      return DateTime.tryParse(userData['last_seen_at'].toString());
    }
    return null;
  }

  String getPresenceStatus(String userId) {
    if (isUserOnline(userId)) {
      return 'online';
    }
    final lastSeen = getLastSeen(userId);
    if (lastSeen == null) return 'offline';
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inMinutes < 1) {
      return 'active_now';
    } else if (diff.inMinutes < 5) {
      return 'last_seen_just_now';
    } else if (diff.inMinutes < 60) {
      return 'last_seen_minutes_ago';
    } else if (diff.inHours < 24) {
      return 'last_seen_hours_ago';
    } else if (diff.inDays == 1) {
      return 'last_seen_yesterday';
    } else {
      return 'last_seen_date';
    }
  }

  String getPresenceStatusText(String userId) {
    final status = getPresenceStatus(userId);
    final lastSeen = getLastSeen(userId);
    
    switch (status) {
      case 'online':
        return 'online'.tr;
      case 'active_now':
        return 'active_now'.tr;
      case 'last_seen_just_now':
        return 'last_seen_just_now'.tr;
      case 'last_seen_minutes_ago':
        final diff = DateTime.now().difference(lastSeen!);
        return 'last_seen_minutes_ago'.trParams({'count': '${diff.inMinutes}'});
      case 'last_seen_hours_ago':
        final diff = DateTime.now().difference(lastSeen!);
        return 'last_seen_hours_ago'.trParams({'count': '${diff.inHours}'});
      case 'last_seen_yesterday':
        return 'last_seen_yesterday'.tr;
      case 'last_seen_date':
        if (lastSeen != null) {
          return intl.DateFormat.yMd().format(lastSeen.toLocal());
        }
        return 'offline'.tr;
      default:
        return 'offline'.tr;
    }
  }

  StreamSubscription? _authSubscription;

  Future<PresenceService> init() async {
    SafeGetx.debugTrace(className: 'PresenceService', method: 'init', feature: 'Core', status: 'INFO');
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to login status to start/stop presence
    _authSubscription = SupabaseService.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        _setupPresence();
      } else {
        _cleanupPresence();
      }
    });

    if (SupabaseService.isLoggedIn) {
      _setupPresence();
      _updateLastSeen();
    }

    SafeGetx.debugTrace(className: 'PresenceService', method: 'init', feature: 'Core', status: 'SUCCESS');
    return this;
  }

  void _setupPresence() {
    _cleanupPresence();
    
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    SafeGetx.debugTrace(
      className: 'PresenceService',
      method: '_setupPresence',
      feature: 'Core',
      status: 'INFO',
      params: {'userId': _truncateId(user.id)},
    );

    _presenceChannel = client.channel('global-presence', opts: const RealtimeChannelConfig(self: true));

    _presenceChannel!
      .onPresenceSync((payload) {
        final newState = _presenceChannel!.presenceState();
        final users = <String, Map<String, dynamic>>{};
        
        for (final state in newState) {
          final presenceList = state.presences;
          if (presenceList.isNotEmpty) {
            for (final presence in presenceList) {
              final payloadData = presence.payload;
              final userId = payloadData['user_id']?.toString();
              if (userId != null) {
                users[userId] = {
                  ...payloadData,
                  'last_seen_at': payloadData['online_at'] ?? DateTime.now().toIso8601String(),
                };
              }
            }
          }
        }
        
        onlineUsers.assignAll(users);
      })
      .subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          SafeGetx.debugTrace(className: 'PresenceService', method: '_setupPresence', feature: 'Core', status: 'SUCCESS', message: 'Subscribed to presence channel');
          await _presenceChannel!.track({
            'user_id': user.id,
            'online_at': DateTime.now().toIso8601String(),
            'user_type': 'user',
          });
          _startHeartbeat();
        } else if (error != null) {
          SafeGetx.debugTrace(className: 'PresenceService', method: '_setupPresence', feature: 'Core', status: 'ERROR', error: error);
        }
      });
  }

  Timer? _heartbeatTimer;
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateHeartbeat();
    });
  }
  
  Future<void> _updateHeartbeat() async {
    if (_presenceChannel == null) return;
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await _presenceChannel!.track({
          'user_id': user.id,
          'online_at': DateTime.now().toIso8601String(),
          'user_type': 'user',
        });
      }
    } catch (e) {
      SafeGetx.debugTrace(className: 'PresenceService', method: '_updateHeartbeat', feature: 'Core', status: 'ERROR', error: e);
    }
  }

  void _cleanupPresence() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    onlineUsers.clear();
  }

  Future<void> _updateLastSeen() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      await SupabaseService.client.rpc('fn_update_last_seen');
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'PresenceService', method: '_updateLastSeen', feature: 'Core', status: 'ERROR', error: e, stackTrace: stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (SupabaseService.isLoggedIn) {
          if (_presenceChannel == null) _setupPresence();
          _updateLastSeen();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _updateLastSeen();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateLastSeen();
        _cleanupPresence();
        break;
    }
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(className: 'PresenceService', method: 'onClose', feature: 'Core', status: 'INFO');
    _authSubscription?.cancel();
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPresence();
    super.onClose();
  }
}
