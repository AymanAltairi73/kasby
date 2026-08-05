import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/search_result_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/features/search/presentation/controllers/search_controller.dart';

class GlobalSearchView extends StatefulWidget {
  const GlobalSearchView({super.key});

  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  late final GlobalSearchController _controller;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(GlobalSearchController());
    _textController = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    Get.delete<GlobalSearchController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(isDark),
            _buildCategoryChips(isDark),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  // ─── SEARCH BAR ────────────────────────────────────────

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KasbySpacing.sm,
        KasbySpacing.md,
        KasbySpacing.lg,
        KasbySpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
            tooltip: 'back'.tr,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surface.withValues(alpha: 0.8)
                    : AppColors.surfaceLight,
                borderRadius: KasbyRadius.inputR,
                border: Border.all(
                  color: isDark
                      ? AppColors.onSurface.withValues(alpha: 0.1)
                      : AppColors.borderLight,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                onChanged: _controller.onQueryChanged,
                style: TextStyle(color: AppColors.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'search_placeholder'.tr,
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  suffixIcon: Obx(() {
                    if (_controller.query.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      onPressed: () {
                        _textController.clear();
                        _controller.clearSearch();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'close'.tr,
                    );
                  }),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KasbySpacing.lg,
                    vertical: KasbySpacing.md,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  // ─── CATEGORY CHIPS ────────────────────────────────────

  Widget _buildCategoryChips(bool isDark) {
    final categories = <_CategoryChipData>[
      _CategoryChipData('all', 'search_all'.tr, Icons.apps_rounded),
      _CategoryChipData(
        'investment',
        'search_investments'.tr,
        Icons.trending_up_rounded,
      ),
      _CategoryChipData(
        'transaction',
        'search_transactions'.tr,
        Icons.receipt_long_rounded,
      ),
      _CategoryChipData(
        'notification',
        'search_notifications'.tr,
        Icons.notifications_rounded,
      ),
      _CategoryChipData(
        'wallet',
        'search_wallet'.tr,
        Icons.account_balance_wallet_rounded,
      ),
      _CategoryChipData('team', 'search_team'.tr, Icons.group_rounded),
      _CategoryChipData('ksp', 'search_ksp'.tr, Icons.stars_rounded),
      _CategoryChipData(
        'agent',
        'search_agents'.tr,
        Icons.support_agent_rounded,
      ),
    ];

    return Obx(() {
      if (_controller.query.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.lg),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: KasbySpacing.sm),
          itemBuilder: (context, index) {
            final chip = categories[index];
            final isSelected = _controller.selectedCategory.value == chip.key;
            final count =
                _controller.results.value.categoryCounts[chip.key] ?? 0;

            return GestureDetector(
              onTap: () => _controller.selectCategory(chip.key),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: KasbySpacing.md,
                  vertical: KasbySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : isDark
                      ? AppColors.surface.withValues(alpha: 0.5)
                      : AppColors.surfaceLight,
                  borderRadius: KasbyRadius.chipR,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                        ? AppColors.onSurface.withValues(alpha: 0.08)
                        : AppColors.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      chip.icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: KasbySpacing.xs),
                    Text(
                      chip.key == 'all'
                          ? chip.label
                          : '${chip.label}${count > 0 ? ' ($count)' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ─── BODY ──────────────────────────────────────────────

  Widget _buildBody(bool isDark) {
    return Obx(() {
      if (_controller.query.isEmpty) {
        return _buildRecentSearches(isDark);
      }

      if (_controller.isSearching.value) {
        return _buildLoadingShimmer();
      }

      final items = _controller.filteredResults;

      if (items.isEmpty) {
        return _buildEmptyState();
      }

      return _buildResults(items, isDark);
    });
  }

  // ─── RECENT SEARCHES ──────────────────────────────────

  Widget _buildRecentSearches(bool isDark) {
    return Obx(() {
      final searches = _controller.recentSearches;

      if (searches.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_rounded,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: KasbySpacing.lg),
              Text(
                'search_hint'.tr,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'recent_searches'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: _controller.clearRecentSearches,
                  child: Text(
                    'clear_all'.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KasbySpacing.md),
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final search = searches[index];
                  return ListTile(
                        leading: Icon(
                          Icons.history_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          search,
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          tooltip: 'close'.tr,
                          onPressed: () =>
                              _controller.removeRecentSearch(search),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          _textController.text = search;
                          _textController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: search.length),
                              );
                          _controller.searchFromRecent(search);
                        },
                      )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                      .slideX(begin: -0.05, end: 0);
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── LOADING SHIMMER ──────────────────────────────────

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      child: Column(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: KasbySpacing.md),
            child: KasbyShimmer.listItem(
              margin: const EdgeInsets.only(bottom: 4),
            ),
          ),
        ),
      ),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      title: 'no_results'.tr,
      description: 'no_results_desc'.tr,
      icon: Icons.search_off_rounded,
    );
  }

  // ─── RESULTS ──────────────────────────────────────────

  Widget _buildResults(List<SearchResultItem> items, bool isDark) {
    final grouped = <String, List<SearchResultItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final showHeaders =
        _controller.selectedCategory.value == 'all' && grouped.length > 1;

    return ListView.builder(
      padding: const EdgeInsets.all(KasbySpacing.lg),
      itemCount: showHeaders ? _countWithHeaders(grouped) : items.length,
      itemBuilder: (context, index) {
        if (showHeaders) {
          return _buildGroupedItem(grouped, index, isDark);
        }
        return _buildResultTile(items[index], isDark, index);
      },
    );
  }

  int _countWithHeaders(Map<String, List<SearchResultItem>> grouped) {
    int count = 0;
    for (final entry in grouped.entries) {
      count += 1 + entry.value.length; // header + items
    }
    return count;
  }

  Widget _buildGroupedItem(
    Map<String, List<SearchResultItem>> grouped,
    int index,
    bool isDark,
  ) {
    int current = 0;
    for (final entry in grouped.entries) {
      if (index == current) {
        return _buildSectionHeader(entry.key, entry.value.length, isDark);
      }
      current++;
      if (index < current + entry.value.length) {
        final itemIndex = index - current;
        return _buildResultTile(entry.value[itemIndex], isDark, index);
      }
      current += entry.value.length;
    }
    return const SizedBox.shrink();
  }

  Widget _buildSectionHeader(String category, int count, bool isDark) {
    final label = _categoryLabel(category);
    return Padding(
      padding: const EdgeInsets.only(
        top: KasbySpacing.lg,
        bottom: KasbySpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: KasbySpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: KasbyRadius.chipR,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(SearchResultItem item, bool isDark, int index) {
    return Padding(
          padding: const EdgeInsets.only(bottom: KasbySpacing.sm),
          child: KasbyCard(
            padding: const EdgeInsets.all(KasbySpacing.md),
            borderRadius: KasbyRadius.card,
            child: InkWell(
              borderRadius: KasbyRadius.cardR,
              onTap: () => _onResultTap(item),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: KasbyRadius.inputR,
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: KasbySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KasbySpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 250.ms, delay: (40 * (index % 10)).ms)
        .slideX(begin: 0.03, end: 0);
  }

  void _onResultTap(SearchResultItem item) {
    if (item.route != null) {
      Get.toNamed(item.route!, arguments: item.arguments);
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'investment':
        return 'search_investments'.tr;
      case 'transaction':
        return 'search_transactions'.tr;
      case 'notification':
        return 'search_notifications'.tr;
      case 'wallet':
        return 'search_wallet'.tr;
      case 'team':
        return 'search_team'.tr;
      case 'ksp':
        return 'search_ksp'.tr;
      case 'agent':
        return 'search_agents'.tr;
      default:
        return category.capitalizeFirst ?? category;
    }
  }
}

class _CategoryChipData {
  final String key;
  final String label;
  final IconData icon;

  const _CategoryChipData(this.key, this.label, this.icon);
}
