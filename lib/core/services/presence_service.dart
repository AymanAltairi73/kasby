import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
            final payloadData = presenceList.first.payload;
            final userId = payloadData['user_id']?.toString();
            if (userId != null) {
              users[userId] = payloadData;
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
        } else if (error != null) {
          SafeGetx.debugTrace(className: 'PresenceService', method: '_setupPresence', feature: 'Core', status: 'ERROR', error: error);
        }
      });
  }

  void _cleanupPresence() {
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
        if (SupabaseService.isLoggedIn && _presenceChannel == null) {
          _setupPresence();
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
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPresence();
    super.onClose();
  }
}
