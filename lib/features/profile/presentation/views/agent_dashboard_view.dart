import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/agent_status_badge.dart';
import 'package:kasby/features/profile/presentation/controllers/agent_controller.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/utils/sla_formatter.dart';
// import 'package:kasby/routes/app_routes.dart';

class AgentDashboardView extends StatefulWidget {
  const AgentDashboardView({super.key});

  @override
  State<AgentDashboardView> createState() => _AgentDashboardViewState();
}

class _AgentDashboardViewState extends State<AgentDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _summaryExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final controller = Get.find<AgentController>();
        controller.setStatusFilter(
          AgentTransactionFilter.values[_tabController.index],
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AgentController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('agent_dashboard'.tr),
        centerTitle: true,
        actions: [
          Obx(() {
            final online =
                controller.agentProfile.value?.isAvailableNow ?? false;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AgentStatusBadge(isOnline: online, compact: true),
                  Switch.adaptive(
                    value: online,
                    activeThumbColor: AppColors.softGreen,
                    onChanged: controller.isLoading.value
                        ? null
                        : (_) => controller.toggleAvailability(),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            if (controller.pendingCount.value > 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Badge(
                  label: Text('${controller.pendingCount.value}'),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 22,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          // IconButton(
          //   onPressed: () => Get.toNamed(Routes.notifications),
          //   icon: const Icon(Icons.history_rounded),
          //   tooltip: 'notification_history'.tr,
          // ),
          IconButton(
            onPressed: () => controller.refreshData(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'refresh'.tr,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'tab_pending'.tr),
            Tab(text: 'tab_approved'.tr),
            Tab(text: 'tab_rejected'.tr),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.agentRecordMissing.value) {
          return _buildMissingProfile();
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshData(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!controller.isOnline) _buildOfflineBanner(),
                      if (!controller.isOnline) const SizedBox(height: 8),
                      _buildCompactSummary(controller),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'search_transactions_hint'.tr,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: controller.search,
                      ),
                      const SizedBox(height: 8),
                      _buildTypeFilters(controller),
                    ],
                  ),
                ),
              ),
              if (controller.isLoading.value && controller.operations.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.operations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _emptyMessage(controller),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == controller.operations.length) {
                        if (controller.operations.length <
                            controller.totalCount.value) {
                          controller.loadNextPage();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox(height: 40);
                      }
                      final tx = controller.operations[index];
                      return _buildOperationCard(
                        context,
                        tx,
                        controller,
                        isDark,
                      );
                    }, childCount: controller.operations.length + 1),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  String _emptyMessage(AgentController controller) {
    switch (controller.statusFilter.value) {
      case AgentTransactionFilter.pending:
        return 'no_pending_operations'.tr;
      case AgentTransactionFilter.approved:
        return 'no_approved_operations'.tr;
      case AgentTransactionFilter.rejected:
        return 'no_rejected_operations'.tr;
    }
  }

  String _transactionTypeLabel(String type) {
    switch (type) {
      case 'deposit':
        return 'deposit'.tr;
      case 'withdrawal':
        return 'withdrawal'.tr;
      default:
        return type.tr;
    }
  }

  Widget _buildCompactSummary(AgentController controller) {
    final profile = controller.agentProfile.value;
    if (profile == null) return const SizedBox.shrink();

    return Obx(() {
      final expanded = _summaryExpanded.value;
      return KasbyCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () => _summaryExpanded.value = !expanded,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${'agent_performance'.tr} · ${CurrencyController.to.formatToUSD(profile.totalCommissionEarned)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.isOnline) _buildLiveIndicator(controller),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _buildCompactPerformance(controller, profile),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCompactPerformance(AgentController controller, dynamic profile) {
    final s = controller.performanceStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _miniMetric(
                'escrow_balance'.tr,
                CurrencyController.to.formatToUSD(profile.escrowBalance),
                AppColors.darkGold,
              ),
              _miniMetric(
                'available_cash'.tr,
                CurrencyController.to.formatToUSD(profile.availableCash),
                Colors.blue,
              ),
              _miniMetric(
                'success_rate'.tr,
                '${profile.successRate.toStringAsFixed(0)}%',
                Colors.orange,
              ),
              if (s.isNotEmpty) ...[
                _miniMetric(
                  'today_deposits'.tr,
                  '${s['today_deposits'] ?? 0}',
                  AppColors.softGreen,
                ),
                _miniMetric(
                  'today_withdrawals'.tr,
                  '${s['today_withdrawals'] ?? 0}',
                  AppColors.darkGold,
                ),
                _miniMetric(
                  'approval_rate'.tr,
                  '${s['approval_rate'] ?? 0}%',
                  AppColors.darkGold,
                ),
                _miniMetric(
                  'commission_today'.tr,
                  CurrencyController.to.formatToUSD(
                    (s['commission_today'] as num?)?.toDouble() ?? 0,
                  ),
                  AppColors.softGreen,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      width: 118,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'agent_offline_banner'.tr,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'agent_profile_not_linked'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'agent_profile_not_linked_hint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilters(AgentController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all'.tr, 'all', controller),
          _filterChip('deposit'.tr, 'deposit', controller),
          _filterChip('withdrawal'.tr, 'withdrawal', controller),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, AgentController controller) {
    final selected = controller.typeFilter.value == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => controller.setTypeFilter(value),
        selectedColor: AppColors.darkGold.withValues(alpha: 0.2),
        checkmarkColor: AppColors.darkGold,
      ),
    );
  }

  Widget _buildOperationCard(
    BuildContext context,
    TransactionModel tx,
    AgentController controller,
    bool isDark,
  ) {
    final isDeposit = tx.type == 'deposit';
    final isPending = tx.status == 'pending' || tx.status == 'processing';
    final slaLevel = isPending && tx.createdAt != null
        ? SlaFormatter.levelFor(tx.createdAt!)
        : null;
    final color = isDeposit ? AppColors.softGreen : AppColors.darkGold;

    return KasbyCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailsSheet(context, tx, controller),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _transactionTypeLabel(tx.type),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (tx.createdAt != null)
                    Text(
                      DateFormat('MMM dd, HH:mm').format(tx.createdAt!),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              if (isPending && tx.createdAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SlaFormatter.colorFor(
                      slaLevel!,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        slaLevel == SlaLevel.overdue
                            ? Icons.error_outline
                            : slaLevel == SlaLevel.warning
                            ? Icons.schedule
                            : Icons.access_time,
                        size: 14,
                        color: SlaFormatter.colorFor(slaLevel),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        SlaFormatter.waitingLabel(tx.createdAt!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SlaFormatter.colorFor(slaLevel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                CurrencyController.to.formatToUSD(tx.amount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${'reference'.tr}: ${tx.id.substring(0, 8)}…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (tx.rejectionReason != null &&
                  tx.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${'rejection_reason_label'.tr}${tx.rejectionReason}',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: KasbyButton(
                        text: isDeposit
                            ? 'approve_deposit'.tr
                            : 'confirm_payout'.tr,
                        onPressed: () =>
                            _showConfirmDialog(context, tx, controller),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _showRejectDialog(context, tx, controller),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('reject'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveIndicator(AgentController controller) {
    if (!controller.isOnline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.softGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms)
              .then()
              .scaleXY(begin: 1.2, end: 0.8, duration: 1000.ms),
          const SizedBox(width: 4),
          Text(
            'live_updates'.tr,
            style: TextStyle(
              color: AppColors.softGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsSheet(
    BuildContext context,
    TransactionModel tx,
    AgentController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: controller.fetchCustomerDetails(
                userId: tx.userId,
                transactionId: tx.id,
              ),
              builder: (context, snapshot) {
                final customer = snapshot.data;
                final profile = customer?['profile'] as Map<String, dynamic>?;
                final walletBalance = (customer?['wallet_balance'] as num?)
                    ?.toDouble();
                final isLoadingCustomer =
                    snapshot.connectionState == ConnectionState.waiting;

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'transaction_details'.tr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isLoadingCustomer)
                        const Center(child: CircularProgressIndicator())
                      else if (profile != null)
                        _buildCustomerHeader(profile, walletBalance)
                      else
                        _buildCustomerFallback(tx.userId),
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        title: 'request_details'.tr,
                        children: [
                          _detailTile(
                            'requested_amount'.tr,
                            CurrencyController.to.formatToUSD(tx.amount),
                            highlight: true,
                          ),
                          _detailTile(
                            'type'.tr,
                            _transactionTypeLabel(tx.type),
                          ),
                          _detailTile('status'.tr, tx.status.tr),
                          _detailTile('transaction_id'.tr, tx.id),
                          if (tx.createdAt != null)
                            _detailTile(
                              'request_time'.tr,
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(tx.createdAt!),
                            ),
                          if (tx.processedAt != null)
                            _detailTile(
                              'processed_at'.tr,
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(tx.processedAt!),
                            ),
                          if (tx.rejectionReason != null)
                            _detailTile(
                              'rejection_reason'.tr,
                              tx.rejectionReason!,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerHeader(
    Map<String, dynamic> profile,
    double? walletBalance,
  ) {
    final fullName = profile['full_name']?.toString() ?? '—';
    final username = profile['referral_code']?.toString() ?? '—';
    final phone = _maskPhone(profile['phone']?.toString());
    final avatarUrl = profile['avatar_url']?.toString();
    final status = profile['status']?.toString() ?? 'active';
    final kycStatus = profile['kyc_status']?.toString() ?? 'unverified';
    final createdAt = profile['created_at']?.toString();
    final lastSeen = profile['last_seen_at']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: AppColors.darkGold)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailTile('invitation_code'.tr, username),
          _detailTile('phone_number'.tr, phone),
          _detailTile('account_status'.tr, status.tr),
          _detailTile('kyc_status'.tr, kycStatus.tr),
          if (walletBalance != null)
            _detailTile(
              'wallet_balance'.tr,
              CurrencyController.to.formatToUSD(walletBalance),
              highlight: true,
            ),
          if (createdAt != null)
            _detailTile(
              'account_created'.tr,
              DateFormat('yyyy-MM-dd').format(DateTime.parse(createdAt)),
            ),
          if (lastSeen != null)
            _detailTile(
              'last_activity'.tr,
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(lastSeen)),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerFallback(String userId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${'user_id'.tr}: $userId',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _detailTile(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                fontSize: highlight ? 16 : 14,
                color: highlight ? AppColors.darkGold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.length < 4) return phone ?? '—';
    final visible = phone.substring(phone.length - 4);
    return '•••• $visible';
  }

  void _showConfirmDialog(
    BuildContext context,
    TransactionModel tx,
    AgentController controller,
  ) {
    final isDeposit = tx.type == 'deposit';
    Get.dialog(
      AlertDialog(
        title: Text(
          isDeposit
              ? 'confirm_deposit_approval'.tr
              : 'confirm_withdrawal_payout'.tr,
        ),
        content: Text(
          isDeposit ? 'confirm_deposit_msg'.tr : 'confirm_payout_msg'.tr,
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              if (isDeposit) {
                controller.approveDeposit(tx.id);
              } else {
                controller.confirmWithdrawal(tx.id);
              }
            },
            child: Text(
              'confirm'.tr,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    TransactionModel tx,
    AgentController controller,
  ) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('reject_operation_title'.tr),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'rejection_reason_hint'.tr,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              controller.rejectTransaction(tx.id, reasonController.text);
            },
            child: Text('reject'.tr, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
