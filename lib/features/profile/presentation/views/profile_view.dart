import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/directional_chevron.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/controllers/theme_controller.dart';
import '../../../support/presentation/controllers/support_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/account_deletion_service.dart';
import 'package:kasby/core/services/auth_security_service.dart';
import 'package:kasby/core/utils/locale_helper.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/core/tour/widgets/tour_settings_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'ProfileView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
      message: 'Tab mounted in MainShell',
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'ProfileView',
      method: 'dispose',
      feature: 'Profile',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportController = Get.put(SupportController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, supportController, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileSection(context, isDark, [
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.person_outline_rounded,
                      'personal_info'.tr,
                      Colors.blueAccent,
                      () => Get.toNamed(Routes.personalProfile),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.groups_rounded,
                      'my_team'.tr,
                      Colors.cyanAccent,
                      () => Get.toNamed(Routes.myTeam),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.analytics_rounded,
                      'referral_analytics'.tr,
                      Colors.blueAccent,
                      () => Get.toNamed(Routes.referralAnalytics),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.account_balance_wallet_rounded,
                      'earnings_analytics'.tr,
                      Colors.greenAccent,
                      () => Get.toNamed(Routes.earningsAnalytics),
                    ),
                    KeyedSubtree(
                      key: TourTargetKeys.profileSecurity,
                      child: _buildProfileItem(
                        context,
                        isDark,
                        Icons.security_rounded,
                        'security_center'.tr,
                        Colors.redAccent,
                        () => Get.toNamed(Routes.securityCenter),
                      ),
                    ),
                    // C11: Statements entry
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.description_outlined,
                      'statements'.tr,
                      Colors.tealAccent,
                      () => Get.toNamed(Routes.statements),
                    ),
                    // KeyedSubtree(
                    //   key: TourTargetKeys.profilePin,
                    //   child: _buildProfileItem(
                    //   context,
                    //   isDark,
                    //   Icons.lock_outline_rounded,
                    //   'change_password'.tr,
                    //   Colors.purpleAccent,
                    //   () => Get.toNamed(Routes.changePassword),
                    // ),
                    // ),
                    KeyedSubtree(
                      key: TourTargetKeys.profileKyc,
                      child: _buildProfileItem(
                        context,
                        isDark,
                        Icons.verified_user_outlined,
                        'kyc_verification'.tr,
                        AppColors.darkGold,
                        () => Get.toNamed(Routes.kyc),
                        trailing: Obx(() {
                          final kycStatus = HomeController.to.kycStatus;
                          final isVerified = kycStatus == 'verified';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (isVerified
                                            ? AppColors.softGreen
                                            : AppColors.darkGold)
                                        .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              isVerified ? 'verified'.tr : 'not_verified'.tr,
                              style: TextStyle(
                                color: isVerified
                                    ? AppColors.softGreen
                                    : AppColors.darkGold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (AuthController.to.userRole == 'agent' ||
                        AuthController.to.userRole == 'admin')
                      _buildProfileItem(
                        context,
                        isDark,
                        Icons.support_agent_rounded,
                        'agent_dashboard'.tr,
                        AppColors.darkGold,
                        () => Get.toNamed(Routes.agentDashboard),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'agent_pro_badge'.tr,
                            style: TextStyle(
                              color: AppColors.darkGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    KeyedSubtree(
                      key: TourTargetKeys.profileLanguage,
                      child: _buildProfileItem(
                        context,
                        isDark,
                        Icons.language_rounded,
                        'language'.tr,
                        Colors.greenAccent,
                        () => _showLanguageSelector(context, isDark),
                      ),
                    ),

                    _buildThemeToggle(context, isDark),
                  ]),
                  const SizedBox(height: 24),
                  _buildProfileSection(context, isDark, [
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.notifications_none_rounded,
                      'notification_settings'.tr,
                      Colors.orangeAccent,
                      () => Get.toNamed(Routes.notificationPreferences),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.help_outline_rounded,
                      'support_faq'.tr,
                      Colors.cyanAccent,
                      () => Get.toNamed(Routes.support),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.tour_rounded,
                      'app_tour'.tr,
                      Colors.amberAccent,
                      () => TourSettingsSheet.show(context),
                    ),
                    _buildProfileItem(
                      context,
                      isDark,
                      Icons.gavel_rounded,
                      'legal_terms'.tr,
                      Colors.grey,
                      () => Get.toNamed(Routes.legal),
                    ),
                  ]),
                  const SizedBox(height: 48),
                  _buildLogoutButton(),
                  const SizedBox(height: 16),
                  _buildDeleteAccountButton(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    SupportController supportController,
    bool isDark,
  ) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: bgColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.darkGold.withValues(alpha: isDark ? 0.2 : 0.12),
                    bgColor,
                  ],
                ),
              ),
            ),
            // Glowing Orbs
            Positioned(
              top: 40,
              left: -30,
              child: KasbyMotion.enabled(context)
                  ? Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent.withValues(
                              alpha: isDark ? 0.1 : 0.06,
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: const Duration(seconds: 4),
                          begin: const Offset(1, 1),
                          end: const Offset(1.3, 1.3),
                        )
                        .blurXY(begin: 30, end: 60)
                  : const SizedBox.shrink(),
            ),
            // Profile Info Header
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Hero(
                      tag: 'profile_pic',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.darkGold,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkGold.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Obx(() {
                          final profile = HomeController.to.profile.value;
                          final networkUrl = profile?.avatarUrl;

                          return CircleAvatar(
                            radius: 55,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            backgroundImage:
                                networkUrl != null && networkUrl.isNotEmpty
                                ? NetworkImage(networkUrl)
                                : null,
                            child: (networkUrl == null || networkUrl.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    color: AppColors.darkGold,
                                    size: 55,
                                  )
                                : null,
                          );
                        }),
                      ),
                    )
                    .animate(autoPlay: KasbyMotion.enabled(context))
                    .scale(
                      delay: KasbyMotion.duration(context, 200.ms),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 20),
                Obx(
                      () => Text(
                        HomeController.to.profileName.isNotEmpty
                            ? HomeController.to.profileName
                            : 'user_name_placeholder'.tr,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    )
                    .animate(autoPlay: KasbyMotion.enabled(context))
                    .fadeIn(delay: KasbyMotion.duration(context, 400.ms)),
                Obx(
                      () => Text(
                        HomeController.to.profileEmail.isNotEmpty
                            ? HomeController.to.profileEmail
                            : 'user_email_placeholder'.tr,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                    .animate(autoPlay: KasbyMotion.enabled(context))
                    .fadeIn(delay: KasbyMotion.duration(context, 500.ms)),
                const SizedBox(height: 40),
              ],
            ),
            Positioned(
              top: 45,
              left: 15,
              child: Obx(() {
                final unreadCount = supportController.unreadCount;
                return Column(
                  children: [
                    Semantics(
                      button: true,
                      label: 'support_prompt'.tr,
                      child:
                          GestureDetector(
                                onTap: () => Get.toNamed(Routes.supportChat),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.darkGold.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.darkGold,
                                          Color.lerp(
                                            AppColors.darkGold,
                                            Colors.white,
                                            0.4,
                                          )!,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.darkGold.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(
                                          Icons.support_agent_rounded,
                                          color: Colors.black,
                                          size: 28,
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            top: -10,
                                            right: -10,
                                            child:
                                                Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        '$unreadCount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                    .animate(
                                                      onPlay: (c) => c.repeat(),
                                                    )
                                                    .scale(
                                                      duration: 400.ms,
                                                      begin: const Offset(1, 1),
                                                      end: const Offset(
                                                        1.2,
                                                        1.2,
                                                      ),
                                                    )
                                                    .then()
                                                    .scale(
                                                      duration: 400.ms,
                                                      begin: const Offset(
                                                        1.2,
                                                        1.2,
                                                      ),
                                                      end: const Offset(1, 1),
                                                    ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .animate(
                                autoPlay: KasbyMotion.enabled(context),
                                onPlay: (c) => c.repeat(reverse: true),
                              )
                              .scale(
                                duration: KasbyMotion.duration(
                                  context,
                                  2000.ms,
                                ),
                                begin: const Offset(1, 1),
                                end: const Offset(1.1, 1.1),
                              )
                              .animate(
                                autoPlay: KasbyMotion.enabled(context),
                                onPlay: (c) => c.repeat(),
                              )
                              .shimmer(
                                duration: KasbyMotion.duration(
                                  context,
                                  3000.ms,
                                ),
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                          'support_prompt'.tr,
                          style: TextStyle(
                            color: AppColors.darkGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        )
                        .animate(
                          autoPlay: KasbyMotion.enabled(context),
                          onPlay: (c) => c.repeat(),
                        )
                        .shimmer(
                          duration: KasbyMotion.duration(context, 2000.ms),
                          color: Colors.white,
                        )
                        .animate(
                          autoPlay: KasbyMotion.enabled(context),
                          onPlay: (c) => c.repeat(reverse: true),
                        )
                        .scale(
                          duration: KasbyMotion.duration(context, 1000.ms),
                          begin: const Offset(1, 1),
                          end: const Offset(1.05, 1.05),
                        ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      // leading: IconButton(
      //   icon: Icon(
      //     Icons.arrow_back_ios_new_rounded,
      //     color: Theme.of(context).colorScheme.onSurface,
      //   ),
      //   onPressed: () => ShellController.to.handleBack(),
      // ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surface.withValues(alpha: 0.3)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(children: children),
          ),
        )
        .animate(autoPlay: KasbyMotion.enabled(context))
        .fadeIn()
        .slideY(begin: 0.1);
  }

  Widget _buildProfileItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.1 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing:
              trailing ??
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: DirectionalChevron(
                  size: 12,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return KasbyButton(
          text: 'logout'.tr,
          color: AppColors.error.withValues(alpha: 0.2),
          textColor: AppColors.error,
          onPressed: () {
            if (Get.isRegistered<HomeController>()) {
              HomeController.to.clearData();
            }
            AuthController.to.logout();
          },
        )
        .animate(autoPlay: KasbyMotion.enabled(context))
        .fadeIn(delay: KasbyMotion.duration(context, 600.ms));
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return TextButton(
      onPressed: () => _showDeleteAccountDialog(context),
      child: Text(
        'delete_account'.tr,
        style: TextStyle(
          color: AppColors.error.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'delete_account'.tr,
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delete_account_confirm'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'delete_account_final_confirm'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              _showDeleteAccountPasswordDialog(context);
            },
            child: Text(
              'continue'.tr,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var isDeleting = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.surface
                : AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'enter_current_password'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'delete_account_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !isDeleting,
                  decoration: InputDecoration(
                    hintText: 'enter_current_password'.tr,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Get.back(),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        final password = passwordController.text.trim();
                        if (password.isEmpty) {
                          AppSnack.error(
                            'error'.tr,
                            'enter_current_password'.tr,
                          );
                          return;
                        }

                        setState(() => isDeleting = true);
                        try {
                          await _verifyPasswordForDelete(password);
                          await AccountDeletionService.deleteOwnAccount();
                          Get.back();
                          if (Get.isRegistered<HomeController>()) {
                            HomeController.to.clearData();
                          }
                          await AuthController.to.logout();
                          AppSnack.success('success'.tr, 'account_deleted'.tr);
                        } on AuthException catch (e) {
                          setState(() => isDeleting = false);
                          final message =
                              e.message.startsWith('DELETED_ACCOUNT:')
                              ? AuthSecurityService.translateAuthError(e)
                              : 'incorrect_password'.tr;
                          AppSnack.error('error'.tr, message);
                        } catch (e) {
                          setState(() => isDeleting = false);
                          AppSnack.error('error'.tr, e.toString());
                        }
                      },
                child: isDeleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(
                        'delete_account'.tr,
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _verifyPasswordForDelete(String password) async {
    final email = SupabaseService.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      await AuthSecurityService.reauthenticateWithPassword(password);
      return;
    }

    final phone = Get.isRegistered<HomeController>()
        ? HomeController.to.profile.value?.phone
        : null;
    final resolvedPhone = phone ?? AuthSecurityService.getUserPhone();
    if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
      await AuthSecurityService.signInWithIdentifier(
        identifier: resolvedPhone,
        password: password,
      );
      return;
    }

    throw AuthException('cannot_verify_identity'.tr);
  }

  void _showLanguageSelector(BuildContext context, bool isDark) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'select_language'.tr,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.onSurface : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageItem(
              isDark,
              'arabic'.tr,
              'ar',
              'SA',
              Get.locale?.languageCode == 'ar',
            ),
            const SizedBox(height: 12),
            _buildLanguageItem(
              isDark,
              'english'.tr,
              'en',
              'US',
              Get.locale?.languageCode == 'en',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    bool isDark,
    String title,
    String langCode,
    String countryCode,
    bool isSelected,
  ) {
    return Semantics(
      button: true,
      label: title,
      selected: isSelected,
      child: InkWell(
        onTap: () async {
          Get.updateLocale(Locale(langCode, countryCode));
          await LocaleHelper.saveLanguageCode(langCode);
          Get.back();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkGold.withValues(alpha: 0.1)
                : (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.darkGold : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.darkGold
                      : (isDark ? Colors.white70 : AppColors.textBodyLight),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.darkGold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: isDark ? 0.1 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: Colors.amber,
            size: 22,
          ),
        ),
        title: Text(
          'dark_mode'.tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Obx(
          () => Switch(
            value: ThemeController.to.isDark.value,
            onChanged: (_) => ThemeController.to.toggleTheme(),
            activeThumbColor: AppColors.darkGold,
            activeTrackColor: AppColors.darkGold.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
