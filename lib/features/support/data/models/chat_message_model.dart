import 'package:kasby/core/utils/safe_getx.dart';

enum MessageStatus { sending, sent, delivered, read }

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderType; // user, admin, agent, system
  final String content;
  final String messageType; // text, image, file, voice
  final bool isEdited;
  final bool isDeleted;
  final String? editedText;
  final DateTime? editedAt;
  final List<String> reactions;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? attachmentMetadata;
  final String? replyToId;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    required this.content,
    this.messageType = 'text',
    this.isEdited = false,
    this.isDeleted = false,
    this.editedText,
    this.editedAt,
    this.reactions = const [],
    this.readAt,
    this.deliveredAt,
    this.attachmentMetadata,
    this.replyToId,
    required this.createdAt,
  });

  /// Current delivery status
  MessageStatus get status {
    if (id.startsWith('temp-')) return MessageStatus.sending;
    if (readAt != null) return MessageStatus.read;
    if (deliveredAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  /// Whether this message has been read.
  bool get isRead => readAt != null;

  /// Whether this message was sent by the user (not admin/agent/system).
  bool get isFromUser => senderType == 'user';

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_type': senderType,
      'message_content': content,
      'message_type': messageType,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'edited_text': editedText,
      'edited_at': editedAt?.toIso8601String(),
      'reactions': reactions,
      'read_at': readAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'attachment_metadata': attachmentMetadata,
      'reply_to_id': replyToId,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    try {
      return ChatMessageModel(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String? ?? '',
        senderId: json['sender_id'] as String? ?? '',
        senderType: json['sender_type'] as String? ?? 'user',
        content: (json['message_content'] ?? json['content']) as String? ?? '',
        messageType: json['message_type'] as String? ?? 'text',
        isEdited: json['is_edited'] as bool? ?? false,
        isDeleted: json['is_deleted'] as bool? ?? false,
        editedText: json['edited_text'] as String?,
        editedAt: json['edited_at'] != null
            ? DateTime.parse(json['edited_at'])
            : null,
        reactions:
            (json['reactions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'])
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'])
            : null,
        attachmentMetadata:
            json['attachment_metadata'] as Map<String, dynamic>?,
        replyToId: json['reply_to_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'ChatMessageModel',
        method: 'fromJson',
        feature: 'Support',
        status: 'ERROR',
        params: {'id': json['id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderType,
    String? content,
    String? messageType,
    bool? isEdited,
    bool? isDeleted,
    String? editedText,
    DateTime? editedAt,
    List<String>? reactions,
    DateTime? readAt,
    DateTime? deliveredAt,
    Map<String, dynamic>? attachmentMetadata,
    String? replyToId,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      editedText: editedText ?? this.editedText,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      attachmentMetadata: attachmentMetadata ?? this.attachmentMetadata,
      replyToId: replyToId ?? this.replyToId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
