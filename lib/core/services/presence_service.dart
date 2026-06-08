import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// PresenceService — tracks online users and manages real-time presence for the User App.
class PresenceService extends GetxService with WidgetsBindingObserver {
  // Map of userId -> presence data
  final onlineUsers = <String, Map<String, dynamic>>{}.obs;
  RealtimeChannel? _presenceChannel;
  
  // Getters for UI
  int get onlineCount => onlineUsers.length;
  bool isUserOnline(String userId) => onlineUsers.containsKey(userId);

  StreamSubscription? _authSubscription;

  Future<PresenceService> init() async {
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

    return this;
  }

  void _setupPresence() {
    _cleanupPresence();
    
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    debugPrint('[PresenceService] ▶ Setting up presence channel for user: ${user.id}');

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
          debugPrint('[PresenceService] √ Subscribed to presence channel.');
          await _presenceChannel!.track({
            'user_id': user.id,
            'online_at': DateTime.now().toIso8601String(),
            'user_type': 'user',
          });
        } else if (error != null) {
          debugPrint('[PresenceService] ✗ Presence subscription error: $error');
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
    } catch (e) {
      debugPrint('[PresenceService] Error updating last seen: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (SupabaseService.isLoggedIn) {
          _setupPresence();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateLastSeen();
        _cleanupPresence();
        break;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPresence();
    super.onClose();
  }
}
