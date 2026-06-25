import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import '../controllers/marketplace_health_controller.dart';

class MarketplaceHealthView extends StatelessWidget {
  const MarketplaceHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceHealthController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marketplace Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refreshHealth,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Padding(
            padding: EdgeInsets.all(KasbySpacing.md),
            child: KasbyShimmer.card(height: 320),
          );
        }
        if (controller.hasError.value) {
          return ErrorStateWidget(onRetry: controller.refreshHealth);
        }

        final data = controller.healthData.value ?? {};
        final live = (data['dashboard'] as Map?)?['live'] as Map? ?? data;

        return RefreshIndicator(
          onRefresh: controller.refreshHealth,
          child: ListView(
            padding: const EdgeInsets.all(KasbySpacing.md),
            children: [
              _statusCard(
                title: 'Reloadly Status',
                value: live['reloadlyStatus']?.toString() ?? 'unknown',
                icon: Icons.cloud_done_rounded,
                ok: live['reloadlyStatus'] == 'healthy',
              ),
              const SizedBox(height: KasbySpacing.sm),
              _metricCard('OAuth Status', live['oauthStatus']?.toString() ?? '—'),
              _metricCard('OAuth Latency', '${live['oauthLatencyMs'] ?? '—'} ms'),
              _metricCard('API Latency', '${live['apiLatencyMs'] ?? '—'} ms'),
              _metricCard('Catalog Count', '${live['catalogCount'] ?? data['catalogCount'] ?? 0}'),
              _metricCard(
                'Balance',
                live['balanceAmount'] != null
                    ? '${live['balanceAmount']} ${live['balanceCurrency'] ?? ''}'
                    : 'N/A',
              ),
              _metricCard('Environment', live['environment']?.toString() ?? '—'),
              _metricCard(
                'Failed Requests (24h)',
                '${(data['dashboard'] as Map?)?['recentFailures'] is List ? ((data['dashboard'] as Map)['recentFailures'] as List).length : data['failed_requests_24h'] ?? 0}',
              ),
              if (live['oauthError'] != null) ...[
                const SizedBox(height: KasbySpacing.md),
                _errorBanner(live['oauthError'].toString()),
              ],
              if (live['apiError'] != null) ...[
                const SizedBox(height: KasbySpacing.sm),
                _errorBanner(live['apiError'].toString()),
              ],
              const SizedBox(height: KasbySpacing.lg),
              Text(
                'Last checked: ${live['checkedAt'] ?? '—'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required IconData icon,
    required bool ok,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (ok ? AppColors.softGreen : Colors.orange)
              .withValues(alpha: 0.15),
          child: Icon(icon, color: ok ? AppColors.softGreen : Colors.orange),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value.toUpperCase()),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KasbySpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KasbyRadius.card),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}
