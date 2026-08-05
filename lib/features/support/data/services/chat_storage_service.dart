import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../models/chat_message_model.dart';

class ChatStorageService {
  static const String _chatHistoryKey = 'chat_history';
  static const String _unreadCountKey = 'unread_count';

  Future<void> saveMessages(List<ChatMessageModel> messages) async {
    final stopwatch = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((msg) => msg.toJson()).toList();
      await prefs.setString(_chatHistoryKey, jsonEncode(jsonList));
      SafeGetx.debugTrace(
        className: 'ChatStorageService',
        method: 'saveMessages',
        feature: 'Support',
        status: 'SUCCESS',
        params: {'count': messages.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'ChatStorageService',
        method: 'saveMessages',
        feature: 'Support',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<ChatMessageModel>> loadMessages() async {
    final stopwatch = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_chatHistoryKey);

      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final messages = jsonList
          .map((json) => ChatMessageModel.fromJson(json))
          .toList();
      SafeGetx.debugTrace(
        className: 'ChatStorageService',
        method: 'loadMessages',
        feature: 'Support',
        status: 'SUCCESS',
        params: {'count': messages.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return messages;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'ChatStorageService',
        method: 'loadMessages',
        feature: 'Support',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
    SafeGetx.debugTrace(
      className: 'ChatStorageService',
      method: 'clearMessages',
      feature: 'Support',
      status: 'SUCCESS',
    );
  }

  Future<List<ChatMessageModel>> searchMessages(String query) async {
    final messages = await loadMessages();
    return messages
        .where(
          (msg) =>
              msg.content.toLowerCase().contains(query.toLowerCase()) &&
              !msg.isDeleted,
        )
        .toList();
  }

  Future<void> setUnreadCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, count);
    SafeGetx.debugTrace(
      className: 'ChatStorageService',
      method: 'setUnreadCount',
      feature: 'Support',
      status: 'SUCCESS',
      params: {'count': count},
    );
  }

  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_unreadCountKey) ?? 0;
    SafeGetx.debugTrace(
      className: 'ChatStorageService',
      method: 'getUnreadCount',
      feature: 'Support',
      status: 'SUCCESS',
      params: {'count': count},
    );
    return count;
  }

  Future<void> clearUnreadCount() async {
    await setUnreadCount(0);
    SafeGetx.debugTrace(
      className: 'ChatStorageService',
      method: 'clearUnreadCount',
      feature: 'Support',
      status: 'SUCCESS',
    );
  }
}
