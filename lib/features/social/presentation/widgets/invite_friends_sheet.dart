import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteFriendsSheet extends StatelessWidget {
  const InviteFriendsSheet({super.key});

  static Future<void> show() {
    return Get.bottomSheet(
      const InviteFriendsSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  String get _referralCode =>
      HomeController.to.profile.value?.referralCode ?? '';
  String get _referralLink => 'https://kasby.app/join?ref=$_referralCode';
  String get _shareMessage =>
      '${'invite_share_text'.tr} $_referralCode\n$_referralLink';

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppSnack.success('success'.tr, message);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget actionTile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color ?? AppColors.darkGold),
        title: Text(label),
        onTap: () {
          Get.back();
          onTap();
        },
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'invite_friends'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'invite_friends_desc'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          actionTile(
            icon: Icons.link_rounded,
            label: 'copy_referral_link'.tr,
            onTap: () => _copy(_referralLink, 'invite_link_copied'.tr),
          ),
          actionTile(
            icon: Icons.tag_rounded,
            label: 'copy_referral_code'.tr,
            onTap: () => _copy(_referralCode, 'referral_code_copied'.tr),
          ),
          actionTile(
            icon: Icons.share_rounded,
            label: 'share_referral_link'.tr,
            onTap: () =>
                SharePlus.instance.share(ShareParams(text: _shareMessage)),
          ),
          actionTile(
            icon: Icons.code_rounded,
            label: 'share_referral_code'.tr,
            onTap: () => SharePlus.instance.share(
              ShareParams(text: '${'invite_share_text'.tr} $_referralCode'),
            ),
          ),
          const Divider(),
          actionTile(
            icon: Icons.chat_rounded,
            label: 'whatsapp'.tr,
            color: const Color(0xFF25D366),
            onTap: () => _launchUrl(
              'https://wa.me/?text=${Uri.encodeComponent(_shareMessage)}',
            ),
          ),
          actionTile(
            icon: Icons.send_rounded,
            label: 'telegram'.tr,
            color: const Color(0xFF0088CC),
            onTap: () => _launchUrl(
              'https://t.me/share/url?url=${Uri.encodeComponent(_referralLink)}&text=${Uri.encodeComponent('invite_share_text'.tr)}',
            ),
          ),
          actionTile(
            icon: Icons.facebook_rounded,
            label: 'facebook'.tr,
            color: const Color(0xFF1877F2),
            onTap: () => _launchUrl(
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_referralLink)}',
            ),
          ),
          actionTile(
            icon: Icons.alternate_email_rounded,
            label: 'x_twitter'.tr,
            onTap: () => _launchUrl(
              'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareMessage)}',
            ),
          ),
        ],
      ),
    );
  }
}
