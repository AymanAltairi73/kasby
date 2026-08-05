import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/biometric_login_service.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/services/transaction_auth_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Security Center — account health, authentication controls, and activity timeline.
class SecurityCenterView extends StatefulWidget {
  const SecurityCenterView({super.key});

  @override
  State<SecurityCenterView> createState() => _SecurityCenterViewState();
}

class _SecurityCenterViewState extends State<SecurityCenterView> {
  bool _loaded = false;

  SecurityActivityService get _activity => SecurityActivityService.to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _activity.fetchEvents();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _setBiometric(bool value) async {
    if (value) {
      await BiometricLoginService.to.enableAfterLogin(
        AuthController.to.loginIdentifierController.text.trim().isNotEmpty
            ? AuthController.to.loginIdentifierController.text.trim()
            : SupabaseService.currentUser?.email ?? '',
      );
      unawaited(_activity.logEvent(SecurityEventType.biometricEnabled));
    } else {
      await BiometricLoginService.to.disable();
      unawaited(_activity.logEvent(SecurityEventType.biometricDisabled));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = SupabaseService.currentUser;
    final emailVerified = user?.emailConfirmedAt != null;
    final hasPhone = AuthSecurityService.getUserPhone() != null;
    final phoneVerified = hasPhone && user?.phoneConfirmedAt != null;
    final kycVerified = HomeController.to.kycStatus == 'verified';
    final biometricEnabled = BiometricLoginService.to.isEnabled.value;

    final steps = <bool>[
      kycVerified,
      emailVerified,
      phoneVerified,
      biometricEnabled,
    ];
    final completed = steps.where((s) => s).length;
    final healthPct = completed / steps.length;

    return Scaffold(
      appBar: AppBar(title: Text('security_center'.tr)),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(color: AppColors.darkGold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.darkGold,
              child: ListView(
                padding: KasbyLayout.listPadding(context),
                children: [
                  _buildHealthCard(isDark, healthPct, completed, steps.length),
                  const SizedBox(height: KasbySpacing.lg),
                  _sectionTitle('account_health'.tr),
                  _buildCheckRow(
                    Icons.verified_user_outlined,
                    'kyc_verification'.tr,
                    kycVerified,
                    onTap: kycVerified ? null : () => Get.toNamed(Routes.kyc),
                  ),
                  _buildCheckRow(
                    Icons.alternate_email_rounded,
                    'email_address'.tr,
                    emailVerified,
                  ),
                  _buildCheckRow(
                    Icons.phone_android_rounded,
                    'phone_number'.tr,
                    phoneVerified,
                    onTap: phoneVerified
                        ? null
                        : () {
                            final phone = AuthSecurityService.getUserPhone();
                            if (phone != null) {
                              AuthController.to.startPhoneVerification();
                            }
                          },
                  ),
                  const SizedBox(height: KasbySpacing.lg),
                  _sectionTitle('security_settings'.tr),
                  Obx(
                    () => _buildToggleTile(
                      Icons.fingerprint_rounded,
                      'biometric_login'.tr,
                      'biometric_login_desc'.tr,
                      BiometricLoginService.to.isEnabled.value,
                      BiometricLoginService.to.isAvailable.value
                          ? _setBiometric
                          : null,
                    ),
                  ),
                  _buildInfoTile(
                    Icons.lock_clock_rounded,
                    'auto_lock'.tr,
                    '${'auto_lock_desc'.tr} (${SessionService.lockTimeout} min)',
                  ),
                  _buildActionTile(
                    Icons.pin_outlined,
                    'transaction_pin_manage'.tr,
                    'transaction_pin_manage_desc'.tr,
                    onTap: () async {
                      final ok = await TransactionAuthService.to
                          .changeTransactionPin();
                      if (ok) {
                        unawaited(
                          _activity.logEvent(
                            SecurityEventType.transactionPinChange,
                          ),
                        );
                        await _activity.fetchEvents();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  _buildActionTile(
                    Icons.password_rounded,
                    'change_password'.tr,
                    'update_your_security'.tr,
                    onTap: () => Get.toNamed(Routes.changePassword),
                  ),
                  _buildInfoTile(
                    Icons.sms_outlined,
                    'otp_security'.tr,
                    'otp_security_desc'.tr,
                  ),
                  const SizedBox(height: KasbySpacing.lg),
                  _sectionTitle('trusted_device'.tr),
                  _buildDeviceTile(isDark),
                  const SizedBox(height: KasbySpacing.lg),
                  _sectionTitle('login_activity'.tr),
                  Obx(() {
                    if (_activity.isLoading.value && _activity.events.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(KasbySpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_activity.events.isEmpty) {
                      return _buildInfoTile(
                        Icons.history_rounded,
                        'no_security_activity'.tr,
                        'security_activity_will_appear'.tr,
                      );
                    }
                    return Column(
                      children: _activity.events
                          .take(20)
                          .map((e) => _buildActivityTile(e, isDark))
                          .toList(),
                    );
                  }),
                  const SizedBox(height: KasbySpacing.md),
                  Obx(
                    () => _buildInfoTile(
                      Icons.warning_amber_rounded,
                      'failed_login_attempts'.tr,
                      '${_activity.failedLoginCount.value}',
                    ),
                  ),
                  _buildInfoTile(
                    Icons.login_rounded,
                    'last_login'.tr,
                    user?.lastSignInAt != null
                        ? DateHelper.dateTime(
                            DateTime.tryParse(user!.lastSignInAt!),
                          )
                        : '--',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KasbySpacing.sm),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHealthCard(bool isDark, double pct, int done, int total) {
    final color = pct >= 1
        ? AppColors.softGreen
        : pct >= 0.5
        ? AppColors.darkGold
        : AppColors.error;
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      borderRadius: KasbyRadius.card,
      hasShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: color, size: 26),
              const SizedBox(width: KasbySpacing.md),
              Expanded(
                child: Text(
                  'security_status'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(KasbyRadius.chip),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: KasbySpacing.sm),
          Text(
            'account_health_desc'.tr,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> event, bool isDark) {
    final type = event['event_type']?.toString() ?? '';
    final eventStatus = event['status']?.toString() ?? 'success';
    final createdAt = event['created_at']?.toString();
    final deviceName = event['device_name']?.toString() ?? '—';
    final platform = event['platform']?.toString() ?? '—';

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'login':
        icon = Icons.login_rounded;
        iconColor = AppColors.softGreen;
        break;
      case 'logout':
        icon = Icons.logout_rounded;
        iconColor = AppColors.textSecondary;
        break;
      case 'failedLogin':
        icon = Icons.block_rounded;
        iconColor = AppColors.error;
        break;
      case 'passwordChange':
      case 'transactionPinChange':
        icon = Icons.lock_reset_rounded;
        iconColor = AppColors.darkGold;
        break;
      default:
        icon = Icons.security_rounded;
        iconColor = AppColors.darkGold;
    }

    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      padding: const EdgeInsets.all(KasbySpacing.md),
      borderRadius: KasbyRadius.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(KasbySpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: KasbyRadius.chipR,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventLabel(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$deviceName · $platform',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateHelper.dateTime(DateTime.tryParse(createdAt)),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          _statusChip(eventStatus),
        ],
      ),
    );
  }

  String _eventLabel(String type) {
    final key = 'security_event_$type';
    return key.tr != key ? key.tr : type;
  }

  Widget _statusChip(String status) {
    final isFailed = status == 'failed';
    final color = isFailed ? AppColors.error : AppColors.softGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KasbyRadius.chipR,
      ),
      child: Text(
        isFailed ? 'failed'.tr : 'success'.tr,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDeviceTile(bool isDark) {
    final latest = _activity.events.firstWhereOrNull(
      (e) => e['event_type'] == SecurityEventType.deviceRegistration.value,
    );
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.md),
      borderRadius: KasbyRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone_rounded, color: AppColors.darkGold),
              const SizedBox(width: KasbySpacing.md),
              Expanded(
                child: Text(
                  'this_device'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.sm),
          Text(
            latest?['device_name']?.toString() ?? 'current_device'.tr,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            '${'platform'.tr}: ${latest?['platform']?.toString() ?? '—'}',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
    IconData icon,
    String title,
    bool done, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: AppColors.darkGold, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: Icon(
        done ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: done ? AppColors.softGreen : AppColors.darkGold,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: KasbySpacing.md,
        vertical: KasbySpacing.sm,
      ),
      borderRadius: KasbyRadius.card,
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGold, size: 22),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.darkGold,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      padding: const EdgeInsets.all(KasbySpacing.md),
      borderRadius: KasbyRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: KasbyRadius.cardR,
        child: Row(
          children: [
            Icon(icon, color: AppColors.darkGold, size: 22),
            const SizedBox(width: KasbySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      padding: const EdgeInsets.all(KasbySpacing.md),
      borderRadius: KasbyRadius.card,
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGold, size: 22),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
