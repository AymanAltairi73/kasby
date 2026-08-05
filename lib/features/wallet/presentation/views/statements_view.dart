import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/statement_service.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

/// Download Statements screen (audit C11). Lets the user pick a period and
/// export a PDF statement of their transactions.
class StatementsView extends StatefulWidget {
  const StatementsView({super.key});

  @override
  State<StatementsView> createState() => _StatementsViewState();
}

class _StatementsViewState extends State<StatementsView> {
  String _period = '30';
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeController.to.fetchAllTransactions(reset: true);
    });
  }

  ({DateTime from, DateTime to}) _range() {
    final now = DateTime.now();
    switch (_period) {
      case '90':
        return (from: now.subtract(const Duration(days: 90)), to: now);
      case 'year':
        return (from: DateTime(now.year, 1, 1), to: now);
      case '30':
      default:
        return (from: now.subtract(const Duration(days: 30)), to: now);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final range = _range();
      final home = HomeController.to;
      await StatementService.generateAndShare(
        accountName: home.profileName,
        accountEmail: home.profileEmail,
        transactions: home.allTransactions.toList(),
        from: range.from,
        to: range.to,
        formatAmount: CurrencyController.to.formatToUSD,
      );
    } catch (e) {
      AppSnack.error('something_went_wrong'.tr, 'couldnt_load_data'.tr);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = <String, String>{
      '30': 'last_30_days'.tr,
      '90': 'last_90_days'.tr,
      'year': 'this_year'.tr,
    };
    return Scaffold(
      appBar: AppBar(title: Text('statements'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(KasbySpacing.xl),
        children: [
          KasbyCard(
            child: Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: AppColors.darkGold,
                  size: 28,
                ),
                const SizedBox(width: KasbySpacing.md),
                Expanded(
                  child: Text(
                    'statements_desc'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KasbySpacing.xl),
          Text(
            'statement_period'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: KasbySpacing.md),
          ...periods.entries.map((e) {
            final selected = _period == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: KasbySpacing.sm),
              child: InkWell(
                borderRadius: KasbyRadius.inputR,
                onTap: () => setState(() => _period = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KasbySpacing.lg,
                    vertical: KasbySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: KasbyRadius.inputR,
                    border: Border.all(
                      color: selected
                          ? AppColors.darkGold
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                    color: selected
                        ? AppColors.darkGold.withValues(alpha: 0.08)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? AppColors.darkGold
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: KasbySpacing.md),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: KasbySpacing.xxl),
          KasbyButton(
            text: 'generate_statement'.tr,
            icon: Icons.picture_as_pdf_rounded,
            isLoading: _generating,
            onPressed: _generating ? null : _generate,
          ),
        ],
      ),
    );
  }
}
