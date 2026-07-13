import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/services/financial_repository.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/currency_conversion_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TransactionDetailsView extends StatefulWidget {
  const TransactionDetailsView({super.key});

  @override
  State<TransactionDetailsView> createState() => _TransactionDetailsViewState();
}

class _TransactionDetailsViewState extends State<TransactionDetailsView> {
  TransactionModel? _tx;
  String? _heroTag;
  bool _hasValidArgs = true;
  Map<String, dynamic>? _serverDetails;
  bool _isLoadingDetails = false;
  StreamSubscription<List<Map<String, dynamic>>>? _txSub;

  @override
  void initState() {
    super.initState();
    final dynamic rawArgs = Get.arguments;

    TransactionModel? tx;
    if (rawArgs is Map<String, dynamic>) {
      tx = rawArgs['transaction'] as TransactionModel;
      _tx = tx;
      _heroTag = rawArgs['heroTag'] as String?;
    } else if (rawArgs is TransactionModel) {
      tx = rawArgs;
      _tx = tx;
      _heroTag = null;
    } else {
      _hasValidArgs = false;
      SafeGetx.debugTrace(
        className: 'TransactionDetailsView',
        method: 'initState',
        feature: 'Wallet',
        status: 'FAILED',
        message: 'Invalid transaction arguments',
      );
      return;
    }

    SafeGetx.debugTrace(
      className: 'TransactionDetailsView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
      message: 'Transaction details loaded',
      params: {
        'txId': tx.id.length > 8 ? '${tx.id.substring(0, 8)}...' : tx.id,
        'type': tx.type,
        'status': tx.status,
        'amount': tx.amount,
      },
    );

    _loadServerDetails(tx.id);
    _listenToTransactionUpdates(tx.id);
  }

  @override
  void dispose() {
    _txSub?.cancel();
    super.dispose();
  }

  Future<void> _loadServerDetails(String transactionId) async {
    setState(() => _isLoadingDetails = true);
    final details = await FinancialRepository.fetchTransactionDetails(transactionId);
    if (mounted) {
      setState(() {
        _serverDetails = details;
        _isLoadingDetails = false;
      });
    }
  }

  void _listenToTransactionUpdates(String transactionId) {
    if (!SupabaseService.isLoggedIn) return;
    _txSub = SupabaseService.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('id', transactionId)
        .listen((rows) async {
      if (rows.isEmpty) return;
      await _loadServerDetails(transactionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidArgs) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('couldnt_load_data'.tr)),
      );
    }

