import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/chat_message_model.dart';

class SupportChatController extends GetxController {
  static SupportChatController get to => Get.find();

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isTyping = false.obs;
  final RxBool isUploading = false.obs;

  List<ChatMessageModel> get filteredMessages {
    if (searchQuery.isEmpty) return messages;
    return messages
        .where((m) =>
            m.content.toLowerCase().contains(searchQuery.value.toLowerCase()) &&
            m.messageType == 'text' &&
            !m.isDeleted)
        .toList();
  }
  final ImagePicker _picker = ImagePicker();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _conversationSubscription;
  String? _conversationId;
  RealtimeChannel? _typingChannel;
  Timer? _typingThrottleTimer;
  final Map<String, Timer> _typingTimers = {};

  @override
  void onInit() {
    super.onInit();
    _initChat();
  }

  @override
  void onClose() {
    _messageSubscription?.cancel();
    _conversationSubscription?.cancel();
    _typingThrottleTimer?.cancel();
    _typingChannel?.unsubscribe();
    for (var t in _typingTimers.values) {
      t.cancel();
    }
    super.onClose();
  }

  Future<void> _initChat() async {
    if (!SupabaseService.isLoggedIn) return;

    isLoading.value = true;
    try {
      // 1. Get or create conversation for the user
      final conversation = await _getOrCreateConversation();
      _conversationId = conversation['id'];

      // 2. Load existing messages
      await _loadMessages();

      // 3. Listen to new messages and conversation changes
      _listenToMessages();
      _listenToConversation();
      _setupTypingBroadcast();
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      Get.snackbar(
        'خطأ في الاتصال',
        'تعذر الاتصال بخوادم الدعم، يرجى المحاولة مرة أخرى لاحقاً.\nالخطأ: $e',
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
    final String lang = Get.locale?.languageCode ?? 'ar';
    
    final response = await SupabaseService.client.rpc(
      'fn_init_support_chat',
      params: {'p_language': lang},
    );

    if (response != null && response['success'] == true) {
      return response['conversation'];
    }

    throw Exception('Failed to initialize support chat');
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    // Use consolidated chat_messages table (same as admin app)
    final response = await SupabaseService.client
        .from('chat_messages')
        .select()
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true);

    messages.value = (response as List)
        .map((json) => ChatMessageModel.fromJson(json))
        .toList();

    _markAllRead();
  }

  void _listenToMessages() {
    if (_conversationId == null) return;

    _messageSubscription = SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true)
        .listen((data) {
          final newList = data
              .map((json) => ChatMessageModel.fromJson(json))
              .toList();

          // Check for new messages from support to play sound
          if (newList.length > messages.length) {
            final latest = newList.last;
            if (latest.senderType != 'user') {
              NotificationService().playNotificationSound();
            }
          }

          messages.value = newList;
          _markAllRead();
        }, onError: (error) {
          debugPrint('Chat message stream error: $error');
        });
  }

  void _listenToConversation() {
    if (_conversationId == null) return;

    _conversationSubscription = SupabaseService.client
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .eq('id', _conversationId!)
        .listen((data) {
          if (data.isNotEmpty) {
            // chat_conversations does not have is_admin_typing column
            // Typing indicator can be added later if needed
            isTyping.value = false;
          }
        }, onError: (error) {
          debugPrint('Chat conversation stream error: $error');
        });
  }

  void reconnectStreams() {
    _messageSubscription?.cancel();
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

    final optimisticMessage = ChatMessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId!,
      senderId: SupabaseService.userId!,
      senderType: 'user',
      content: content.trim(),
      messageType: type,
      createdAt: DateTime.now(),
      readAt: DateTime.now(),
    );

    // 1. Optimistic Update
    messages.add(optimisticMessage);
    NotificationService().playMessageSentSound();

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
      });

      // 3. Update last_message on conversation
      await SupabaseService.client
          .from('chat_conversations')
          .update({
            'last_message': type == 'image' ? '📷 صورة' : content.trim(),
            'last_message_at': DateTime.now().toIso8601String(),
            'unread_admin_count': 1,
          })
          .eq('id', _conversationId!);
    } catch (e) {
      debugPrint('Error sending message: $e');
      // 4. Rollback Optimistic Update
      messages.removeWhere((m) => m.id == optimisticMessage.id);
      Get.snackbar('خطأ', 'تعذر إرسال الرسالة، يرجى المحاولة مرة أخرى.');
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compressing for better performance
        maxWidth: 1200,
      );

      if (image == null) return;

      isUploading.value = true;
      final File file = File(image.path);
      
      final String? imageUrl = await _uploadImage(file);
      
      if (imageUrl != null) {
        await sendMessage(imageUrl, type: 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      Get.snackbar('خطأ', 'تعذر التقاط الصورة');
    } finally {
      isUploading.value = false;
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'support/${SupabaseService.userId}/$fileName';

      // Verify bucket exists first or just try upload with more detail
      debugPrint('Attempting to upload to bucket: chat_attachments');
      
      await SupabaseService.client.storage
          .from('chat_attachments')
          .upload(path, file);

      final String publicUrl = SupabaseService.client.storage
          .from('chat_attachments')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      
      // Additional diagnostic: List buckets to see what's available
      try {
        final buckets = await SupabaseService.client.storage.listBuckets();
        debugPrint('Available buckets: ${buckets.map((b) => b.name).toList()}');
      } catch (listError) {
        debugPrint('Could not list buckets: $listError');
      }

      Get.snackbar(
        'خطأ في الرفع', 
        'تعذر رفع الصورة. تأكد من وجود الحاوية "chat_attachments" في Supabase وإعدادات الوصول (Policies).',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  Future<void> _markAllRead() async {
    if (_conversationId == null) return;

    // Reset user unread count on conversation
    try {
      await SupabaseService.client
          .from('chat_conversations')
          .update({'unread_user_count': 0})
          .eq('id', _conversationId!);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await SupabaseService.client
          .from('chat_messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
      // Realtime listener will handle local update
    } catch (e) {
      debugPrint('Error deleting message: $e');
      Get.snackbar('خطأ', 'تعذر حذف الرسالة');
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
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      Get.snackbar('خطأ', 'تعذر إضافة التفاعل');
    }
  }
}
