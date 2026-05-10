class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'info', 'success', 'warning', 'critical'
  final String target; // 'all' or specific
  final String? targetUserId;
  final String status; // sent, scheduled, failed, read
  final String? sentBy;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? readAt;

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
  });

  /// Whether this notification has been read.
  bool get isRead => readAt != null || status == 'read';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
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
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'target': target,
      'target_user_id': targetUserId,
      'status': status,
      'sent_by': sentBy,
      'scheduled_at': scheduledAt?.toIso8601String(),
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
    );
  }
}
