import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playNotificationSound() async {
    try {
      debugPrint('[PROFIT_NOTIFICATION] Sound played for notification');
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      HapticFeedback.mediumImpact();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationService',
        method: 'playNotificationSound',
        feature: 'Core',
        status: 'FAILED',
        error: e,
        stackTrace: stack,
      );
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> playMessageSentSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/message_sent.mp3'));
      HapticFeedback.lightImpact();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'NotificationService',
        method: 'playMessageSentSound',
        feature: 'Core',
        status: 'FAILED',
        error: e,
        stackTrace: stack,
      );
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
