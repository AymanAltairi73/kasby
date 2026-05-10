import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message_model.dart';

class ChatStorageService {
  static const String _chatHistoryKey = 'chat_history';
  static const String _unreadCountKey = 'unread_count';

  Future<void> saveMessages(List<ChatMessageModel> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((msg) => msg.toJson()).toList();
    await prefs.setString(_chatHistoryKey, jsonEncode(jsonList));
  }

  Future<List<ChatMessageModel>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_chatHistoryKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ChatMessageModel.fromJson(json)).toList();
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
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
  }

  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_unreadCountKey) ?? 0;
  }

  Future<void> clearUnreadCount() async {
    await setUnreadCount(0);
  }
}
