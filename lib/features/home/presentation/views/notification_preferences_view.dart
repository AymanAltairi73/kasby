import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/notification_preferences_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/sound_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

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
  bool _isLoading = true;

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
    final financial = await NotificationPreferencesService.isCategoryEnabled(
      'financial',
    );
    final security = await NotificationPreferencesService.isCategoryEnabled(
      'security',
    );
    final social = await NotificationPreferencesService.isCategoryEnabled(
      'social',
    );
    final system = await NotificationPreferencesService.isCategoryEnabled(
      'system',
    );
    final quiet = await NotificationPreferencesService.isQuietHoursEnabled();
    final quietStart = await NotificationPreferencesService.getQuietStart();
    final quietEnd = await NotificationPreferencesService.getQuietEnd();

    if (!mounted) return;
    setState(() {
      _financialEnabled = financial;
      _securityEnabled = security;
      _socialEnabled = social;
      _systemEnabled = system;
      _quietHoursEnabled = quiet;
      _quietStart = quietStart;
      _quietEnd = quietEnd;
      _isLoading = false;
    });
  }

  Future<void> _onGlobalToggle(bool value) async {
    await FCMService.to.setNotificationsEnabled(value);
    AppSnack.success(
      'success'.tr,
      value ? 'notif_enabled_message'.tr : 'notif_disabled_message'.tr,
    );
  }

  Future<void> _onCategoryToggle(String category, bool value) async {
    await NotificationPreferencesService.setCategoryEnabled(category, value);
    setState(() {
      switch (category) {
        case 'financial':
          _financialEnabled = value;
        case 'security':
          _securityEnabled = value;
        case 'social':
          _socialEnabled = value;
        case 'system':
          _systemEnabled = value;
      }
    });
    final label = _categoryLabel(category);
    AppSnack.success(
      'success'.tr,
      value
          ? 'notif_category_enabled'.trParams({'category': label})
          : 'notif_category_disabled'.trParams({'category': label}),
    );
  }

  Future<void> _onQuietHoursToggle(bool value) async {
    await NotificationPreferencesService.setQuietHoursEnabled(value);
    setState(() => _quietHoursEnabled = value);
    AppSnack.success(
      'success'.tr,
      value ? 'notif_quiet_hours_enabled'.tr : 'notif_quiet_hours_disabled'.tr,
    );
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'financial' => 'category_financial'.tr,
      'security' => 'category_security'.tr,
      'social' => 'category_social'.tr,
      'system' => 'category_system'.tr,
      _ => category,
    };
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.darkGold),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
      if (isStart) {
        await NotificationPreferencesService.setQuietHoursStart(
          picked.hour,
          picked.minute,
        );
      } else {
        await NotificationPreferencesService.setQuietHoursEnd(
          picked.hour,
          picked.minute,
        );
      }
      AppSnack.success('success'.tr, 'notif_time_updated'.tr);
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'notification_settings'.tr,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  title: 'notification_settings'.tr,
                  children: [
                    Obx(
                      () => _buildToggleItem(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.darkGold,
                        title: 'notification_settings'.tr,
                        value: FCMService.to.isNotificationsEnabled.value,
                        onChanged: _onGlobalToggle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'المؤثرات الصوتية',
                  children: [
                    Obx(
                      () => _buildToggleItem(
                        icon: SoundService.to.isSoundEnabled.value
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.amber,
                        title: 'المؤثرات الصوتية',
                        subtitle: SoundService.to.isSoundEnabled.value
                            ? 'تشغيل أصوات العمليات والشراء'
                            : 'كتم المؤثرات الصوتية',
                        value: SoundService.to.isSoundEnabled.value,
                        onChanged: (val) => SoundService.to.toggleSound(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'categories'.tr,
                  children: [
                    _buildToggleItem(
                      icon: Icons.account_balance_wallet_rounded,
                      color: Colors.green,
                      title: 'category_financial'.tr,
                      value: _financialEnabled,
                      onChanged: (val) => _onCategoryToggle('financial', val),
                    ),
                    _buildToggleItem(
                      icon: Icons.shield_rounded,
                      color: Colors.redAccent,
                      title: 'category_security'.tr,
                      value: _securityEnabled,
                      onChanged: (val) => _onCategoryToggle('security', val),
                    ),
                    _buildToggleItem(
                      icon: Icons.people_rounded,
                      color: Colors.blueAccent,
                      title: 'category_social'.tr,
                      value: _socialEnabled,
                      onChanged: (val) => _onCategoryToggle('social', val),
                    ),
                    _buildToggleItem(
                      icon: Icons.settings_rounded,
                      color: Colors.grey,
                      title: 'category_system'.tr,
                      value: _systemEnabled,
                      onChanged: (val) => _onCategoryToggle('system', val),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'quiet_hours'.tr,
                  children: [
                    _buildToggleItem(
                      icon: Icons.do_not_disturb_on_rounded,
                      color: Colors.deepPurple,
                      title: 'quiet_hours'.tr,
                      subtitle: 'quiet_hours_desc'.tr,
                      value: _quietHoursEnabled,
                      onChanged: _onQuietHoursToggle,
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
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
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
