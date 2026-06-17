import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesView extends StatefulWidget {
  const NotificationPreferencesView({super.key});

  @override
  State<NotificationPreferencesView> createState() =>
      _NotificationPreferencesViewState();
}

class _NotificationPreferencesViewState
    extends State<NotificationPreferencesView> {
  bool _financialEnabled = true;
  bool _securityEnabled = true;
  bool _socialEnabled = true;
  bool _systemEnabled = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'NotificationPreferencesView',
      method: 'initState',
      feature: 'Notifications',
      status: 'INFO',
    );
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _financialEnabled = prefs.getBool('notif_financial') ?? true;
      _securityEnabled = prefs.getBool('notif_security') ?? true;
      _socialEnabled = prefs.getBool('notif_social') ?? true;
      _systemEnabled = prefs.getBool('notif_system') ?? true;
      _quietHoursEnabled = prefs.getBool('notif_quiet_hours') ?? false;
      _quietStart = TimeOfDay(
        hour: prefs.getInt('notif_quiet_start_h') ?? 22,
        minute: prefs.getInt('notif_quiet_start_m') ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour: prefs.getInt('notif_quiet_end_h') ?? 7,
        minute: prefs.getInt('notif_quiet_end_m') ?? 0,
      );
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.darkGold,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
          _savePreference('notif_quiet_start_h', picked.hour);
          _savePreference('notif_quiet_start_m', picked.minute);
        } else {
          _quietEnd = picked;
          _savePreference('notif_quiet_end_h', picked.hour);
          _savePreference('notif_quiet_end_m', picked.minute);
        }
      });
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'notification_preferences'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Global toggle
          _buildSection(
            title: 'notification_settings'.tr,
            children: [
              Obx(() => _buildToggleItem(
                    icon: Icons.notifications_active_rounded,
                    color: AppColors.darkGold,
                    title: 'notification_settings'.tr,
                    value: FCMService.to.isNotificationsEnabled.value,
                    onChanged: (val) =>
                        FCMService.to.setNotificationsEnabled(val),
                  )),
            ],
          ),
          const SizedBox(height: 24),
          // Category toggles
          _buildSection(
            title: 'categories'.tr,
            children: [
              _buildToggleItem(
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.green,
                title: 'category_financial'.tr,
                value: _financialEnabled,
                onChanged: (val) {
                  setState(() => _financialEnabled = val);
                  _savePreference('notif_financial', val);
                },
              ),
              _buildToggleItem(
                icon: Icons.shield_rounded,
                color: Colors.redAccent,
                title: 'category_security'.tr,
                value: _securityEnabled,
                onChanged: (val) {
                  setState(() => _securityEnabled = val);
                  _savePreference('notif_security', val);
                },
              ),
              _buildToggleItem(
                icon: Icons.people_rounded,
                color: Colors.blueAccent,
                title: 'category_social'.tr,
                value: _socialEnabled,
                onChanged: (val) {
                  setState(() => _socialEnabled = val);
                  _savePreference('notif_social', val);
                },
              ),
              _buildToggleItem(
                icon: Icons.settings_rounded,
                color: Colors.grey,
                title: 'category_system'.tr,
                value: _systemEnabled,
                onChanged: (val) {
                  setState(() => _systemEnabled = val);
                  _savePreference('notif_system', val);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quiet hours
          _buildSection(
            title: 'quiet_hours'.tr,
            children: [
              _buildToggleItem(
                icon: Icons.do_not_disturb_on_rounded,
                color: Colors.deepPurple,
                title: 'quiet_hours'.tr,
                subtitle: 'quiet_hours_desc'.tr,
                value: _quietHoursEnabled,
                onChanged: (val) {
                  setState(() => _quietHoursEnabled = val);
                  _savePreference('notif_quiet_hours', val);
                },
              ),
              if (_quietHoursEnabled) ...[
                const SizedBox(height: 8),
                _buildTimePicker(
                  label: 'start_time'.tr,
                  time: _quietStart,
                  onTap: () => _pickTime(isStart: true),
                ),
                const SizedBox(height: 8),
                _buildTimePicker(
                  label: 'end_time'.tr,
                  time: _quietEnd,
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.onSurfaceLight,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
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

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 52),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time.format(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
