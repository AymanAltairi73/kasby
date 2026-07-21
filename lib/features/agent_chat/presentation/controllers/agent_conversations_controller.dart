import 'dart:async';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class AgentConversationsController extends GetxController {
  static AgentConversationsController get to => Get.find();

  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString agentId = RxnString();
  final RxString searchQuery = ''.obs;

  StreamSubscription? _conversationsSubscription;
  Worker? _presenceWorker;
  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    SafeGetx.debugTrace(
      className: 'AgentConversationsController',
      method: 'onInit',
      feature: 'AgentChat',
      status: 'INFO',
    );
    _initialize();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'AgentConversationsController',
      method: 'onClose',
      feature: 'AgentChat',
      status: 'INFO',
    );
    _conversationsSubscription?.cancel();
    _presenceWorker?.dispose();
    _searchWorker?.dispose();
    super.onClose();
  }

  Future<void> _initialize() async {
    isLoading.value = true;
    try {
      final id = await _getAgentId();
      if (id != null) {
        agentId.value = id;
        await fetchConversations(showLoading: false);
        _setupConversationsListener(id);
        _setupPresenceListener();
        _setupSearchListener();
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: '_initialize',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _getAgentId() async {
    try {
      final response = await SupabaseService.client
          .from('agents')
          .select('id')
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();
      if (response != null) {
        return response['id'] as String?;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: '_getAgentId',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
    return null;
  }

  Future<void> fetchConversations({bool showLoading = true}) async {
    final id = agentId.value;
    if (id == null) return;

    if (showLoading) isLoading.value = true;

    try {
      // First fetch conversations without profile join
      final response = await SupabaseService.client
          .from('chat_conversations')
          .select('*')
          .eq('is_agent_chat', true)
          .eq('agent_id', id)
          .order('last_message_at', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'fetchConversations',
        feature: 'AgentChat',
        status: 'DEBUG',
        params: {
          'agent_id': id,
          'conversations_count': list.length,
        },
      );
      
      // Then fetch profiles for each conversation using RPC
      final conversationsWithProfiles = <Map<String, dynamic>>[];
      
      for (final item in list) {
        final conv = Map<String, dynamic>.from(item as Map);
        final convId = conv['id'] as String?;
        
        SafeGetx.debugTrace(
          className: 'AgentConversationsController',
          method: 'fetchConversations',
          feature: 'AgentChat',
          status: 'DEBUG',
          params: {
            'conversation_id': convId,
          },
        );
        
        if (convId != null) {
          try {
            final profileResult = await SupabaseService.client.rpc(
              'get_conversation_profile',
              params: {'p_conversation_id': convId},
            );
            
            SafeGetx.debugTrace(
              className: 'AgentConversationsController',
              method: 'fetchConversations',
              feature: 'AgentChat',
              status: 'DEBUG',
              params: {
                'conversation_id': convId,
                'profile_result': profileResult,
              },
            );
            
            if (profileResult != null && profileResult is List && profileResult.isNotEmpty) {
              final profileData = profileResult[0] as Map<String, dynamic>;
              conv['profiles'] = {
                'full_name': profileData['full_name'],
                'avatar_url': profileData['avatar_url'],
                'updated_at': profileData['last_seen_at'],
                'role': profileData['role'],
                'last_seen_at': profileData['last_seen_at'],
                'referral_code': await _getReferralCode(profileData['user_id']),
              };
            }
          } catch (e) {
            SafeGetx.debugTrace(
              className: 'AgentConversationsController',
              method: 'fetchConversations',
              feature: 'AgentChat',
              status: 'ERROR',
              params: {'conversation_id': convId},
              error: e,
            );
          }
        }
        
        conversationsWithProfiles.add(conv);
      }
      
      conversations.value = conversationsWithProfiles;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'fetchConversations',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  void _setupConversationsListener(String id) {
    _conversationsSubscription?.cancel();
    _conversationsSubscription = SupabaseService.client
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .eq('agent_id', id)
        .order('last_message_at', ascending: false)
        .listen((data) {
          // Filter for agent chats and update conversations list with realtime data
          final List<Map<String, dynamic>> updatedConversations = [];
          
          for (final item in data) {
            final conv = Map<String, dynamic>.from(item as Map);
            
            // Filter only agent chats
            if (conv['is_agent_chat'] != true) continue;
            
            // Preserve profile data from existing conversations
            final existingConv = conversations.firstWhereOrNull((c) => c['id'] == conv['id']);
            if (existingConv != null && existingConv['profiles'] != null) {
              conv['profiles'] = existingConv['profiles'];
            }
            
            updatedConversations.add(conv);
          }
          
          conversations.value = updatedConversations;
        }, onError: (error, stack) {
          SafeGetx.debugTrace(
            className: 'AgentConversationsController',
            method: '_setupConversationsListener',
            feature: 'AgentChat',
            status: 'ERROR',
            error: error,
            stackTrace: stack,
          );
        });
  }

  void _setupPresenceListener() {
    if (!Get.isRegistered<PresenceService>()) return;
    
    final presenceService = Get.find<PresenceService>();
    _presenceWorker = ever(presenceService.onlineUsers, (_) {
      // Trigger UI update when presence changes
      conversations.refresh();
    });
  }

  void _setupSearchListener() {
    _searchWorker = debounce(searchQuery, (_) {
      // Search is handled in the view via filtered list
      conversations.refresh();
    }, time: const Duration(milliseconds: 300));
  }

  List<Map<String, dynamic>> get filteredConversations {
    final query = searchQuery.value.toLowerCase().trim();
    if (query.isEmpty) return conversations.toList();
    
    return conversations.where((conv) {
      final profile = conv['profiles'] as Map<String, dynamic>?;
      if (profile == null) return false;
      
      final fullName = (profile['full_name'] as String? ?? '').toLowerCase();
      final referralCode = (profile['referral_code'] as String? ?? '').toLowerCase();
      
      return fullName.contains(query) || referralCode.contains(query);
    }).toList();
  }

  bool isUserOnline(String userId) {
    if (!Get.isRegistered<PresenceService>()) return false;
    return Get.find<PresenceService>().isUserOnline(userId);
  }

  String? getLastSeen(String userId) {
    if (!Get.isRegistered<PresenceService>()) return null;
    final presenceService = Get.find<PresenceService>();
    return presenceService.getPresenceStatusText(userId);
  }

  String getPresenceStatus(String userId) {
    if (!Get.isRegistered<PresenceService>()) return 'offline';
    final presenceService = Get.find<PresenceService>();
    return presenceService.getPresenceStatus(userId);
  }

  Future<String?> _getReferralCode(String? userId) async {
    if (userId == null) return null;
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('referral_code')
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        return response['referral_code'] as String?;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: '_getReferralCode',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
    return null;
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await SupabaseService.client
          .from('chat_conversations')
          .delete()
          .eq('id', conversationId);
      
      conversations.removeWhere((c) => c['id'] == conversationId);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'deleteConversation',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<bool> pinMessage(String conversationId, String messageId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'pin_message',
        params: {
          'p_conversation_id': conversationId,
          'p_message_id': messageId,
        },
      );
      await fetchConversations(showLoading: false);
      return result as bool? ?? false;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'pinMessage',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<bool> unpinMessage(String conversationId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'unpin_message',
        params: {'p_conversation_id': conversationId},
      );
      await fetchConversations(showLoading: false);
      return result as bool? ?? false;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'unpinMessage',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await SupabaseService.client
          .from('chat_conversations')
          .update({'unread_admin_count': 0})
          .eq('id', conversationId);
      
      // Refresh conversations to update UI
      await fetchConversations(showLoading: false);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentConversationsController',
        method: 'markConversationAsRead',
        feature: 'AgentChat',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
