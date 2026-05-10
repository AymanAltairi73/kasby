import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/snack_service.dart';

class QrPaymentController extends GetxController {
  static QrPaymentController get to => Get.find();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxBool isScanning = false.obs;

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }

  void _log(String msg, {bool isError = false}) {
    print('==> [QR_PAYMENT_CONTROLLER] ${isError ? "❌" : "ℹ️"} $msg');
  }

  /// Generates the standard JSON metadata for a user's receive QR
  String generateUserQrData({double? amount, String? type = 'transfer'}) {
    final profile = HomeController.to.profile.value;
    if (profile == null) return '';

    final data = {
      'type': type,
      'user_id': profile.id,
      'referral_code': profile.referralCode,
      'name': profile.fullName,
      if (amount != null && amount > 0) 'amount': amount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(data);
  }

  /// Plays the scan success sound and triggers haptic feedback
  Future<void> playScanFeedback() async {
    try {
      HapticFeedback.heavyImpact();
      await _audioPlayer.play(AssetSource('sounds/scan_success.mp3'));
    } catch (e) {
      _log('Error playing feedback: $e', isError: true);
    }
  }

  /// Parses the scanned QR string and returns a map if valid
  Map<String, dynamic>? parseQrData(String rawData) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawData);
      
      // Basic validation
      if (!data.containsKey('user_id') || !data.containsKey('type')) {
        _log('Invalid QR structure', isError: true);
        return null;
      }

      return data;
    } catch (e) {
      _log('Error parsing QR data: $e', isError: true);
      return null;
    }
  }

  /// Process the scanned data and navigate to transfer
  void handleScanResult(String rawData) async {
    if (isScanning.value) return;
    isScanning.value = true;

    final data = parseQrData(rawData);
    if (data == null) {
      AppSnack.error('invalid_qr'.tr, 'invalid_qr_desc'.tr);
      isScanning.value = false;
      return;
    }

    await playScanFeedback();

    final userId = data['user_id'];
    final referralCode = data['referral_code'] ?? userId;
    final amount = data['amount'];

    // Navigate to transfer view with arguments
    Get.back(); // Close scanner
    
    // We can either navigate to a new flow or update existing TransferView
    // For now, let's assume we navigate to TransferView with arguments
    Get.toNamed('/transfer', arguments: {
      'receiver_id': referralCode,
      'amount': amount?.toString(),
    });

    isScanning.value = false;
  }
}
