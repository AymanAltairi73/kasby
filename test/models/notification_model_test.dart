import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    group('fromJson', () {
      test('parses notification correctly', () {
        final json = {
          'id': 'notif-001',
          'title': 'Test Notification',
          'message': 'This is a test',
          'type': 'success',
          'target': 'specific',
          'target_user_id': 'user-1',
          'status': 'sent',
          'sent_at': '2026-06-09T12:00:00Z',
        };

        final notif = NotificationModel.fromJson(json);

        expect(notif.id, 'notif-001');
        expect(notif.title, 'Test Notification');
        expect(notif.message, 'This is a test');
        expect(notif.type, 'success');
        expect(notif.target, 'specific');
        expect(notif.targetUserId, 'user-1');
        expect(notif.status, 'sent');
      });

      test('handles missing optional fields with defaults', () {
        final json = {
          'id': 'notif-min',
          'title': 'Min Notif',
          'message': 'Minimal',
        };

        final notif = NotificationModel.fromJson(json);

        expect(notif.type, 'info');
        expect(notif.target, 'all');
        expect(notif.status, 'sent');
        expect(notif.targetUserId, isNull);
        expect(notif.sentBy, isNull);
        expect(notif.scheduledAt, isNull);
      });
    });

    group('isRead', () {
      test('returns false for unread notification', () {
        final notif = NotificationModel(
          id: 'n1',
          title: 'Unread',
          message: 'Test',
          status: 'sent',
        );

        expect(notif.isRead, false);
      });

      test('returns true when readAt is set', () {
        final notif = NotificationModel(
          id: 'n2',
          title: 'Read',
          message: 'Test',
          status: 'sent',
          readAt: DateTime(2026, 6, 9),
        );

        expect(notif.isRead, true);
      });

      test('returns true when status is read', () {
        final notif = NotificationModel(
          id: 'n3',
          title: 'Read Status',
          message: 'Test',
          status: 'read',
        );

        expect(notif.isRead, true);
      });
    });

    group('toJson', () {
      test('serializes for broadcast notification', () {
        final notif = NotificationModel(
          id: 'n1',
          title: 'Broadcast',
          message: 'To everyone',
          type: 'info',
          target: 'all',
        );

        final json = notif.toJson();

        expect(json['title'], 'Broadcast');
        expect(json['target'], 'all');
        expect(json['target_user_id'], isNull);
        expect(json.containsKey('id'), isTrue);
      });

      test('serializes for targeted notification', () {
        final notif = NotificationModel(
          id: 'n2',
          title: 'Personal',
          message: 'Just for you',
          type: 'success',
          target: 'specific',
          targetUserId: 'user-42',
        );

        final json = notif.toJson();

        expect(json['target'], 'specific');
        expect(json['target_user_id'], 'user-42');
      });
    });
  });
}
