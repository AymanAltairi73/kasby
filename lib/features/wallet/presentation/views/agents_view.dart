import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/agent_service.dart';
import 'package:kasby/core/services/agent_chat_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/features/wallet/presentation/widgets/agent_card.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AgentsView extends StatefulWidget {
  const AgentsView({super.key});

  @override
  State<AgentsView> createState() => _AgentsViewState();
}

class _AgentsViewState extends State<AgentsView> {
  final RxList<AgentModel> agents = <AgentModel>[].obs;
  final RxList<AgentModel> filteredAgents = <AgentModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  StreamSubscription<List<Map<String, dynamic>>>? _profilesSub;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'AgentsView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
    );
    _fetchAgents();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
      _filterAgents();
    });
  }

  void _filterAgents() {
    if (_searchQuery.isEmpty) {
      filteredAgents.value = agents;
    } else {
      final query = _searchQuery.value.toLowerCase();
      filteredAgents.value = agents.where((agent) {
        final name = agent.name.toLowerCase();
        final city = agent.city.toLowerCase();
        final username = (agent.username ?? '').toLowerCase();
        return name.contains(query) ||
            city.contains(query) ||
            username.contains(query);
      }).toList();
    }
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'AgentsView',
      method: 'dispose',
      feature: 'Wallet',
      status: 'INFO',
    );
    _searchController.dispose();
    _profilesSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    hasError.value = false;
    try {
      agents.value = await AgentService.fetchActiveAgents(limit: 50);
      _filterAgents();
      _listenProfileUpdates();
      SafeGetx.debugTrace(
        className: 'AgentsView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'count': agents.length},
      );
    } catch (e, stack) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'AgentsView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _listenProfileUpdates() {
    _profilesSub?.cancel();
    if (!SupabaseService.isLoggedIn) return;

    final userIds = agents
        .map((agent) => agent.userId)
        .whereType<String>()
        .toList();
    if (userIds.isEmpty) return;

    _profilesSub = SupabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .inFilter('id', userIds)
        .listen((rows) {
          var changed = false;
          for (final row in rows) {
            final userId = row['id']?.toString();
            if (userId == null) continue;

            final index = agents.indexWhere((agent) => agent.userId == userId);
            if (index < 0) continue;

            final updated = agents[index].copyWith(
              name: row['full_name']?.toString() ?? agents[index].name,
              username: row['referral_code']?.toString() ?? agents[index].username,
              avatarUrl: row['avatar_url']?.toString(),
              kycStatus: row['kyc_status']?.toString() ?? agents[index].kycStatus,
            );

            if (updated.avatarUrl != agents[index].avatarUrl ||
                updated.name != agents[index].name ||
                updated.username != agents[index].username ||
                updated.kycStatus != agents[index].kycStatus) {
              agents[index] = updated;
              changed = true;
            }
          }

          if (changed) {
            agents.refresh();
            _filterAgents();
          }
        });
  }

  Future<void> _startAgentChat(AgentModel agent) async {
    if (agent.userId == null) {
      AppSnack.warning('warning'.tr, 'agent_not_active'.tr);
      return;
    }

    final currentUserId = SupabaseService.userId;
    if (currentUserId != null && agent.userId == currentUserId) {
      AppSnack.warning('warning'.tr, 'agent_chat_self_not_allowed'.tr);
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final result = await AgentChatService.startChat(
      agentRecordId: agent.id,
      agentUserId: agent.userId,
      agentName: agent.name,
    );

    SafeGetx.dismissOverlayIfOpen();

    if (!result.success ||
        result.conversationId == null ||
        result.conversation == null) {
      SafeGetx.debugTrace(
        className: 'AgentsView',
        method: '_startAgentChat',
        feature: 'AgentChat',
        status: 'ERROR',
        message: result.error,
        params: {
          'rpc': result.rpcName,
          'rpcParams': result.rpcParams,
          'agentId': agent.id,
          'agentUserId': agent.userId,
          'currentUserId': currentUserId,
          'durationMs': result.durationMs,
        },
        error: result.exception,
        stackTrace: result.stackTrace,
      );
      AppSnack.error(
        'error'.tr,
        result.error ?? 'chat_connection_error'.tr,
      );
      return;
    }

    SafeGetx.debugTrace(
      className: 'AgentsView',
      method: '_startAgentChat',
      feature: 'AgentChat',
      status: 'SUCCESS',
      durationMs: result.durationMs,
      params: {
        'agentId': agent.id,
        'agentUserId': agent.userId,
        'conversationId': result.conversationId,
        'currentUserId': currentUserId,
      },
    );

    await Get.toNamed(
      Routes.socialChat,
      arguments: {
        'conversation_id': result.conversationId,
        'conversation': result.conversation,
        'user_id': agent.userId,
        'user_name': agent.name,
        'is_agent_chat': true,
      },
    );
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('authorized_agents'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'back'.tr,
          onPressed: () => Get.safeBack(),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, __) =>
                      const KasbyShimmer.listItem(height: 118),
                );
              }

              if (hasError.value && agents.isEmpty) {
                return ErrorStateWidget(onRetry: _fetchAgents);
              }

              if (filteredAgents.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'no_agents'.tr : 'no_results_found'.tr,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.darkGold,
                onRefresh: _fetchAgents,
                child: _buildListView(),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.darkGold.withValues(alpha: isDark ? 0.12 : 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.darkGold.withValues(alpha: 0.18),
                  AppColors.darkGold.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: AppColors.darkGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.darkGold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'authorized_agents'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isDark ? Colors.white : AppColors.textBodyLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'agency_desc'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Row(
              children: [
                _buildStatChip(
                  Icons.groups_rounded,
                  '${agents.length}',
                  'agents_list'.tr,
                ),
                const SizedBox(width: 10),
                _buildStatChip(
                  Icons.verified_rounded,
                  '${agents.where((a) => a.status == 'active').length}',
                  'verified_agent'.tr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'search_agent_hint'.tr,
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.darkGold),
                suffixIcon: Obx(() => _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'close'.tr,
                        onPressed: _searchController.clear,
                      )
                    : const SizedBox.shrink()),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.toNamed(Routes.agencyApply),
              icon: Icon(Icons.workspace_premium_rounded, color: AppColors.darkGold),
              label: Text(
                'apply_agency'.tr,
                style: TextStyle(
                  color: AppColors.darkGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.darkGold.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.darkGold.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.darkGold),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textBodyLight,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filteredAgents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final agent = filteredAgents[index];
        return AgentCard(
          agent: agent,
          isDark: isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            Get.toNamed(
              Routes.agentDetails,
              arguments: {
                'name': agent.name,
                'username': agent.username,
                'avatar_url': agent.avatarUrl,
                'country': agent.country,
                'location': agent.city,
                'rate': '${agent.successRate}%',
                'availability_status': agent.availabilityStatus,
                'is_online': agent.isAvailableNow,
                'kyc_status': agent.kycStatus,
                'whatsapp': agent.whatsapp,
                'telegram': agent.telegram,
                'phone': agent.phone,
              },
            );
          },
          onChat: () {
            HapticFeedback.lightImpact();
            _startAgentChat(agent);
          },
        );
      },
    );
  }
}
