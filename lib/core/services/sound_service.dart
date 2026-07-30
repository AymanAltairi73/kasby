import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Sound Service for Kasby User Application.
/// Handles low-latency sound effects, prevents overlap, and enforces user preference.
class SoundService extends GetxService {
  static SoundService get to {
    if (!Get.isRegistered<SoundService>()) {
      Get.put(SoundService(), permanent: true);
    }
    return Get.find<SoundService>();
  }

  static const String _soundPrefKey = 'sound_effects_enabled';

  late AudioPlayer _player;
  final RxBool isSoundEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    _player = AudioPlayer();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isSoundEnabled.value = prefs.getBool(_soundPrefKey) ?? true;
    } catch (e) {
      debugPrint('[SoundService] Error loading sound preference: $e');
    }
  }

  Future<void> toggleSound(bool enabled) async {
    try {
      isSoundEnabled.value = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundPrefKey, enabled);
    } catch (e) {
      debugPrint('[SoundService] Error saving sound preference: $e');
    }
  }

  /// Plays purchase success sound effect.
  Future<void> playPurchase() async {
    if (!isSoundEnabled.value) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/purchase_success.mp3'));
      debugPrint('[SoundService] ✓ Played purchase_success.mp3');
    } catch (e) {
      debugPrint('[SoundService] ✗ Failed playing purchase sound: $e');
    }
  }

  /// Plays general operation success sound effect.
  Future<void> playSuccess() async {
    if (!isSoundEnabled.value) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/success.mp3'));
      debugPrint('[SoundService] ✓ Played success.mp3');
    } catch (e) {
      debugPrint('[SoundService] ✗ Failed playing success sound: $e');
    }
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
