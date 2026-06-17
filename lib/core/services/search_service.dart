import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/models/search_result_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class SearchService {
  SearchService._();

  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;

  // ─── RECENT SEARCHES ───────────────────────────────────

  static Future<List<String>> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'loadRecentSearches',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  static Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_recentSearchesKey) ?? [];
      searches.remove(query);
      searches.insert(0, query);
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }
      await prefs.setStringList(_recentSearchesKey, searches);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'saveRecentSearch',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static Future<void> removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_recentSearchesKey) ?? [];
      searches.remove(query);
      await prefs.setStringList(_recentSearchesKey, searches);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'removeRecentSearch',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'clearRecentSearches',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ─── SEARCH ────────────────────────────────────────────

  static Future<SearchResults> search(String query) async {
    if (query.trim().isEmpty) return SearchResults.empty;

    final stopwatch = Stopwatch()..start();
    final lowerQuery = query.toLowerCase().trim();

    try {
      final results = await Future.wait([
        _searchInvestments(lowerQuery),
        _searchTransactions(lowerQuery),
        _searchNotifications(lowerQuery),
        _searchWallet(lowerQuery),
        _searchTeam(lowerQuery),
        _searchKsp(lowerQuery),
        _searchAgents(lowerQuery),
      ]);

      final allItems = results.expand((list) => list).toList();

      final categoryCounts = <String, int>{};
      for (final item in allItems) {
        categoryCounts[item.category] =
            (categoryCounts[item.category] ?? 0) + 1;
      }

      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'search',
        feature: 'Search',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'query': query, 'results': allItems.length},
      );

      return SearchResults(
        items: allItems,
        totalCount: allItems.length,
        categoryCounts: categoryCounts,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: 'search',
        feature: 'Search',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      return SearchResults.empty;
    }
  }

  // ─── CATEGORY SEARCHES ─────────────────────────────────

  static Future<List<SearchResultItem>> _searchInvestments(
    String query,
  ) async {
    final items = <SearchResultItem>[];
    final home = _homeController;
    if (home == null) return items;

    for (final inv in home.myInvestments) {
      if (_matchesInvestment(inv, query)) {
        items.add(SearchResultItem(
          id: inv.id,
          title:
              '${_investmentPlanName(inv)} — ${_formatAmount(inv.amount)}',
          subtitle:
              '${'status'.tr}: ${inv.status.tr} · ${'profit'.tr}: ${inv.profitPercentage}%',
          category: 'investment',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF4CAF50),
          route: Routes.investmentDetails,
          arguments: {'investment': inv},
        ));
      }
    }

    if (items.isEmpty) {
      try {
        final response = await SupabaseService.client
            .from('user_investments')
            .select('*, investment:investment_plans(*)')
            .eq('user_id', SupabaseService.userId!)
            .or('status.ilike.%$query%,plan_id.ilike.%$query%')
            .order('created_at', ascending: false)
            .limit(5);

        for (final json in response as List) {
          final inv = UserInvestmentModel.fromJson(json);
          if (!items.any((i) => i.id == inv.id)) {
            items.add(SearchResultItem(
              id: inv.id,
              title:
                  '${_investmentPlanName(inv)} — ${_formatAmount(inv.amount)}',
              subtitle:
                  '${'status'.tr}: ${inv.status.tr} · ${'profit'.tr}: ${inv.profitPercentage}%',
              category: 'investment',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF4CAF50),
              route: Routes.investmentDetails,
              arguments: {'investment': inv},
            ));
          }
        }
      } catch (e, stack) {
        SafeGetx.debugTrace(
          className: 'SearchService',
          method: '_searchInvestments',
          feature: 'Search',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
      }
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchTransactions(
    String query,
  ) async {
    final items = <SearchResultItem>[];
    final home = _homeController;
    if (home == null) return items;

    for (final tx in home.recentTransactions) {
      if (_matchesTransaction(tx, query)) {
        items.add(_transactionToSearchItem(tx));
      }
    }

    if (items.isEmpty) {
      try {
        final response = await SupabaseService.client
            .from('transactions')
            .select()
            .eq('user_id', SupabaseService.userId!)
            .or('type.ilike.%$query%,status.ilike.%$query%,description.ilike.%$query%')
            .order('created_at', ascending: false)
            .limit(5);

        for (final json in response as List) {
          final tx = TransactionModel.fromJson(json);
          if (!items.any((i) => i.id == tx.id)) {
            items.add(_transactionToSearchItem(tx));
          }
        }
      } catch (e, stack) {
        SafeGetx.debugTrace(
          className: 'SearchService',
          method: '_searchTransactions',
          feature: 'Search',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
      }
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchNotifications(
    String query,
  ) async {
    final items = <SearchResultItem>[];
    final home = _homeController;
    if (home == null) return items;

    for (final n in home.notifications) {
      if (_matchesNotification(n, query)) {
        items.add(SearchResultItem(
          id: n.id,
          title: n.title,
          subtitle: n.message,
          category: 'notification',
          icon: Icons.notifications_rounded,
          color: const Color(0xFFFF9800),
          route: Routes.notifications,
        ));
      }
    }

    if (items.isEmpty) {
      try {
        final response = await SupabaseService.client
            .from('notifications')
            .select()
            .eq('user_id', SupabaseService.userId!)
            .or('title.ilike.%$query%,message.ilike.%$query%')
            .order('created_at', ascending: false)
            .limit(5);

        for (final json in response as List) {
          final n = NotificationModel.fromJson(json);
          if (!items.any((i) => i.id == n.id)) {
            items.add(SearchResultItem(
              id: n.id,
              title: n.title,
              subtitle: n.message,
              category: 'notification',
              icon: Icons.notifications_rounded,
              color: const Color(0xFFFF9800),
              route: Routes.notifications,
            ));
          }
        }
      } catch (e, stack) {
        SafeGetx.debugTrace(
          className: 'SearchService',
          method: '_searchNotifications',
          feature: 'Search',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
      }
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchWallet(String query) async {
    final items = <SearchResultItem>[];

    final walletTerms = [
      'wallet',
      'balance',
      'deposit',
      'withdraw',
      'transfer',
      'محفظة',
      'رصيد',
      'إيداع',
      'سحب',
      'تحويل',
    ];

    final matched = walletTerms.any(
      (term) => term.contains(query) || query.contains(term),
    );

    if (matched) {
      final cc = _currencyController;
      final balanceText = cc != null
          ? cc.formatAmount(cc.totalBalance.value)
          : '';

      items.add(SearchResultItem(
        id: 'wallet_balance',
        title: 'wallet'.tr,
        subtitle: '${'total_balance'.tr}: $balanceText',
        category: 'wallet',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF2196F3),
        route: Routes.home,
      ));

      if (query.contains('deposit') || query.contains('إيداع')) {
        items.add(SearchResultItem(
          id: 'wallet_deposit',
          title: 'deposit'.tr,
          subtitle: 'deposit_description'.tr,
          category: 'wallet',
          icon: Icons.add_circle_rounded,
          color: const Color(0xFF4CAF50),
          route: Routes.deposit,
        ));
      }

      if (query.contains('withdraw') || query.contains('سحب')) {
        items.add(SearchResultItem(
          id: 'wallet_withdraw',
          title: 'withdraw'.tr,
          subtitle: 'withdraw_description'.tr,
          category: 'wallet',
          icon: Icons.remove_circle_rounded,
          color: const Color(0xFFF44336),
          route: Routes.withdraw,
        ));
      }

      if (query.contains('transfer') || query.contains('تحويل')) {
        items.add(SearchResultItem(
          id: 'wallet_transfer',
          title: 'transfer'.tr,
          subtitle: 'transfer_description'.tr,
          category: 'wallet',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF9C27B0),
          route: Routes.transfer,
        ));
      }
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchTeam(String query) async {
    final items = <SearchResultItem>[];

    final teamTerms = [
      'team',
      'referral',
      'invite',
      'friend',
      'فريق',
      'إحالة',
      'دعوة',
      'صديق',
    ];

    final matched = teamTerms.any(
      (term) => term.contains(query) || query.contains(term),
    );

    if (matched) {
      final home = _homeController;
      final referralCode = home?.referralCode ?? '';

      items.add(SearchResultItem(
        id: 'team_referral',
        title: 'my_team'.tr,
        subtitle: '${'referral_code'.tr}: $referralCode',
        category: 'team',
        icon: Icons.group_rounded,
        color: const Color(0xFF3F51B5),
        route: Routes.myTeam,
      ));
    }

    if (items.isEmpty) {
      try {
        final response = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, referral_code')
            .eq('referred_by', SupabaseService.userId!)
            .or('full_name.ilike.%$query%,referral_code.ilike.%$query%')
            .limit(5);

        for (final json in response as List) {
          items.add(SearchResultItem(
            id: json['id'] as String,
            title: json['full_name'] as String? ?? 'team_member'.tr,
            subtitle: json['referral_code'] as String? ?? '',
            category: 'team',
            icon: Icons.person_rounded,
            color: const Color(0xFF3F51B5),
            route: Routes.myTeam,
          ));
        }
      } catch (e, stack) {
        SafeGetx.debugTrace(
          className: 'SearchService',
          method: '_searchTeam',
          feature: 'Search',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
      }
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchKsp(String query) async {
    final items = <SearchResultItem>[];

    final kspTerms = ['ksp', 'points', 'نقاط', 'spin', 'wheel', 'عجلة'];

    final matched = kspTerms.any(
      (term) => term.contains(query) || query.contains(term),
    );

    if (matched) {
      final home = _homeController;
      final points = home?.userPoints.value ?? 0;

      items.add(SearchResultItem(
        id: 'ksp_wallet',
        title: 'ksp_wallet'.tr,
        subtitle: '${'points_balance'.tr}: $points KSP',
        category: 'ksp',
        icon: Icons.stars_rounded,
        color: const Color(0xFFC9A24D),
        route: Routes.kspWallet,
      ));

      items.add(SearchResultItem(
        id: 'ksp_spin',
        title: 'spin_wheel'.tr,
        subtitle: 'spin_wheel_description'.tr,
        category: 'ksp',
        icon: Icons.casino_rounded,
        color: const Color(0xFFE91E63),
        route: Routes.spinWheel,
      ));
    }

    return items;
  }

  static Future<List<SearchResultItem>> _searchAgents(String query) async {
    final items = <SearchResultItem>[];

    final agentTerms = [
      'agent',
      'وكيل',
      'agency',
      'وكالة',
    ];

    final matched = agentTerms.any(
      (term) => term.contains(query) || query.contains(term),
    );

    if (matched) {
      items.add(SearchResultItem(
        id: 'agents_list',
        title: 'agents'.tr,
        subtitle: 'find_agents'.tr,
        category: 'agent',
        icon: Icons.support_agent_rounded,
        color: const Color(0xFF009688),
        route: Routes.agents,
      ));
    }

    try {
      final response = await SupabaseService.client
          .from('agents')
          .select('id, user_id, full_name, city, status')
          .eq('status', 'approved')
          .or('full_name.ilike.%$query%,city.ilike.%$query%')
          .limit(5);

      for (final json in response as List) {
        final name = json['full_name'] as String? ?? 'agent'.tr;
        final city = json['city'] as String? ?? '';
        items.add(SearchResultItem(
          id: json['id']?.toString() ?? json['user_id'] as String,
          title: name,
          subtitle: city,
          category: 'agent',
          icon: Icons.support_agent_rounded,
          color: const Color(0xFF009688),
          route: Routes.agentDetails,
          arguments: json,
        ));
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SearchService',
        method: '_searchAgents',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }

    return items;
  }

  // ─── HELPERS ───────────────────────────────────────────

  static HomeController? get _homeController {
    try {
      return HomeController.to;
    } catch (_) {
      return null;
    }
  }

  static CurrencyController? get _currencyController {
    try {
      return CurrencyController.to;
    } catch (_) {
      return null;
    }
  }

  static String _formatAmount(double amount) {
    final cc = _currencyController;
    if (cc != null) return cc.formatAmount(amount);
    return '\$${amount.toStringAsFixed(2)}';
  }

  static String _investmentPlanName(UserInvestmentModel inv) {
    final plan = inv.investment;
    if (plan == null) return 'investment'.tr;
    final isAr = Get.locale?.languageCode == 'ar';
    return isAr ? plan.nameAr : (plan.nameEn ?? plan.nameAr);
  }

  static bool _matchesInvestment(UserInvestmentModel inv, String query) {
    final searchable = [
      inv.status,
      inv.amount.toString(),
      inv.profitPercentage.toString(),
      inv.planId,
      inv.investment?.nameAr ?? '',
      inv.investment?.nameEn ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  static bool _matchesTransaction(TransactionModel tx, String query) {
    final searchable = [
      tx.type,
      tx.status,
      tx.amount.toString(),
      tx.description ?? '',
      tx.reason ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  static bool _matchesNotification(NotificationModel n, String query) {
    final searchable = [
      n.title,
      n.message,
      n.type,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  static SearchResultItem _transactionToSearchItem(TransactionModel tx) {
    final typeLabel = tx.type.replaceAll('_', ' ').capitalizeFirst ?? tx.type;
    return SearchResultItem(
      id: tx.id,
      title: '$typeLabel — ${_formatAmount(tx.amount)}',
      subtitle:
          '${'status'.tr}: ${tx.status.tr}${tx.description != null ? ' · ${tx.description}' : ''}',
      category: 'transaction',
      icon: tx.isCredit
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded,
      color: tx.isCredit ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
      route: Routes.transactionDetails,
      arguments: tx,
    );
  }
}
