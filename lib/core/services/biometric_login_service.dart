import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:local_auth/local_auth.dart';

/// Persists last login identifier and offers biometric shortcut on login screen.
class BiometricLoginService extends GetxService {
  static BiometricLoginService get to => Get.find();

  static const _keyEnabled = 'biometric_login_enabled';
  static const _keyLoginId = 'biometric_login_id';

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  final RxBool isAvailable = false.obs;
  final RxBool isEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    _refreshAvailability();
  }

  Future<void> _refreshAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      isAvailable.value = canCheck || supported;
      final enabled = await _storage.read(key: _keyEnabled);
      isEnabled.value = enabled == 'true' && isAvailable.value;
    } catch (_) {
      isAvailable.value = false;
      isEnabled.value = false;
    }
  }

  Future<void> enableAfterLogin(String loginId) async {
    if (!isAvailable.value || loginId.trim().isEmpty) return;
    await _storage.write(key: _keyEnabled, value: 'true');
    await _storage.write(key: _keyLoginId, value: loginId.trim());
    isEnabled.value = true;
  }

  Future<void> disable() async {
    await _storage.delete(key: _keyEnabled);
    isEnabled.value = false;
  }

  Future<String?> savedLoginId() => _storage.read(key: _keyLoginId);

  /// Authenticate with biometrics then sign in using saved identifier + password field.
  Future<bool> attemptBiometricLogin() async {
    if (!isAvailable.value) return false;

    final savedId = await savedLoginId();
    if (savedId == null || savedId.isEmpty) return false;

    final authenticated = await SessionService.to.authenticate();
    if (!authenticated) return false;

    final controller = AuthController.to;
    controller.loginIdentifierController.text = savedId;

    if (controller.passwordController.text.isNotEmpty) {
      await controller.login();
      return controller.isLoggedIn;
    }

    return false;
  }
}
