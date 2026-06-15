import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../data/models/chat_message_model.dart';

class SupportChatController extends GetxController {
  static SupportChatController get to => Get.find();

  /// When set, opens a P2P chat with a friend (uses `start_social_chat` RPC).
  final String? friendId;
  final String? friendName;
  
  // Agent Chat Variables
  final String? agentUserId;
  final String? agentName;
  final bool isAgentChat;
  final String? predefinedConversationId;

  SupportChatController({
    this.friendId, 
    this.friendName,
    this.agentUserId,
    this.agentName,
    this.isAgentChat = false,
    this.predefinedConversationId,
  });

  bool get isSocialChat => friendId != null;
  bool get isKasbySupportChat => !isSocialChat && !isAgentChat;
  String get chatTitle {
    if (isAgentChat) return agentName ?? 'kasby_support'.tr;
    if (isSocialChat) return friendName ?? 'chat'.tr;
    return 'kasby_support'.tr;
  }

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isTyping = false.obs;
  final RxBool isUploading = false.obs;
  
  // Presence & Pagination
  final RxBool isRecipientOnline = false.obs;
  final Rxn<DateTime> recipientLastSeen = Rxn<DateTime>();
  static const int _pageSize = 50;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _currentPage = 0;

  final RxList<String> searchResultIds = <String>[].obs;
  final RxInt currentSearchIndex = 0.obs;

  // Reply and Scroll management
  final Rxn<ChatMessageModel> replyMessage = Rxn<ChatMessageModel>();
  final RxBool showScrollToBottom = false.obs;
  final RxInt newIncomingCount = 0.obs;

  void setReplyingTo(ChatMessageModel? message) {
    replyMessage.value = message;
  }

  void clearReply() {
    replyMessage.value = null;
  }

  List<ChatMessageModel> get filteredMessages => messages;

  void searchMessages(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchResultIds.clear();
      currentSearchIndex.value = 0;
      return;
    }
    
    final matches = messages.where((m) => 
      m.messageType == 'text' && 
      !m.isDeleted && 
      m.content.toLowerCase().contains(query.toLowerCase())
    ).map((m) => m.id).toList();
    
