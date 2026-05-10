import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Fallback to haptic only if sound fails
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> playMessageSentSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/message_sent.mp3'));
      HapticFeedback.lightImpact();
    } catch (e) {
      HapticFeedback.lightImpact();
    }
  }

  void vibrate() {
    HapticFeedback.mediumImpact();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
