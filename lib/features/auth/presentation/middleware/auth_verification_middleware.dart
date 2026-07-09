import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/auth/domain/auth_otp_config.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Blocks access to protected routes until email is verified.
class AuthVerificationMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (AuthOtpConfig.tempSkipEmailVerification) return null;
    if (!Get.isRegistered<AuthController>()) return null;

    final user = SupabaseService.currentUser;
    if (user == null) return null;

    if (!AuthSecurityService.isEmailVerificationRequired(user)) return null;

    final email =
        user.email ?? AuthController.to.pendingVerificationEmail.value ?? '';
    AuthController.to.pendingVerificationEmail.value = email;
    AuthController.to.authStatus.value = AuthStatus.unauthenticated;

    if (Get.currentRoute == Routes.verifyEmail) return null;

    return RouteSettings(
      name: Routes.verifyEmail,
      arguments: {'email': email, 'purpose': 'signup'},
    );
  }
}
