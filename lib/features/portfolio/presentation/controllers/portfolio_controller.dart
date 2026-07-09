import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

enum PortfolioPeriod { d7, d30, d90, y1, all }

/// Aggregated money movement for the selected analytics period.
class InvestmentFlowSnapshot {
  final double opening;
  final double deposits;
  final double returns;
  final double withdrawals;
  final double investments;
  final double closing;
  final int activeInvestments;
  final int completedInvestments;

  const InvestmentFlowSnapshot({
    required this.opening,
    required this.deposits,
    required this.returns,
    required this.withdrawals,
    required this.investments,
    required this.closing,
    required this.activeInvestments,
    required this.completedInvestments,
  });

  static const empty = InvestmentFlowSnapshot(
    opening: 0,
    deposits: 0,
    returns: 0,
    withdrawals: 0,
    investments: 0,
    closing: 0,
    activeInvestments: 0,
    completedInvestments: 0,
  );

  bool get hasActivity =>
      deposits > 0 || returns > 0 || withdrawals > 0 || investments > 0;

  double get totalInflows => deposits + returns;

  double get totalOutflows => withdrawals + investments;

  double get netChange => closing - opening;
}

class PortfolioController extends GetxController {
  static PortfolioController get to => Get.find();

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final Rx<PortfolioPeriod> selectedPeriod = PortfolioPeriod.d30.obs;

  // Computed metrics
  final RxDouble totalInvested = 0.0.obs;
  final RxDouble totalReturns = 0.0.obs;
  final RxDouble totalPortfolioValue = 0.0.obs;
  final RxDouble roiPercentage = 0.0.obs;
  final RxDouble dailyProfit = 0.0.obs;
  final RxDouble netWorth = 0.0.obs;
  final RxDouble changeFromStart = 0.0.obs;

  // Performance data for sparkline
  final RxList<double> growthData = <double>[].obs;

  // Period performance
  final RxDouble dailyPerformance = 0.0.obs;
  final RxDouble weeklyPerformance = 0.0.obs;
  final RxDouble monthlyPerformance = 0.0.obs;
  final RxDouble yearlyPerformance = 0.0.obs;

  // Investment distribution: planName -> amount
  final RxMap<String, double> distribution = <String, double>{}.obs;

  // Investment flow breakdown for the selected period
  final Rx<InvestmentFlowSnapshot> investmentFlow =
      InvestmentFlowSnapshot.empty.obs;

  // Benchmark comparison: expected vs actual ROI per plan
  final RxList<Map<String, dynamic>> benchmarks = <Map<String, dynamic>>[].obs;

  // Financial insights
  final RxList<String> insights = <String>[].obs;

  HomeController get _home => HomeController.to;

  @override
  void onInit() {
    super.onInit();
    SafeGetx.debugTrace(
      className: 'PortfolioController',
      method: 'onInit',
      feature: 'Portfolio',
      status: 'INFO',
    );
    _computeAll();
    ever(_home.myInvestments, (_) => _computeAll());
    ever(_home.recentTransactions, (_) => _computeAll());
    ever(_home.dashboard, (_) => _computeAll());
    ever(selectedPeriod, (_) {
      _buildGrowthData();
      _buildInvestmentFlow();
    });
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    await _home.refreshAll();
    _computeAll();
  }

  void changePeriod(PortfolioPeriod period) {
    selectedPeriod.value = period;
  }

