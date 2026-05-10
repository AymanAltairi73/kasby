import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:flutter/services.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
// import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';

class AllTransactionsView extends StatefulWidget {
  const AllTransactionsView({super.key});

  @override
  State<AllTransactionsView> createState() => _AllTransactionsViewState();
}

class _AllTransactionsViewState extends State<AllTransactionsView> {
  final homeController = HomeController.to;
  final currencyController = CurrencyController.to;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _filters = [
    {
      'key': 'all',
      'label': 'filter_all'.tr,
      'icon': Icons.apps_rounded,
    },
    {
      'key': 'deposit',
      'label': 'filter_deposit'.tr,
      'icon': Icons.arrow_downward_rounded,
    },
    {
      'key': 'withdrawal',
      'label': 'filter_withdrawal'.tr,
      'icon': Icons.arrow_upward_rounded,
    },
    {
      'key': 'transfer_out',
      'label': 'filter_transfer'.tr,
      'icon': Icons.swap_horiz_rounded,
    },
    {
      'key': 'investment',
      'label': 'filter_investment'.tr,
      'icon': Icons.trending_up_rounded,
    },
    {
      'key': 'profit',
      'label': 'filter_profit'.tr,
      'icon': Icons.auto_awesome_rounded,
    },
    {
      'key': 'reward',
      'label': 'filter_reward'.tr,
      'icon': Icons.card_giftcard_rounded,
    },
    {
      'key': 'points',
      'label': 'filter_points'.tr,
      'icon': Icons.stars_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Safety: ensure this runs after the current build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeController.fetchAllTransactions(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      homeController.loadMoreTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'all_transactions'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
        // leading: IconButton(
        //   icon: Icon(
        //     Icons.arrow_back_ios_new_rounded,
        //     color: isDark ? Colors.white : AppColors.onSurfaceLight,
        //   ),
        //   onPressed: () => ShellController.to.handleBack(),
        // ),
      ),
      body: Column(
        children: [
          // ── Filter Chips ────────────────────
          _buildFilterBar(isDark),
          const SizedBox(height: 8),
          // ── Transactions List ───────────────
          Expanded(
            child: Obx(() {
              final transactions = homeController.allTransactions;
              final isLoading = homeController.isLoadingAllTransactions.value;

              if (isLoading && transactions.isEmpty) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: 6,
                  itemBuilder: (_, __) => KasbyShimmer.transactionItem(isDark: isDark),
                );
              }

              if (transactions.isEmpty) {
                return EmptyStateWidget(
                  title: 'no_transactions'.tr,
                  description: 'no_transactions_desc'.tr,
                  icon: Icons.receipt_long_rounded,
                );
              }

              // Group by date
              final grouped = _groupByDate(transactions);

              return RefreshIndicator(
                color: AppColors.darkGold,
                backgroundColor: isDark ? AppColors.surface : Colors.white,
                onRefresh: () =>
                    homeController.fetchAllTransactions(reset: true),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount:
                      grouped.length +
                      (homeController.hasMoreTransactions.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= grouped.length) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: KasbyShimmer.transactionItem(isDark: isDark),
                      );
                    }

                    final group = grouped[index];
                    return _buildDateGroup(
                      group['label'] as String,
                      group['transactions'] as List<TransactionModel>,
                      isDark,
                      index,
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final activeFilter = homeController.selectedFilter.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isActive = activeFilter == filter['key'];
            return GestureDetector(
              onTap: () => homeController.filterTransactions(filter['key']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.darkGold
                      : (isDark ? AppColors.surface : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppColors.darkGold : Colors.transparent,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.darkGold.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isActive
                          ? Colors.black
                          : (isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isActive
                            ? Colors.black
                            : (isDark
                                  ? Colors.white70
                                  : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }


  Widget _buildDateGroup(
    String label,
    List<TransactionModel> transactions,
    bool isDark,
    int groupIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(Icons.person_rounded, color: AppColors.darkGold),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...transactions.asMap().entries.map((entry) {
          return _buildTransactionCard(
            entry.value,
            isDark,
            groupIndex,
            entry.key,
          );
        }),
      ],
    );
  }

  Widget _buildTransactionCard(
    TransactionModel tx,
    bool isDark,
    int groupIndex,
    int itemIndex,
  ) {
    final isOut = tx.isDebit;
    final typeInfo = _getTypeInfo(tx.type);
    final statusInfo = _getStatusInfo(tx.status);

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Get.toNamed(
                Routes.transactionDetails,
                arguments: {
                  'transaction': tx,
                  'heroTag': 'all_tx_${tx.id}_${groupIndex}_${itemIndex}',
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Type Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (typeInfo['color'] as Color).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      typeInfo['icon'] as IconData,
                      color: typeInfo['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Description + Status + Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (tx.description != null && tx.description!.isNotEmpty)
                              ? tx.description!.tr
                              : typeInfo['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (statusInfo['color'] as Color)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusInfo['label'] as String,
                                style: TextStyle(
                                  color: statusInfo['color'] as Color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _formatDate(tx.createdAt),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Amount
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${isOut ? '-' : '+'}${CurrencyController.to.formatToUSD(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isOut ? AppColors.error : AppColors.softGreen,
                            ),
                          ),
                        ),
                        if (tx.fee > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '-${CurrencyController.to.formatToUSD(tx.fee)} ${'fee'.tr}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 60 * itemIndex),
          duration: 400.ms,
        )
        .slideX(begin: 0.05, end: 0);
  }

  // ── Helpers ──────────────────────────────────────────

  List<Map<String, dynamic>> _groupByDate(List<TransactionModel> transactions) {
    final Map<String, List<TransactionModel>> groups = {};
    final now = DateTime.now();

    for (final tx in transactions) {
      String key;
      if (tx.createdAt == null) {
        key = 'other';
      } else {
        final date = tx.createdAt!;
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          key = 'today'.tr;
        } else if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day - 1) {
          key = 'yesterday'.tr;
        } else {
          key = '${date.day}/${date.month}/${date.year}';
        }
      }
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(tx);
    }

    return groups.entries
        .map((e) => {'label': e.key, 'transactions': e.value})
        .toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
        };
      case 'approved':
        return {
          'label': 'enum_status_approved'.tr,
          'color': AppColors.softGreen,
        };
      case 'pending':
        return {'label': 'enum_status_pending'.tr, 'color': Colors.orange};
      case 'processing':
        return {
          'label': 'enum_status_processing'.tr,
          'color': const Color(0xFF2196F3),
        };
      case 'rejected':
        return {'label': 'enum_status_rejected'.tr, 'color': AppColors.error};
      case 'failed':
        return {'label': 'enum_status_failed'.tr, 'color': AppColors.error};
      case 'cancelled':
        return {'label': 'enum_status_cancelled'.tr, 'color': AppColors.error};
      default:
        return {'label': status, 'color': AppColors.textSecondary};
    }
  }
}