    final tx = _tx!;
    final heroTag = _heroTag;
    final currencyController = CurrencyController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOut = tx.isDebit;
    final typeInfo = _getTypeInfo(tx.type);
    final statusInfo = _getStatusInfo(tx.status);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: isDark ? AppColors.surface : Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.grey.shade200)
                      .withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(
                tx,
                currencyController,
                typeInfo,
                statusInfo,
                isOut,
                isDark,
                heroTag,
              ),
            ),
          ),

          // ── Details Body ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status Timeline
                  _buildStatusTimeline(
                    tx,
                    isDark,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),
                  // Details Card
                  _buildDetailsCard(
                    tx,
                    currencyController,
                    isDark,
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),
                  if (_isLoadingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_serverDetails?['counterpart'] != null) ...[
                    const SizedBox(height: 16),
                    _buildPartyCard(
                      title: 'counterparty'.tr,
                      party: Map<String, dynamic>.from(
                        _serverDetails!['counterpart'] as Map,
                      ),
                      isDark: isDark,
                    ),
                  ],
                  if (_serverDetails?['agent'] != null) ...[
                    const SizedBox(height: 16),
                    _buildPartyCard(
                      title: 'deposit_agent'.tr,
                      party: Map<String, dynamic>.from(
                        _serverDetails!['agent'] as Map,
                      ),
                      isDark: isDark,
                      isAgent: true,
                    ),
                  ],
                  if (_serverDetails?['proof_url'] != null &&
                      (_serverDetails!['proof_url'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildProofCard(_serverDetails!['proof_url'] as String, isDark),
                  ],
                  if (tx.description != null && tx.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDescriptionCard(
                      tx,
                      isDark,
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                  if (tx.rejectionReason != null &&
                      tx.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildRejectionCard(
                      tx,
                      isDark,
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                  const SizedBox(height: 24),
                  // Transaction ID (Copyable)
                  _buildTransactionIdCard(
                    tx,
                    isDark,
                  ).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Header ──────────────────────────────────────

  Widget _buildHeroHeader(
    TransactionModel tx,
    CurrencyController currencyController,
    Map<String, dynamic> typeInfo,
    Map<String, dynamic> statusInfo,
    bool isOut,
    bool isDark,
    String? heroTag,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  (typeInfo['color'] as Color).withValues(alpha: 0.15),
                  AppColors.background,
                ]
              : [
                  (typeInfo['color'] as Color).withValues(alpha: 0.08),
                  AppColors.backgroundLight,
                ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Type Icon
            Hero(
              tag: heroTag ?? 'home_tx_${tx.id}',
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (typeInfo['color'] as Color).withValues(alpha: 0.15),
                  border: Border.all(
                    color: (typeInfo['color'] as Color).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  typeInfo['icon'] as IconData,
                  size: 40,
                  color: typeInfo['color'] as Color,
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            // Type Label
            Text(
              typeInfo['label'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            // Amount
            Text(
                  tx.currency == 'KSP' 
                      ? '${isOut ? '-' : '+'}${CurrencyConversionService.formatKsp(tx.amount)} KSP'
                      : '${isOut ? '-' : '+'}${currencyController.formatToUSD(tx.amount)}',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: isOut ? AppColors.error : AppColors.softGreen,
                    letterSpacing: -1,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            if (tx.currency == 'KSP')
              Text(
                CurrencyConversionService.getUsdEquivalentText(tx.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 12),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (statusInfo['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusInfo['icon'] as IconData,
                    size: 16,
                    color: statusInfo['color'] as Color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusInfo['label'] as String,
                    style: TextStyle(
                      color: statusInfo['color'] as Color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  // ── Status Timeline ──────────────────────────────────

  Widget _buildStatusTimeline(TransactionModel tx, bool isDark) {
    final steps = _getTimelineSteps(tx);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: AppColors.darkGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'transaction_timeline'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;
            return _buildTimelineStep(
              step['label'] as String,
              step['isCompleted'] as bool,
              step['isCurrent'] as bool,
              isLast,
              isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(
    String label,
    bool isCompleted,
    bool isCurrent,
    bool isLast,
    bool isDark,
  ) {
    final color = isCompleted
        ? AppColors.softGreen
        : (isCurrent
              ? AppColors.darkGold
              : (isDark ? Colors.white24 : Colors.grey.shade300));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.softGreen
                    : (isCurrent ? AppColors.darkGold : Colors.transparent),
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : (isCurrent
                        ? const Icon(Icons.circle, size: 8, color: Colors.black)
                        : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted
                    ? AppColors.softGreen
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
              color: isCompleted || isCurrent
                  ? (isDark ? Colors.white : AppColors.onSurfaceLight)
                  : (isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ],
    );
  }

  // ── Details Card ─────────────────────────────────────

  Widget _buildDetailsCard(
    TransactionModel tx,
    CurrencyController currencyController,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.darkGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'transaction_details'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            'transaction_type'.tr,
            _getTypeInfo(tx.type)['label'] as String,
            isDark,
          ),
          _buildDivider(isDark),
          _buildDetailRow(
            'transaction_amount'.tr,
            tx.currency == 'KSP' 
                ? '${CurrencyConversionService.formatKsp(tx.amount)} KSP'
                : currencyController.formatToUSD(tx.amount),
            isDark,
          ),
          if (tx.currency == 'KSP') ...[
            _buildDivider(isDark),
            _buildDetailRow(
              'equivalent_usd'.tr,
              CurrencyConversionService.formatUsdFromKsp(tx.amount),
              isDark,
            ),
            _buildDivider(isDark),
            _buildDetailRow(
              'exchange_rate'.tr,
              CurrencyConversionService.getExchangeRateText(),
              isDark,
            ),
          ],
          if (tx.fee > 0) ...[
            _buildDivider(isDark),
            _buildDetailRow(
              'transaction_fee'.tr,
              tx.currency == 'KSP' 
                  ? '${CurrencyConversionService.formatKsp(tx.fee)} KSP'
                  : currencyController.formatToUSD(tx.fee),
              isDark,
            ),
          ],
          if (tx.netAmount != null) ...[
            _buildDivider(isDark),
            _buildDetailRow(
              'net_amount'.tr,
              tx.currency == 'KSP' 
                  ? '${CurrencyConversionService.formatKsp(tx.netAmount!)} KSP'
                  : currencyController.formatToUSD(tx.netAmount!),
              isDark,
              valueColor: AppColors.softGreen,
            ),
          ],
          _buildDivider(isDark),
          _buildDetailRow('currency'.tr, tx.currency, isDark),
          if (tx.runningBalance != null) ...[
            _buildDivider(isDark),
            _buildDetailRow(
              'running_balance'.tr,
              currencyController.formatToUSD(tx.runningBalance!),
              isDark,
            ),
          ],
          _buildDivider(isDark),
          _buildDetailRow(
            'transaction_date'.tr,
            tx.createdAt != null ? DateHelper.dateTime(tx.createdAt) : '—',
            isDark,
          ),
          if (tx.processedAt != null) ...[
            _buildDivider(isDark),
            _buildDetailRow(
              'processed_at'.tr,
              DateHelper.dateTime(tx.processedAt),
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color:
                    valueColor ??
                    (isDark ? Colors.white : AppColors.onSurfaceLight),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade100,
      height: 1,
    );
  }

  // ── Description Card ─────────────────────────────────

  Widget _buildDescriptionCard(TransactionModel tx, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: AppColors.darkGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'description'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tx.description!.tr,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textBodyLight,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Rejection Card ───────────────────────────────────

  Widget _buildRejectionCard(TransactionModel tx, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'rejection_reason'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tx.rejectionReason!,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textBodyLight,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Transaction ID ───────────────────────────────────

  Widget _buildTransactionIdCard(TransactionModel tx, bool isDark) {
    return GestureDetector(
      onTap: () {
        SafeGetx.debugTrace(
          className: 'TransactionDetailsView',
          method: 'copyTransactionId',
          feature: 'Wallet',
          status: 'INFO',
          params: {
            'txId': tx.id.length > 8 ? '${tx.id.substring(0, 8)}...' : tx.id,
          },
        );
        Clipboard.setData(ClipboardData(text: tx.id));
        AppSnack.success(
          'success_copy'.tr,
          '${'transaction_id'.tr}: ${tx.id.substring(0, 8)}...',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkGold.withValues(alpha: 0.08)
              : AppColors.darkGold.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fingerprint_rounded,
              color: AppColors.darkGold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'transaction_id'.tr,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.id,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppColors.textBodyLight,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, color: AppColors.darkGold, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────

  List<Map<String, dynamic>> _getTimelineSteps(TransactionModel tx) {
    final statusOrder = ['pending', 'processing', 'completed'];
    final currentIndex = statusOrder.indexOf(
      tx.status == 'approved' ? 'completed' : tx.status,
    );
    final isRejected =
        tx.status == 'rejected' ||
        tx.status == 'failed' ||
        tx.status == 'cancelled';

    return [
      {
        'label': 'timeline_created'.tr,
        'isCompleted': true,
        'isCurrent': currentIndex == 0 && !isRejected,
      },
      {
        'label': 'timeline_reviewing'.tr,
        'isCompleted': currentIndex >= 1 || isRejected,
        'isCurrent': currentIndex == 1,
      },
      if (isRejected)
        {'label': 'status_rejected'.tr, 'isCompleted': false, 'isCurrent': true}
      else
        {
          'label': 'timeline_success'.tr,
          'isCompleted': currentIndex >= 2,
          'isCurrent': currentIndex == 2,
        },
    ];
  }

  Map<String, dynamic> _getTypeInfo(String type) {
    switch (type) {
      case 'deposit':
        return {
          'icon': Icons.arrow_downward_rounded,
          'color': AppColors.softGreen,
          'label': 'enum_txn_deposit'.tr,
        };
      case 'withdrawal':
        return {
          'icon': Icons.arrow_upward_rounded,
          'color': AppColors.error,
          'label': 'enum_txn_withdrawal'.tr,
        };
      case 'transfer_in':
        return {
          'icon': Icons.call_received_rounded,
          'color': AppColors.softGreen,
          'label': 'enum_txn_transfer_in'.tr,
        };
      case 'transfer_out':
        return {
          'icon': Icons.call_made_rounded,
          'color': AppColors.error,
          'label': 'enum_txn_transfer_out'.tr,
        };
      case 'investment':
        return {
          'icon': Icons.trending_up_rounded,
          'color': const Color(0xFF2196F3),
          'label': 'enum_txn_investment'.tr,
        };
      case 'investment_return':
        return {
          'icon': Icons.assignment_return_rounded,
          'color': AppColors.softGreen,
          'label': 'enum_txn_investment_return'.tr,
        };
      case 'profit':
        return {
          'icon': Icons.auto_awesome_rounded,
          'color': AppColors.darkGold,
          'label': 'enum_txn_profit'.tr,
        };
      case 'reward':
        return {
          'icon': Icons.card_giftcard_rounded,
          'color': const Color(0xFFE91E63),
          'label': 'enum_txn_reward'.tr,
        };
      case 'fee':
        return {
          'icon': Icons.receipt_long_rounded,
          'color': Colors.orange,
          'label': 'enum_txn_fee'.tr,
        };
      case 'loan_disbursement':
        return {
          'icon': Icons.handshake_rounded,
          'color': const Color(0xFF9C27B0),
          'label': 'enum_txn_loan_disbursement'.tr,
        };
      case 'loan_repayment':
        return {
          'icon': Icons.payments_rounded,
          'color': Colors.teal,
          'label': 'enum_txn_loan_repayment'.tr,
        };
      case 'adjustment':
        return {
          'icon': Icons.tune_rounded,
          'color': Colors.blueGrey,
          'label': 'enum_txn_adjustment'.tr,
        };
      case 'admin_credit':
        return {
          'icon': Icons.add_card_rounded,
          'color': AppColors.softGreen,
          'label': 'enum_txn_admin_credit'.tr,
        };
      case 'admin_debit':
        return {
          'icon': Icons.credit_card_off_rounded,
          'color': AppColors.error,
          'label': 'enum_txn_admin_debit'.tr,
        };
      default:
        return {
          'icon': Icons.receipt_rounded,
          'color': AppColors.textSecondary,
          'label': type,
        };
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'completed':
        return {
          'label': 'enum_status_completed'.tr,
          'color': AppColors.softGreen,
          'icon': Icons.check_circle_rounded,
        };
      case 'approved':
        return {
          'label': 'enum_status_approved'.tr,
          'color': AppColors.softGreen,
          'icon': Icons.check_circle_rounded,
        };
      case 'pending':
        return {
          'label': 'enum_status_pending'.tr,
          'color': Colors.orange,
          'icon': Icons.hourglass_empty_rounded,
        };
      case 'processing':
        return {
          'label': 'enum_status_processing'.tr,
          'color': const Color(0xFF2196F3),
          'icon': Icons.sync_rounded,
        };
      case 'rejected':
        return {
          'label': 'enum_status_rejected'.tr,
          'color': AppColors.error,
          'icon': Icons.cancel_rounded,
        };
      case 'failed':
        return {
          'label': 'enum_status_failed'.tr,
          'color': AppColors.error,
          'icon': Icons.cancel_rounded,
        };
      case 'cancelled':
        return {
          'label': 'enum_status_cancelled'.tr,
          'color': AppColors.error,
          'icon': Icons.cancel_rounded,
        };
      default:
        return {
          'label': status,
          'color': AppColors.textSecondary,
          'icon': Icons.info_outline_rounded,
        };
    }
  }

  Widget _buildPartyCard({
    required String title,
    required Map<String, dynamic> party,
    required bool isDark,
    bool isAgent = false,
  }) {
    final name = party['full_name']?.toString() ?? '—';
    final id = party['id']?.toString() ?? party['user_id']?.toString() ?? '';
    final isVerified = party['is_verified'] == true ||
        party['kyc_status']?.toString() == 'verified';
    final avatarUrl = party['avatar_url']?.toString();
    final country = party['country']?.toString();
    final role = party['role']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(name.isNotEmpty ? name[0] : '?')
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.onSurfaceLight,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.softGreen,
                          ),
                        ],
                      ],
                    ),
                    if (id.isNotEmpty)
                      Text(
                        'ID: ${id.length > 8 ? id.substring(0, 8) : id}...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (country != null && country.isNotEmpty)
                      Text(country, style: const TextStyle(fontSize: 12)),
                    if (isAgent || role == 'agent')
                      Chip(
                        label: Text('agent'.tr, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofCard(String proofUrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'proof_image'.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              proofUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                alignment: Alignment.center,
                child: Text('couldnt_load_data'.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
