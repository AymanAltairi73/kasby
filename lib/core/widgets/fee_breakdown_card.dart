import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/fee_service.dart';
import 'package:kasby/core/theme/app_colors.dart';

/// Shows server-authoritative fee preview for wallet operations.
class FeeBreakdownCard extends StatefulWidget {
  const FeeBreakdownCard({
    super.key,
    required this.category,
    required this.amount,
    this.compact = false,
  });

  final String category;
  final double amount;
  final bool compact;

  @override
  State<FeeBreakdownCard> createState() => _FeeBreakdownCardState();
}

class _FeeBreakdownCardState extends State<FeeBreakdownCard> {
  double _fee = 0;
  double _net = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant FeeBreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.amount != widget.amount) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    await FeeService.load();
    final preview = await FeeService.previewFeeFromServer(
      widget.category,
      widget.amount,
    );
    if (mounted) {
      setState(() {
        _fee = preview['fee'] ?? 0;
        _net = preview['net'] ?? widget.amount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rateLabel = FeeService.feeRateLabel(widget.category);
    final lines = FeeService.feeDescriptionLines(widget.category, widget.amount);

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 14),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surface : AppColors.surfaceLight)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'expected_fee'.tr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                _fee > 0 ? '-\$${_fee.toStringAsFixed(2)}' : '\$0.00',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _fee > 0 ? AppColors.error : AppColors.softGreen,
                  fontSize: widget.compact ? 12 : 13,
                ),
              ),
            ],
          ),
          if (rateLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'fee_rate_label'.trParams({'rate': rateLabel}),
              style: TextStyle(
                color: AppColors.darkGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (_fee <= 0) ...[
            const SizedBox(height: 4),
            Text(
              'no_fee_applied'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          if (!widget.compact && lines.isNotEmpty && widget.amount > 0) ...[
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $line',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          if (widget.amount > 0 && _fee > 0) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'net_amount'.tr,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '\$${_net.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.softGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
