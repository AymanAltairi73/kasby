import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class AgentDetailsView extends StatefulWidget {
  const AgentDetailsView({super.key});

  @override
  State<AgentDetailsView> createState() => _AgentDetailsViewState();
}

class _AgentDetailsViewState extends State<AgentDetailsView> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'AgentDetailsView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
      params: {'hasArgs': Get.arguments != null},
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'AgentDetailsView',
      method: 'dispose',
      feature: 'Wallet',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> agent =
        Get.arguments ??
        {
          'name': 'Agent Name',
          'country': 'iraq'.tr,
          'location': 'enter_city'.tr,
          'rate': '98%',
          'availability_status': 'available',
        };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('authorized_agents'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAgentHeader(context, agent),
            const SizedBox(height: 32),
            _buildAgentStats(agent, context),
            const SizedBox(height: 32),
            _buildContactSection(agent, context),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentHeader(BuildContext context, Map<String, dynamic> agent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Icon(
              Icons.person_rounded,
              size: 60,
              color: AppColors.darkGold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          agent['name'],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${agent['location']}, ${agent['country']}',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(agent['availability_status']).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getStatusText(agent['availability_status']),
            style: TextStyle(
              color: _getStatusColor(agent['availability_status']),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildAgentStats(Map<String, dynamic> agent, BuildContext context) {
    return KasbyCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'verified_agent'.tr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGold,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.verified_rounded,
            color: Colors.blueAccent,
            size: 24,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildContactSection(Map<String, dynamic> agent, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'location'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        const SizedBox(height: 12),
        KasbyCard(
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${agent['location']}, ${agent['country']}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'agent_notes'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        const SizedBox(height: 12),
        KasbyCard(
          color: AppColors.darkGold.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'transfer_time_note'.tr,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                'send_screenshot_note'.tr,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'direct_contact_options'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: KasbyButton(
                text: 'whatsapp'.tr,
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                onPressed: () async {
                  final whatsappUrl = Uri.parse(
                    'https://wa.me/${agent['whatsapp']}',
                  );
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(
                      whatsappUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KasbyButton(
                text: 'telegram'.tr,
                icon: Icons.send_rounded,
                color: const Color(0xFF0088CC),
                onPressed: () async {
                  final telegramUrl = Uri.parse(
                    'https://t.me/${agent['telegram']}',
                  );
                  if (await canLaunchUrl(telegramUrl)) {
                    await launchUrl(
                      telegramUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        KasbyButton(
          text: 'call_now'.tr,
          icon: Icons.phone_forwarded_rounded,
          onPressed: () async {
            final phoneUrl = Uri.parse('tel:${agent['phone']}');
            if (await canLaunchUrl(phoneUrl)) {
              await launchUrl(phoneUrl);
            }
          },
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'available':
        return AppColors.softGreen;
      case 'busy':
        return Colors.orange;
      case 'unavailable':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'available':
        return 'status_available'.tr;
      case 'busy':
        return 'status_busy'.tr;
      case 'unavailable':
        return 'status_unavailable'.tr;
      default:
        return 'status_unavailable'.tr;
    }
  }
}
