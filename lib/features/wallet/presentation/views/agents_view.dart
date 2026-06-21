import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/agent_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  final RxBool _showMap = false.obs;
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

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
        return name.contains(query) || city.contains(query);
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
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    hasError.value = false;
    try {
      agents.value = await AgentService.fetchActiveAgents(limit: 50);
      _filterAgents();
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

  Future<void> _startAgentChat(AgentModel agent) async {
    if (agent.userId == null) {
      AppSnack.warning('warning'.tr, 'agent_not_active'.tr);
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final response = await SupabaseService.client.rpc(
        'fn_start_agent_chat',
        params: {'p_agent_id': agent.id},
      );

      Get.safeBack();

      if (response != null && response['success'] == true) {
        SafeGetx.debugTrace(
          className: 'AgentsView',
          method: '_startAgentChat',
          feature: 'Wallet',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
          params: {'agentId': agent.id},
        );
        final conversationId = response['conversation']['id'];
        Get.toNamed(Routes.socialChat, arguments: {
          'conversation_id': conversationId,
          'user_id': agent.userId,
          'user_name': agent.name,
          'is_agent_chat': true,
        });
      } else {
        SafeGetx.debugTrace(
          className: 'AgentsView',
          method: '_startAgentChat',
          feature: 'Wallet',
          status: 'WARN',
          durationMs: stopwatch.elapsedMilliseconds,
          message: response?['error']?.toString(),
        );
        AppSnack.error('error'.tr, response['error'] ?? 'chat_connection_error'.tr);
      }
    } catch (e, stack) {
      if (Get.isDialogOpen ?? false) Get.safeBack();
      SafeGetx.debugTrace(
        className: 'AgentsView',
        method: '_startAgentChat',
        feature: 'Wallet',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      AppSnack.error('error'.tr, 'chat_connection_error'.tr);
    }
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
                      const KasbyShimmer.listItem(height: 90),
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

              if (_showMap.value) {
                return _buildMapView();
              }

              return _buildListView();
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
                  Icons.map_rounded,
                  '${agents.where((a) => a.latitude != null).length}',
                  'agents_map'.tr,
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
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : const SizedBox.shrink()),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      'agents_list'.tr,
                      isSelected: !_showMap.value,
                      onTap: () => _showMap.value = false,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      'agents_map'.tr,
                      isSelected: _showMap.value,
                      onTap: () => _showMap.value = true,
                    ),
                  ),
                ],
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

  Widget _buildTabButton(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkGold
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : AppColors.textBodyLight),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredAgents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final agent = filteredAgents[index];
                  return Semantics(
                    button: true,
                    label: agent.name,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Get.toNamed(
                          Routes.agentDetails,
              arguments: {
                'name': agent.name,
                'country': agent.country,
                'location': agent.city,
                'rate': '${agent.successRate}%',
                'availability_status': agent.availabilityStatus,
                'whatsapp': agent.whatsapp,
                'telegram': agent.telegram,
                'phone': agent.phone,
              },
            );
          },
          child: KasbyCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.darkGold.withValues(alpha: 0.25),
                        AppColors.darkGold.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.darkGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.darkGold,
                    size: 28,
                  ),
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
                              agent.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textBodyLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (agent.status == 'active')
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${agent.city}, ${agent.country}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(agent.availabilityStatus)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusText(agent.availabilityStatus),
                              style: TextStyle(
                                color: _getStatusColor(agent.availabilityStatus),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (agent.successRate > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'success_rate'.trParams({
                                  'rate': '${agent.successRate.toStringAsFixed(0)}%',
                                }),
                                style: TextStyle(
                                  color: AppColors.softGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.darkGold,
                      ),
                      tooltip: 'send_message'.tr,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _startAgentChat(agent);
                      },
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    final agentsWithCoords = filteredAgents
        .where((a) => a.latitude != null && a.longitude != null)
        .toList();
    final agentsWithoutCoords = filteredAgents
        .where((a) => a.latitude == null || a.longitude == null)
        .toList();

    final mapCenter = agentsWithCoords.isNotEmpty
        ? LatLng(agentsWithCoords.first.latitude!, agentsWithCoords.first.longitude!)
        : LatLng(33.3, 44.4);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: agentsWithCoords.isNotEmpty ? 10 : 5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kasby.app',
                          ),
                          MarkerLayer(markers: _buildMarkers(agentsWithCoords)),
                        ],
                      ),
                      if (agentsWithCoords.isNotEmpty)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.surface : Colors.white)
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place_rounded,
                                  size: 16,
                                  color: AppColors.darkGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${agentsWithCoords.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textBodyLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (agentsWithCoords.isEmpty)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.surface : Colors.white).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_rounded, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'no_agent_locations'.tr,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (agentsWithoutCoords.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${agentsWithoutCoords.length} ${'agents_without_location'.tr}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: agentsWithoutCoords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final agent = agentsWithoutCoords[index];
                return _buildCompactAgentTile(agent);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactAgentTile(AgentModel agent) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Get.toNamed(Routes.agentDetails, arguments: {
          'name': agent.name,
          'country': agent.country,
          'location': agent.city,
          'rate': '${agent.successRate}%',
          'availability_status': agent.availabilityStatus,
          'whatsapp': agent.whatsapp,
          'telegram': agent.telegram,
          'phone': agent.phone,
        });
      },
      child: KasbyCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  isDark ? AppColors.surface : AppColors.surfaceLight,
              child: Icon(Icons.person, color: AppColors.darkGold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                agent.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textBodyLight,
                ),
              ),
            ),
            Text(
              agent.city,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(List<AgentModel> agentsWithCoords) {
    return agentsWithCoords.map((agent) {
      return Marker(
        point: LatLng(agent.latitude!, agent.longitude!),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              backgroundColor: isDark ? AppColors.surface : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _buildAgentInfoSheet(agent),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkGold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAgentInfoSheet(AgentModel agent) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                isDark ? AppColors.surface : AppColors.surfaceLight,
            child: Icon(Icons.person, color: AppColors.darkGold, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            agent.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textBodyLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${agent.city}, ${agent.country}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(agent.availabilityStatus)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _getStatusText(agent.availabilityStatus),
              style: TextStyle(
                color: _getStatusColor(agent.availabilityStatus),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Get.toNamed(Routes.agentDetails, arguments: {
                    'name': agent.name,
                    'country': agent.country,
                    'location': agent.city,
                    'rate': '${agent.successRate}%',
                    'availability_status': agent.availabilityStatus,
                    'whatsapp': agent.whatsapp,
                    'telegram': agent.telegram,
                    'phone': agent.phone,
                  });
                },
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text('details'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startAgentChat(agent);
                },
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: AppColors.darkGold),
                label: Text('chat'.tr,
                    style: TextStyle(color: AppColors.darkGold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.darkGold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.softGreen;
      case 'busy':
        return Colors.orange;
      case 'unavailable':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'status_available'.tr;
      case 'busy':
        return 'status_busy'.tr;
      case 'unavailable':
        return 'status_unavailable'.tr;
      default:
        return 'status_unavailable'.tr;
    }
  }
}