    searchResultIds.value = matches;
    currentSearchIndex.value = matches.isNotEmpty ? 0 : -1;
  }

  void nextSearchResult() {
    if (searchResultIds.isEmpty) return;
    if (currentSearchIndex.value < searchResultIds.length - 1) {
      currentSearchIndex.value++;
    } else {
      currentSearchIndex.value = 0; // Wrap around
    }
  }

  void previousSearchResult() {
    if (searchResultIds.isEmpty) return;
    if (currentSearchIndex.value > 0) {
      currentSearchIndex.value--;
    } else {
      currentSearchIndex.value = searchResultIds.length - 1; // Wrap around
    }
  }
  final ImagePicker _picker = ImagePicker();

  RealtimeChannel? _messageChannel;
  StreamSubscription? _conversationSubscription;
  String? _conversationId;
  String? _userLowId;
  String? _assignedAdminId;
  RealtimeChannel? _typingChannel;

  // Edit mode
  final Rxn<ChatMessageModel> editingMessage = Rxn<ChatMessageModel>();

  Timer? _typingThrottleTimer;
  final Map<String, Timer> _typingTimers = {};
  Worker? _presenceWorker;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'SupportChatController',
      method: 'onInit',
      feature: 'Support',
      status: 'INFO',
      params: {
        'isSocialChat': isSocialChat,
        'isAgentChat': isAgentChat,
      },
    );
    super.onInit();
    _initChat();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'SupportChatController',
      method: 'onClose',
      feature: 'Support',
      status: 'INFO',
    );
    _messageChannel?.unsubscribe();
    _conversationSubscription?.cancel();
    _typingThrottleTimer?.cancel();
    _typingChannel?.unsubscribe();
    _presenceWorker?.dispose();
    for (var t in _typingTimers.values) {
      t.cancel();
    }
    super.onClose();
  }

  Future<void> _initChat() async {
    if (!SupabaseService.isLoggedIn) return;

    isLoading.value = true;
    final stopwatch = Stopwatch()..start();
    try {
      // 1. Get or create conversation for the user
      final conversation = await _getOrCreateConversation();
      _conversationId = conversation['id'];

      // 2. Load existing messages
      await _loadMessages();

      // 3. Listen to new messages, conversation changes, and presence
      _listenToMessages();
      _listenToConversation();
      _setupTypingBroadcast();
      _listenToPresence();
      SafeGetx.debugTrace(
        className: 'SupportChatController',
        method: '_initChat',
        feature: 'Support',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SupportChatController',
        method: '_initChat',
        feature: 'Support',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      Get.snackbar(
        'error'.tr,
        'chat_connection_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> _getOrCreateConversation() async {
    if (predefinedConversationId != null) {
      final conv = await SupabaseService.client
          .from('chat_conversations')
          .select()
          .eq('id', predefinedConversationId!)
          .maybeSingle();
      if (conv != null) {
        _applyConversationIds(conv);
        return conv;
      }
      throw Exception('Failed to load conversation');
    }

    if (isSocialChat) {
      final response = await SupabaseService.client.rpc(
        'start_social_chat',
        params: {'p_friend_id': friendId},
      );
      final map = response as Map<String, dynamic>;
      if (map['success'] == true && map['conversation_id'] != null) {
        final convId = map['conversation_id'] as String;
        final conv = await SupabaseService.client
            .from('chat_conversations')
            .select()
            .eq('id', convId)
            .maybeSingle();
        if (conv != null) {
          _applyConversationIds(conv);
          return conv;
        }
      }
      throw Exception(map['error'] ?? 'Failed to start social chat');
    }

    final String lang = Get.locale?.languageCode ?? 'ar';

    final response = await SupabaseService.client.rpc(
      'fn_init_support_chat',
      params: {'p_language': lang},
    );

    if (response != null && response['success'] == true) {
      final conv = response['conversation'] as Map<String, dynamic>;
      _applyConversationIds(conv);
      return conv;
    }

    throw Exception('Failed to initialize support chat');
  }

  void _applyConversationIds(Map<String, dynamic> conv) {
    _userLowId = conv['user_low_id'] as String?;
    _assignedAdminId = conv['assigned_admin_id'] as String?;
  }

  void _listenToPresence() {
    // Determine the recipient ID based on conversation type.
    final targetId = isAgentChat 
        ? agentUserId 
        : (isSocialChat ? friendId : _assignedAdminId);

    if (targetId != null) {
      final presenceService = Get.find<PresenceService>();
      
      // Update initially
      isRecipientOnline.value = presenceService.isUserOnline(targetId);
      if (!isRecipientOnline.value) _fetchRecipientLastSeen(targetId);
      
      // Listen to changes
      _presenceWorker = ever(presenceService.onlineUsers, (_) {
        final isOnline = presenceService.isUserOnline(targetId);
        isRecipientOnline.value = isOnline;
        if (!isOnline) {
          _fetchRecipientLastSeen(targetId);
        }
      });
    }
  }

  Future<void> _fetchRecipientLastSeen(String targetId) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('last_seen_at')
          .eq('id', targetId)
          .maybeSingle();
      
      if (response != null && response['last_seen_at'] != null) {
        recipientLastSeen.value = DateTime.parse(response['last_seen_at']);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: '_fetchRecipientLastSeen', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
    }
  }

  Future<void> loadMoreMessages() async {
    await _loadMessages(loadMore: true);
  }

  Future<void> _loadMessages({bool loadMore = false}) async {
    if (_conversationId == null) return;
    if (loadMore && (!hasMore.value || isLoadingMore.value)) return;

    if (loadMore) {
      isLoadingMore.value = true;
    } else {
      _currentPage = 0;
      hasMore.value = true;
    }

    try {
      final response = await SupabaseService.client
          .from('chat_messages')
          .select()
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      final List<dynamic> data = response;
      final newMessages = data.map((json) => ChatMessageModel.fromJson(json)).toList();

      if (newMessages.length < _pageSize) {
        hasMore.value = false;
      }

      // Reverse to chronological order for the view
      final reversedNew = newMessages.reversed.toList();

      if (loadMore) {
        messages.insertAll(0, reversedNew); // Prepend older messages
      } else {
        messages.value = reversedNew;
      }

      _currentPage++;
      _markAllRead();
      _markMessagesDelivered();
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: '_loadMessages', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshMessages() async {
    await _loadMessages(loadMore: false);
  }

  void _listenToMessages() {
    if (_conversationId == null) return;

    _messageChannel?.unsubscribe();
    _messageChannel = SupabaseService.client
        .channel('chat_messages_$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId!,
          ),
          callback: (payload) {
            final newMsg = ChatMessageModel.fromJson(payload.newRecord);

            // Replace optimistic temp message with the real one
            messages.removeWhere(
              (m) => m.id.startsWith('temp-') && m.content == newMsg.content,
            );

            if (!messages.any((m) => m.id == newMsg.id)) {
              messages.add(newMsg);

              final fromOther = isSocialChat
                  ? newMsg.senderId != SupabaseService.userId
                  : newMsg.senderType != 'user';
              if (fromOther) {
                NotificationService().playNotificationSound();
                if (showScrollToBottom.value) {
                  newIncomingCount.value++;
                }
              }

              _markAllRead();
              _markMessagesDelivered();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId!,
          ),
          callback: (payload) {
            final updated = ChatMessageModel.fromJson(payload.newRecord);
            final index = messages.indexWhere((m) => m.id == updated.id);
            if (index != -1) {
              messages[index] = updated;
            }
          },
        )
        .subscribe();
  }

  void _listenToConversation() {
    if (_conversationId == null) return;

    _conversationSubscription = SupabaseService.client
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .eq('id', _conversationId!)
        .listen((data) {
          if (data.isNotEmpty) {
            isTyping.value = false;
          }
        }, onError: (error, stack) {
          SafeGetx.debugTrace(className: 'SupportChatController', method: '_listenToConversation', feature: 'Support', status: 'ERROR', error: error, stackTrace: stack);
        });
  }

  void reconnectStreams() {
    _messageChannel?.unsubscribe();
    _conversationSubscription?.cancel();
    _listenToMessages();
    _listenToConversation();
  }

  void _setupTypingBroadcast() {
    _typingChannel = SupabaseService.client.channel('chat_typing');

    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final userId = payload['user_id'] as String?;
        final conversationId = payload['conversation_id'] as String?;
        final currentUserId = SupabaseService.userId;

        if (userId != null &&
            conversationId != null &&
            conversationId == _conversationId &&
            userId != currentUserId) {
          _handleIncomingTyping();
        }
      },
    ).subscribe();
  }

  void _handleIncomingTyping() {
    isTyping.value = true;

    // Reset timer to auto-clear typing status after 3 seconds of silence
    _typingTimers['agent']?.cancel();
    _typingTimers['agent'] = Timer(const Duration(seconds: 3), () {
      isTyping.value = false;
    });
  }

  /// Call this whenever the user types
  void sendTypingEvent() {
    if (_conversationId == null) return;
    if (_typingThrottleTimer?.isActive ?? false) return;

    final currentUserId = SupabaseService.userId;
    if (currentUserId == null) return;

    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': currentUserId,
        'conversation_id': _conversationId,
      },
    );

    // Throttle broadcast to once every 2 seconds
    _typingThrottleTimer = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> sendMessage(String content, {String type = 'text'}) async {
    if (content.trim().isEmpty || _conversationId == null) return;

    final String? replyToId = replyMessage.value?.id;

    final optimisticMessage = ChatMessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId!,
      senderId: SupabaseService.userId!,
      senderType: 'user',
      content: content.trim(),
      messageType: type,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      readAt: DateTime.now(),
    );

    // 1. Optimistic Update
    messages.add(optimisticMessage);
    NotificationService().playMessageSentSound();
    
    // Clear reply state immediately
    clearReply();

    try {
      // 2. Insert into consolidated chat_messages table
      final String idempotencyKey = 'msg-${DateTime.now().microsecondsSinceEpoch}-${SupabaseService.userId!.substring(0, 5)}';

      await SupabaseService.client.from('chat_messages').insert({
        'conversation_id': _conversationId,
        'sender_id': SupabaseService.userId,
        'sender_type': 'user',
        'message_content': content.trim(),
        'message_type': type,
        'idempotency_key': idempotencyKey,
        'reply_to_id': replyToId,
      });
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: 'sendMessage', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      // 3. Rollback Optimistic Update
      messages.removeWhere((m) => m.id == optimisticMessage.id);
      Get.snackbar('error'.tr, 'chat_send_error'.tr);
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    if (isClosed) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compressing for better performance
        maxWidth: 1200,
      );

      if (image == null || isClosed) return;

      isUploading.value = true;
      final File file = File(image.path);
      
      final String? imageUrl = await _uploadImage(file);
      
      if (imageUrl != null && !isClosed) {
        await sendMessage(imageUrl, type: 'image');
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: 'pickAndSendImage', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      Get.snackbar('error'.tr, 'chat_capture_error'.tr);
    } finally {
      isUploading.value = false;
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final userId = SupabaseService.userId!;
      final folder = isSocialChat ? 'social' : 'support';
      final String path = '$userId/$folder/$fileName';

      SafeGetx.debugTrace(
        className: 'SupportChatController',
        method: '_uploadImage',
        feature: 'Support',
        status: 'INFO',
        message: 'Uploading chat attachment',
        params: {'path': path},
      );
      
      await SupabaseService.client.storage
          .from('chat_attachments')
          .upload(path, file);

      // Store relative path; UI resolves signed URL at display time.
      return path;
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: '_uploadImage', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      
      Get.snackbar(
        'error'.tr, 
        'chat_upload_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  Map<String, dynamic> _myUnreadClearPayload() {
    final userId = SupabaseService.userId;
    if (isSocialChat && userId != null && _userLowId != null) {
      if (userId == _userLowId) {
        return {'unread_user_count': 0};
      }
      return {'unread_admin_count': 0};
    }
    return {'unread_user_count': 0};
  }

  Future<void> _markAllRead() async {
    if (_conversationId == null) return;

    try {
      await SupabaseService.client
          .from('chat_conversations')
          .update(_myUnreadClearPayload())
          .eq('id', _conversationId!);
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: '_markAllRead', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
    }
  }

  Future<void> _markMessagesDelivered() async {
    if (_conversationId == null) return;
    try {
      await SupabaseService.client.rpc(
        'fn_mark_messages_delivered',
        params: {'p_conversation_id': _conversationId},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: '_markMessagesDelivered', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
    }
  }

  void startEditing(ChatMessageModel message) {
    editingMessage.value = message;
  }

  void cancelEditing() {
    editingMessage.value = null;
  }

  Future<void> updateMessage(String messageId, String newContent) async {
    if (newContent.trim().isEmpty) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = messages[index].copyWith(
        content: newContent.trim(),
        isEdited: true,
        editedAt: DateTime.now(),
      );
    }

    try {
      await SupabaseService.client
          .from('chat_messages')
          .update({
            'message_content': newContent.trim(),
            'is_edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: 'updateMessage', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      await refreshMessages();
      Get.snackbar('error'.tr, 'chat_edit_error'.tr);
    } finally {
      cancelEditing();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await SupabaseService.client
          .from('chat_messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
      // Realtime listener will handle local update
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: 'deleteMessage', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      Get.snackbar('error'.tr, 'chat_delete_error'.tr);
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      final message = messages.firstWhere((m) => m.id == messageId);
      final newReactions = List<String>.from(message.reactions);

      if (newReactions.contains(emoji)) {
        newReactions.remove(emoji);
      } else {
        newReactions.add(emoji);
      }

      await SupabaseService.client
          .from('chat_messages')
          .update({'reactions': newReactions})
          .eq('id', messageId);
      // Realtime listener will handle local update
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'SupportChatController', method: 'addReaction', feature: 'Support', status: 'ERROR', error: e, stackTrace: stack);
      Get.snackbar('error'.tr, 'chat_reaction_error'.tr);
    }
  }
}
