import 'dart:convert';
import 'package:kasby/core/utils/safe_getx.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String target;
  final String? targetUserId;
  final String status;
  final String? sentBy;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final String? deepLink;
  final String? entityType;
  final String? entityId;
  final String? roleTarget;
  final String? titleKey;
  final String? messageKey;
  final Map<String, dynamic>? parameters;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.target = 'all',
    this.targetUserId,
    this.status = 'sent',
    this.sentBy,
    this.scheduledAt,
    this.sentAt,
    this.readAt,
    this.deepLink,
    this.entityType,
    this.entityId,
    this.roleTarget,
    this.titleKey,
    this.messageKey,
    this.parameters,
  });

  bool get isRead => readAt != null || status == 'read';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      Map<String, dynamic>? parsedParams;
      if (json['parameters'] != null) {
        if (json['parameters'] is Map) {
          parsedParams = Map<String, dynamic>.from(json['parameters'] as Map);
        } else if (json['parameters'] is String) {
          try {
            final decoded = jsonDecode(json['parameters'] as String);
            if (decoded is Map) {
              parsedParams = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            parsedParams = null;
          }
        }
      }

      return NotificationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String? ?? 'info',
        target: json['target'] as String? ?? 'all',
        targetUserId: json['target_user_id'] as String?,
        status: json['status'] as String? ?? 'sent',
        sentBy: json['sent_by'] as String?,
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.parse(json['scheduled_at'])
            : null,
        sentAt: json['sent_at'] != null
            ? DateTime.parse(json['sent_at'])
            : null,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'])
            : null,
        deepLink: json['deep_link'] as String?,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
        roleTarget: json['role_target'] as String?,
        titleKey: json['title_key'] as String?,
        messageKey: json['message_key'] as String?,
        parameters: parsedParams,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationModel',
        method: 'fromJson',
        feature: 'Core',
        status: 'ERROR',
        params: {'id': json['id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'target': target,
      'target_user_id': targetUserId,
      'status': status,
      'sent_by': sentBy,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'deep_link': deepLink,
      'entity_type': entityType,
      'entity_id': entityId,
      'role_target': roleTarget,
      'title_key': titleKey,
      'message_key': messageKey,
      'parameters': parameters,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? target,
    String? targetUserId,
    String? status,
    String? sentBy,
    DateTime? scheduledAt,
    DateTime? sentAt,
    DateTime? readAt,
    String? deepLink,
    String? entityType,
    String? entityId,
    String? roleTarget,
    String? titleKey,
    String? messageKey,
    Map<String, dynamic>? parameters,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      target: target ?? this.target,
      targetUserId: targetUserId ?? this.targetUserId,
      status: status ?? this.status,
      sentBy: sentBy ?? this.sentBy,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      deepLink: deepLink ?? this.deepLink,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      roleTarget: roleTarget ?? this.roleTarget,
      titleKey: titleKey ?? this.titleKey,
      messageKey: messageKey ?? this.messageKey,
      parameters: parameters ?? this.parameters,
    );
  }
}

