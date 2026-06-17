import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Security Center (audit C10 — MVP).
///
/// Surfaces an account-health score, biometric login + auto-lock preferences,
/// and recent login activity. Biometric preference persists in
/// [SharedPreferences]; auto-lock is enforced by [SessionService].
class SecurityCenterView extends StatefulWidget {
  const SecurityCenterView({super.key});

  @override
  State<SecurityCenterView> createState() => _SecurityCenterViewState();
}

class _SecurityCenterViewState extends State<SecurityCenterView> {
  static const _biometricKey = 'security_biometric_enabled';
  bool _biometricEnabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool(_biometricKey) ?? true;
      _loaded = true;
    });
  }

  Future<void> _setBiometric(bool value) async {
    setState(() => _biometricEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = SupabaseService.currentUser;
    final emailVerified = user?.emailConfirmedAt != null;
    final kycVerified = HomeController.to.kycStatus == 'verified';

    // Account health score: KYC + email + biometric.
    final steps = <bool>[kycVerified, emailVerified, _biometricEnabled];
    final completed = steps.where((s) => s).length;
    final healthPct = (completed / steps.length);

    return Scaffold(
      appBar: AppBar(title: Text('security_center'.tr)),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(color: AppColors.darkGold))
          : ListView(
              padding: const EdgeInsets.all(KasbySpacing.xl),
              children: [
                _buildHealthCard(isDark, healthPct, completed, steps.length),
                const SizedBox(height: KasbySpacing.xl),
                Text(
                  'account_health'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: KasbySpacing.md),
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
                const SizedBox(height: KasbySpacing.xl),
                Text(
                  'security_center'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: KasbySpacing.md),
                _buildToggleTile(
                  isDark,
                  Icons.fingerprint_rounded,
                  'biometric_login'.tr,
                  'biometric_login_desc'.tr,
                  _biometricEnabled,
                  _setBiometric,
                ),
                _buildInfoTile(
                  isDark,
                  Icons.lock_clock_rounded,
                  'auto_lock'.tr,
                  '${'auto_lock_desc'.tr} (${SessionService.lockTimeout} min)',
                ),
                const SizedBox(height: KasbySpacing.xl),
                Text(
                  'login_activity'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: KasbySpacing.md),
                _buildInfoTile(
                  isDark,
                  Icons.devices_rounded,
                  'active_sessions'.tr,
                  user?.lastSignInAt != null
                      ? DateHelper.dateTime(
                          DateTime.tryParse(user!.lastSignInAt!))
                      : '--',
                ),
              ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: color, size: 28),
              const SizedBox(width: KasbySpacing.md),
              Expanded(
                child: Text(
                  'account_health'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
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

  Widget _buildCheckRow(IconData icon, String title, bool done,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.darkGold),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Icon(
        done ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: done ? AppColors.softGreen : AppColors.darkGold,
      ),
      onTap: onTap,
    );
  }

  Widget _buildToggleTile(bool isDark, IconData icon, String title,
      String subtitle, bool value, ValueChanged<bool> onChanged) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGold),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.darkGold,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
      bool isDark, IconData icon, String title, String subtitle) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: KasbySpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGold),
          const SizedBox(width: KasbySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
