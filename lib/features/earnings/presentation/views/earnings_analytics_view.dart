import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/currency_conversion_service.dart';
import 'package:kasby/features/earnings/presentation/controllers/earnings_analytics_controller.dart';
import 'package:kasby/core/models/earnings_analytics_model.dart';
import 'package:kasby/core/localization/model_localization_extensions.dart';

/// Earnings Analytics Screen
/// Enterprise-grade financial analytics dashboard
class EarningsAnalyticsView extends GetView<EarningsAnalyticsController> {
  const EarningsAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('earnings_analytics'.tr), elevation: 0),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: Text('retry'.tr),
                ),
              ],
            ),
          );
        }

        final analytics = controller.analytics.value;
        if (analytics == null || analytics.summary == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'no_earnings_data'.tr,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(context),
                const SizedBox(height: 24),
                _buildStatisticsCards(context, analytics),
                const SizedBox(height: 24),
                _buildSourceBreakdown(context, analytics),
                const SizedBox(height: 24),
                _buildTrendChart(context, analytics),
                const SizedBox(height: 24),
                _buildTimeline(context, analytics),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Obx(() {
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.selectedPeriod.value,
            isExpanded: true,
            items: EarningsAnalyticsController.periods.map((period) {
              return DropdownMenuItem<String>(
                value: period,
                child: Text(controller.getLocalizedPeriodName(period)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                controller.changePeriod(value);
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildStatisticsCards(
    BuildContext context,
    EarningsAnalyticsModel analytics,
  ) {
    final stats = analytics.statistics!;
    final totalUsd = controller.getTotalEarningsUsd();
    final todayUsd = controller.getTodayEarningsUsd();
    final last24hUsd = controller.getLast24hEarningsUsd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              context,
              'total_earnings'.tr,
              CurrencyConversionService.formatUsd(totalUsd),
              Icons.account_balance_wallet,
              Colors.blue,
            ),
            _buildStatCard(
              context,
              'today_earnings'.tr,
              CurrencyConversionService.formatUsd(todayUsd),
              Icons.today,
              Colors.green,
            ),
            _buildStatCard(
              context,
              'last_24h'.tr,
              CurrencyConversionService.formatUsd(last24hUsd),
              Icons.schedule,
              Colors.orange,
            ),
            _buildStatCard(
              context,
              'highest_daily'.tr,
              CurrencyConversionService.formatUsd(
                stats.highestDailyEarningsUsd,
              ),
              Icons.trending_up,
              Colors.purple,
            ),
            _buildStatCard(
              context,
              'average_daily'.tr,
              CurrencyConversionService.formatUsd(
                stats.averageDailyEarningsUsd,
              ),
              Icons.bar_chart,
              Colors.teal,
            ),
            _buildStatCard(
              context,
              'days_in_period'.tr,
              '${stats.daysInPeriod}',
              Icons.calendar_today,
              Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBreakdown(
    BuildContext context,
    EarningsAnalyticsModel analytics,
  ) {
    final breakdown = controller.getBreakdownWithConversion();
    final totalUsd = controller.getTotalEarningsUsd();

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'source_breakdown'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...breakdown.map(
          (item) => _buildBreakdownItem(context, item, totalUsd),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    BreakdownItem item,
    double totalUsd,
  ) {
    final icon = _getSourceIcon(item.source);
    final percentage = item.percentage;
    final totalUsdEquivalent = item.getTotalUsdEquivalent();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.getLocalizedSource(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyConversionService.formatUsd(totalUsdEquivalent),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.amountKsp != null && item.amountKsp! > 0)
                    Text(
                      '(${CurrencyConversionService.formatKsp(item.amountKsp!.toDouble())} KSP)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'investments':
        return Icons.trending_up;
      case 'lucky_wheel':
        return Icons.casino;
      case 'referral_rewards':
        return Icons.people;
      case 'registration_bonuses':
        return Icons.card_giftcard;
      case 'other_rewards':
        return Icons.stars;
      case 'investment_returns':
        return Icons.account_balance;
      default:
        return Icons.attach_money;
    }
  }

  Widget _buildTrendChart(
    BuildContext context,
    EarningsAnalyticsModel analytics,
  ) {
    final chartData = analytics.chartData?.trendChart ?? [];

    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'earnings_trend'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: CustomPaint(
            painter: _TrendChartPainter(
              data: chartData,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    EarningsAnalyticsModel analytics,
  ) {
    final timeline = analytics.timeline;

    if (timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'earnings_timeline'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...timeline.map((item) => _buildTimelineItem(context, item)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, TimelineItem item) {
    final icon = _getSourceIcon(item.source);
    final totalUsd = item.getTotalUsdEquivalent();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.getLocalizedSource(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  item.localizedDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyConversionService.formatUsd(totalUsd),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              if (item.amountKsp != null && item.amountKsp! > 0)
                Text(
                  '(${CurrencyConversionService.formatKsp(item.amountKsp!.toDouble())} KSP)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatDate(item.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'today'.tr;
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr;
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day_ago'.tr : 'days_ago'.tr}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendChartItem> data;
  final Color color;

  _TrendChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = 16.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Find max value for scaling
    final maxValue = data
        .map((e) => e.amountUsd)
        .reduce((a, b) => a > b ? a : b);
    final scale = maxValue > 0 ? chartHeight / maxValue : 1.0;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw line chart
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final pointWidth = chartWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = padding + pointWidth * i;
      final y = padding + chartHeight - (data[i].amountUsd * scale);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = padding + pointWidth * i;
      final y = padding + chartHeight - (data[i].amountUsd * scale);

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
