import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/legal/kasby_legal_content.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalView extends StatefulWidget {
  const LegalView({super.key});

  @override
  State<LegalView> createState() => _LegalViewState();
}

class _LegalViewState extends State<LegalView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final initialTab = args['initialTab'] is int
        ? args['initialTab'] as int
        : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = Get.locale?.languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('legal_terms'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.darkGold,
          labelColor: AppColors.darkGold,
          unselectedLabelColor: isDark
              ? AppColors.textSecondary
              : AppColors.textSecondaryLight,
          tabs: [
            Tab(text: 'terms_conditions'.tr),
            Tab(text: 'privacy_policy'.tr),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'open_in_browser'.tr,
            onPressed: () async {
              final isTerms = _tabController.index == 0;
              final url = isTerms
                  ? KasbyLegalContent.termsOfServiceUrl
                  : KasbyLegalContent.privacyPolicyUrl;
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LegalDocumentBody(
            intro: 'terms_intro'.tr,
            body: KasbyLegalContent.termsForLocale(languageCode),
            isDark: isDark,
          ),
          _LegalDocumentBody(
            intro: 'privacy_intro'.tr,
            body: KasbyLegalContent.privacyForLocale(languageCode),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentBody extends StatelessWidget {
  final String intro;
  final String body;
  final bool isDark;

  const _LegalDocumentBody({
    required this.intro,
    required this.body,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intro,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            body,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
              height: 1.8,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
