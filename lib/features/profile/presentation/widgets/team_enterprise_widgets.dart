import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/features/profile/presentation/controllers/team_controller.dart';
import 'package:kasby/features/profile/presentation/widgets/team_member_profile_sheet.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/core/services/supabase_service.dart';

class TeamMemberCard extends StatelessWidget {
  const TeamMemberCard({
    super.key,
    required this.member,
    this.showLevel = true,
    this.compact = false,
    this.onTap,
    this.animationIndex = 0,
  });

  final Map<String, dynamic> member;
  final bool showLevel;
  final bool compact;
  final VoidCallback? onTap;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = member['id']?.toString() ?? '';
    final isOnline =
        Get.isRegistered<PresenceService>() &&
        Get.find<PresenceService>().isUserOnline(id);
    final isActive = member['status']?.toString() == 'active';
    final isVerified =
        member['is_verified'] == true ||
        member['kyc_status']?.toString() == 'verified';
    final invested = (member['investment_amount'] as num?)?.toDouble() ?? 0;

    return KasbyCard(
          padding: EdgeInsets.all(compact ? KasbySpacing.md : KasbySpacing.lg),
          margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
          borderRadius: KasbyRadius.card,
          hasShadow: true,
          child: InkWell(
            onTap: onTap ?? () => TeamMemberProfileSheet.show(member),
            borderRadius: KasbyRadius.cardR,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: compact ? 22 : 24,
                      backgroundImage: member['avatar_url'] != null
                          ? NetworkImage(member['avatar_url'].toString())
                          : null,
                      child: member['avatar_url'] == null
                          ? Text(
                              (member['full_name']?.toString() ?? '?')[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.softGreen : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.surface : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: KasbySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member['full_name']?.toString() ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 14 : 15,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.onSurfaceLight,
                              ),
                            ),
                          ),
                          if (showLevel)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KasbySpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.darkGold.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: KasbyRadius.chipR,
                              ),
                              child: Text(
                                'L${member['level'] ?? 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkGold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${member['referral_code'] ?? '—'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: KasbySpacing.xs),
                        Wrap(
                          spacing: KasbySpacing.xs,
                          runSpacing: KasbySpacing.xs,
                          children: [
                            _badge(
                              isActive ? 'active'.tr : 'inactive'.tr,
                              isActive ? AppColors.softGreen : Colors.grey,
                            ),
                            if (isVerified)
                              _badge('verified'.tr, AppColors.softGreen),
                            if (invested > 0)
                              _badge('investor'.tr, AppColors.darkGold),
                          ],
                        ),
                        const SizedBox(height: KasbySpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: _miniMetric(
                                'investment'.tr,
                                '\$${invested.toStringAsFixed(0)}',
                              ),
                            ),
                            Expanded(
                              child: _miniMetric(
                                'referral_earnings'.tr,
                                '\$${(member['referral_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (member['created_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            DateHelper.date(
                              DateTime.parse(member['created_at'].toString()),
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 30 * animationIndex),
          duration: KasbyMotion.fast,
        )
        .slideX(begin: 0.03, duration: KasbyMotion.fast);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KasbyRadius.chipR,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class TeamNetworkTab extends StatelessWidget {
  const TeamNetworkTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TeamController.to;
    return Obx(() {
      final nodes = controller.treeNodes;
      if (nodes.isEmpty) {
        return _emptyState('no_team_members'.tr);
      }
      return ListView.builder(
        padding: KasbyLayout.listPadding(context),
        itemCount: nodes.length,
        itemBuilder: (_, i) =>
            TeamMemberCard(member: nodes[i], animationIndex: i),
      );
    });
  }
}

class TeamTimelineTab extends StatelessWidget {
  const TeamTimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TeamController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final items = controller.timelineItems;
      if (items.isEmpty) {
        return _emptyState('no_activity_yet'.tr);
      }
      return ListView.builder(
        padding: KasbyLayout.listPadding(context),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.darkGold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.darkGold.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.darkGold.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: KasbySpacing.sm),
                Expanded(
                  child: KasbyCard(
                    padding: const EdgeInsets.all(KasbySpacing.md),
                    margin: const EdgeInsets.only(bottom: KasbySpacing.sm),
                    borderRadius: KasbyRadius.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['title']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.onSurfaceLight,
                                ),
                              ),
                            ),
                            if (item['amount'] != null)
                              Text(
                                '\$${(item['amount'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkGold,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                        if (item['body'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item['body'].toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (item['created_at'] != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: KasbySpacing.xs,
                            ),
                            child: Text(
                              DateHelper.dateTime(
                                DateTime.parse(item['created_at'].toString()),
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class TeamStatsTab extends StatelessWidget {
  const TeamStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TeamController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = KasbyLayout.gridColumns(context);
    final aspect = KasbyLayout.statsAspectRatio(context);

    return Obx(() {
      final s = controller.statistics;
      if (s.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final metrics = [
        ('total_team_members', s['total_members']),
        ('active_members', s['active_members']),
        ('inactive_members', s['inactive_members']),
        ('registered_today', s['registered_today']),
        ('verified_users', s['verified_users']),
        ('investors', s['investors']),
        ('non_investors', s['non_investors']),
        ('agents', s['agents']),
        ('premium_members', s['premium_members']),
        (
          'total_team_investment',
          '\$${(s['total_team_investment'] as num?)?.toStringAsFixed(0) ?? '0'}',
        ),
        (
          'total_referral_earnings',
          '\$${(s['total_referral_earnings'] as num?)?.toStringAsFixed(2) ?? '0'}',
        ),
        (
          'today_referral_earnings',
          '\$${(s['today_referral_earnings'] as num?)?.toStringAsFixed(2) ?? '0'}',
        ),
        (
          'monthly_referral_earnings',
          '\$${(s['monthly_referral_earnings'] as num?)?.toStringAsFixed(2) ?? '0'}',
        ),
        (
          'average_investment',
          '\$${(s['average_investment'] as num?)?.toStringAsFixed(0) ?? '0'}',
        ),
        ('highest_investor', s['highest_investor']),
        ('newest_member', s['newest_member']),
      ];

      return GridView.builder(
        padding: KasbyLayout.listPadding(context),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: aspect,
          crossAxisSpacing: KasbySpacing.sm,
          mainAxisSpacing: KasbySpacing.sm,
        ),
        itemCount: metrics.length,
        itemBuilder: (_, i) {
          final key = metrics[i].$1;
          final value = metrics[i].$2?.toString() ?? '0';
          return KasbyCard(
            padding: const EdgeInsets.all(KasbySpacing.md),
            borderRadius: KasbyRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  key.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: KasbySpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

/// Builds hierarchical tree nodes from flat RPC data using [parent_id].
class _TreeNode {
  _TreeNode(this.data, {this.children = const []});
  final Map<String, dynamic> data;
  final List<_TreeNode> children;
}

List<_TreeNode> _buildTreeRoots(
  List<Map<String, dynamic>> flat,
  String rootUserId,
) {
  final nodes = flat
      .map((n) => _TreeNode(Map<String, dynamic>.from(n)))
      .toList();
  final byId = {for (final n in nodes) n.data['id']?.toString() ?? '': n};
  final childMap = <String, List<_TreeNode>>{};

  for (final node in nodes) {
    final parentId = node.data['parent_id']?.toString();
    if (parentId != null &&
        parentId != rootUserId &&
        byId.containsKey(parentId)) {
      childMap.putIfAbsent(parentId, () => []).add(node);
    }
  }

  _TreeNode withChildren(_TreeNode n) {
    final id = n.data['id']?.toString() ?? '';
    final kids = childMap[id] ?? const [];
    return _TreeNode(n.data, children: kids.map(withChildren).toList());
  }

  return nodes
      .where((n) {
        final parentId = n.data['parent_id']?.toString();
        return parentId == null ||
            parentId == rootUserId ||
            !byId.containsKey(parentId);
      })
      .map(withChildren)
      .toList();
}

class TeamTreeTab extends StatefulWidget {
  const TeamTreeTab({super.key});

  @override
  State<TeamTreeTab> createState() => _TeamTreeTabState();
}

class _TeamTreeTabState extends State<TeamTreeTab> {
  final _searchController = TextEditingController();
  final _collapsed = <String>{};
  int _levelFilter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isExpanded(String id) => !_collapsed.contains(id);

  void _toggle(String id) {
    setState(() {
      if (_collapsed.contains(id)) {
        _collapsed.remove(id);
      } else {
        _collapsed.add(id);
      }
    });
  }

  List<Map<String, dynamic>> _filterFlat(List<Map<String, dynamic>> nodes) {
    final query = _searchController.text.trim().toLowerCase();
    return nodes.where((n) {
      if (_levelFilter > 0 && (n['level'] as int? ?? 1) != _levelFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = n['full_name']?.toString().toLowerCase() ?? '';
      final code = n['referral_code']?.toString().toLowerCase() ?? '';
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TeamController.to;
    final rootId = SupabaseService.userId ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KasbySpacing.lg,
            KasbySpacing.sm,
            KasbySpacing.lg,
            0,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search'.tr,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: KasbyRadius.inputR),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: KasbySpacing.md,
                vertical: KasbySpacing.sm,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: KasbySpacing.lg,
            vertical: KasbySpacing.sm,
          ),
          child: Row(
            children: [
              FilterChip(
                label: Text('all_levels'.tr),
                visualDensity: VisualDensity.compact,
                selected: _levelFilter == 0,
                onSelected: (_) => setState(() => _levelFilter = 0),
              ),
              for (var l = 1; l <= 5; l++)
                Padding(
                  padding: const EdgeInsets.only(left: KasbySpacing.sm),
                  child: FilterChip(
                    label: Text('L$l'),
                    visualDensity: VisualDensity.compact,
                    selected: _levelFilter == l,
                    onSelected: (_) => setState(() => _levelFilter = l),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final filtered = _filterFlat(controller.treeNodes);
            if (filtered.isEmpty) {
              return _emptyState('no_team_members'.tr);
            }

            final roots = _buildTreeRoots(filtered, rootId);
            return ListView(
              padding: KasbyLayout.listPadding(context),
              children: [
                for (var i = 0; i < roots.length; i++)
                  _TreeNodeTile(
                    node: roots[i],
                    depth: 0,
                    isExpanded: _isExpanded,
                    onToggle: _toggle,
                    animationIndex: i,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _TreeNodeTile extends StatelessWidget {
  const _TreeNodeTile({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.onToggle,
    this.animationIndex = 0,
  });

  final _TreeNode node;
  final int depth;
  final bool Function(String id) isExpanded;
  final void Function(String id) onToggle;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final id = node.data['id']?.toString() ?? '';
    final hasChildren = node.children.isNotEmpty;
    final expanded = isExpanded(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: depth * 20.0),
            if (hasChildren)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: KasbyMotion.fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.darkGold,
                  ),
                ),
                onPressed: () => onToggle(id),
              )
            else
              SizedBox(width: depth > 0 ? 28 : 0),
            Expanded(
              child: TeamMemberCard(
                member: node.data,
                compact: true,
                animationIndex: animationIndex,
              ),
            ),
          ],
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              for (var i = 0; i < node.children.length; i++)
                _TreeNodeTile(
                  node: node.children[i],
                  depth: depth + 1,
                  isExpanded: isExpanded,
                  onToggle: onToggle,
                  animationIndex: animationIndex + i + 1,
                ),
            ],
          ),
          crossFadeState: expanded && hasChildren
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: KasbyMotion.normal,
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

Widget _emptyState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(KasbySpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: KasbySpacing.md),
          Text(message, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}