  void _computeAll() {
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    hasError.value = false;

    try {
      _computeMetrics();
      _computeDistribution();
      _buildGrowthData();
      _buildInvestmentFlow();
      _computePeriodPerformance();
      _generateInsights();
    } catch (e, stack) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'PortfolioController',
        method: '_computeAll',
        feature: 'Portfolio',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
      SafeGetx.debugTrace(
        className: 'PortfolioController',
        method: '_computeAll',
        feature: 'Portfolio',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  void _computeMetrics() {
    final investments = _home.myInvestments;
    final dash = _home.dashboard.value;

    double invested = 0;
    double returns = 0;

    for (final inv in investments) {
      invested += inv.amount;
      returns += (inv.actualProfit ?? inv.expectedProfit);
    }

    totalInvested.value = invested;
    totalReturns.value = returns;
    totalPortfolioValue.value = invested + returns;

    roiPercentage.value = invested > 0 ? (returns / invested) * 100 : 0;
    dailyProfit.value = dash?.dailyProfit ?? 0;

    final available = dash?.availableBalance ?? 0;
    final profit = dash?.profitBalance ?? 0;
    final investedBal = dash?.investedBalance ?? 0;
    netWorth.value = available + profit + investedBal;

    changeFromStart.value = invested > 0 ? returns : 0;

    // Build benchmark data per plan
    final List<Map<String, dynamic>> bench = [];
    for (final inv in investments) {
      final expectedRoi = inv.profitPercentage;
      final actualRoi = inv.amount > 0
          ? ((inv.actualProfit ?? inv.expectedProfit) / inv.amount * 100)
          : 0.0;
      bench.add({
        'planName': inv.investment?.nameEn ?? inv.investment?.nameAr ?? 'Plan',
        'expectedRoi': expectedRoi,
        'actualRoi': actualRoi,
        'amount': inv.amount,
      });
    }
    benchmarks.value = bench;
  }

  void _computeDistribution() {
    final investments = _home.myInvestments;
    final Map<String, double> dist = {};

    for (final inv in investments) {
      final planName = _planDisplayName(inv);
      dist[planName] = (dist[planName] ?? 0) + inv.amount;
    }

    distribution.value = dist;
  }

  String _planDisplayName(UserInvestmentModel inv) {
    if (inv.investment != null) {
      final locale = Get.locale?.languageCode ?? 'en';
      if (locale == 'ar') return inv.investment!.nameAr;
      return inv.investment!.nameEn ?? inv.investment!.nameAr;
    }
    return CurrencyController.to.formatToUSD(inv.amount);
  }

  void _buildGrowthData() {
    final transactions = _home.allTransactions.isNotEmpty
        ? _home.allTransactions.toList()
        : _home.recentTransactions.toList();

    if (transactions.isEmpty) {
      growthData.value = [];
      return;
    }

    final now = DateTime.now();
    final cutoff = _periodCutoff(selectedPeriod.value, now);

    final filtered = transactions
        .where((t) =>
            t.createdAt != null &&
            t.createdAt!.isAfter(cutoff) &&
            t.status == 'completed')
        .toList()
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    if (filtered.isEmpty) {
      growthData.value = [netWorth.value, netWorth.value];
      return;
    }

    // Build cumulative balance curve from transactions
    double runningBalance = 0;
    final List<double> points = [];

    for (final tx in filtered) {
      if (tx.isCredit) {
        runningBalance += tx.amount;
      } else {
        runningBalance -= tx.amount;
      }
      points.add(runningBalance);
    }

    // Normalize so the last point matches current net worth
    if (points.isNotEmpty) {
      final drift = netWorth.value - points.last;
      for (int i = 0; i < points.length; i++) {
        points[i] += drift;
      }
    }

    // Down-sample to max 60 points for smooth rendering
    if (points.length > 60) {
      final step = points.length / 60;
      final sampled = <double>[];
      for (double i = 0; i < points.length; i += step) {
        sampled.add(points[i.toInt()]);
      }
      if (sampled.last != points.last) sampled.add(points.last);
      growthData.value = sampled;
    } else {
      growthData.value = points;
    }

  }

  void _buildInvestmentFlow() {
    final transactions = _home.allTransactions.isNotEmpty
        ? _home.allTransactions.toList()
        : _home.recentTransactions.toList();

    final now = DateTime.now();
    final cutoff = _periodCutoff(selectedPeriod.value, now);

    final filtered = transactions
        .where((t) =>
            t.createdAt != null &&
            t.createdAt!.isAfter(cutoff) &&
            t.status == 'completed')
        .toList();

    double deposits = 0;
    double returns = 0;
    double withdrawals = 0;
    double investments = 0;

    const profitTypes = {'profit', 'investment_return', 'reward'};

    for (final tx in filtered) {
      switch (tx.type) {
        case 'deposit':
          deposits += tx.amount;
          break;
        case 'withdrawal':
          withdrawals += tx.amount;
          break;
        case 'investment':
          investments += tx.amount;
          break;
        default:
          if (profitTypes.contains(tx.type)) {
            returns += tx.amount;
          }
      }
    }

    var activeCount = 0;
    var completedCount = 0;
    for (final inv in _home.myInvestments) {
      final status = inv.status.toLowerCase();
      if (status == 'active') {
        activeCount++;
      } else if (status == 'completed' || status == 'matured') {
        completedCount++;
      }
    }

    final opening =
        netWorth.value - deposits - returns + withdrawals + investments;

    investmentFlow.value = InvestmentFlowSnapshot(
      opening: opening,
      deposits: deposits,
      returns: returns,
      withdrawals: withdrawals,
      investments: investments,
      closing: netWorth.value,
      activeInvestments: activeCount,
      completedInvestments: completedCount,
    );
  }

  void _computePeriodPerformance() {
    final transactions = _home.allTransactions.isNotEmpty
        ? _home.allTransactions.toList()
        : _home.recentTransactions.toList();

    final now = DateTime.now();

    dailyPerformance.value = _netForPeriod(
      transactions,
      now.subtract(const Duration(days: 1)),
    );
    weeklyPerformance.value = _netForPeriod(
      transactions,
      now.subtract(const Duration(days: 7)),
    );
    monthlyPerformance.value = _netForPeriod(
      transactions,
      now.subtract(const Duration(days: 30)),
    );
    yearlyPerformance.value = _netForPeriod(
      transactions,
      now.subtract(const Duration(days: 365)),
    );
  }

  double _netForPeriod(List<TransactionModel> txs, DateTime since) {
    double net = 0;
    for (final tx in txs) {
      if (tx.createdAt != null &&
          tx.createdAt!.isAfter(since) &&
          tx.status == 'completed') {
        final profitTypes = {'profit', 'investment_return', 'reward'};
        if (profitTypes.contains(tx.type)) {
          net += tx.amount;
        }
      }
    }
    return net;
  }

  void _generateInsights() {
    final list = <String>[];
    final investments = _home.myInvestments;

    if (investments.isEmpty) {
      insights.value = list;
      return;
    }

    // Diversification insight
    final uniquePlans = investments.map((e) => e.planId).toSet();
    if (uniquePlans.length < 3 && investments.length >= 2) {
      list.add('portfolio_insight_diversify');
    }

    // Growth insight
    if (roiPercentage.value > 5) {
      list.add('portfolio_insight_growth');
    }

    // Reinvest insight
    final dash = _home.dashboard.value;
    if (dash != null && dash.availableBalance > 100) {
      list.add('portfolio_insight_reinvest');
    }

    insights.value = list;
  }

  DateTime _periodCutoff(PortfolioPeriod period, DateTime now) {
    switch (period) {
      case PortfolioPeriod.d7:
        return now.subtract(const Duration(days: 7));
      case PortfolioPeriod.d30:
        return now.subtract(const Duration(days: 30));
      case PortfolioPeriod.d90:
        return now.subtract(const Duration(days: 90));
      case PortfolioPeriod.y1:
        return now.subtract(const Duration(days: 365));
      case PortfolioPeriod.all:
        return DateTime(2020);
    }
  }

  String periodLabel(PortfolioPeriod period) {
    switch (period) {
      case PortfolioPeriod.d7:
        return 'period_7d'.tr;
      case PortfolioPeriod.d30:
        return 'period_30d'.tr;
      case PortfolioPeriod.d90:
        return 'period_90d'.tr;
      case PortfolioPeriod.y1:
        return 'period_1y'.tr;
      case PortfolioPeriod.all:
        return 'period_all'.tr;
    }
  }

  bool get hasData => _home.myInvestments.isNotEmpty;

  // Allocation colors for distribution chart
  static const List<Color> allocationColors = [
    Color(0xFFC9A24D),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF795548),
  ];
}
