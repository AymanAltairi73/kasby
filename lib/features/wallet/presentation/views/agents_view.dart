import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:flutter/services.dart';

class AgentsView extends StatefulWidget {
  const AgentsView({super.key});

  @override
  State<AgentsView> createState() => _AgentsViewState();
}

class _AgentsViewState extends State<AgentsView> {
  final RxList<AgentModel> agents = <AgentModel>[].obs;
  final RxList<AgentModel> filteredAgents = <AgentModel>[].obs;
  final RxBool isLoading = true.obs;
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    isLoading.value = true;
    try {
      debugPrint('[DEBUG] Fetching agents with status: Active...');
      final response = await SupabaseService.client
          .from('agents')
          .select('*, profiles(*)')
          .eq('status', 'active');

      debugPrint('[DEBUG] Agents Response Length: ${response.length}');
      if (response.isNotEmpty) {
        debugPrint('[DEBUG] First Agent Raw Data: ${response[0]}');
      } else {
        debugPrint('[DEBUG] Response is empty or null');
        // Test query: check if ANY agents exist without filter
        final countCheck = await SupabaseService.client
          .from('agents')
          .select('id')
          .limit(1);
        debugPrint('[DEBUG] Any agents in table? ${countCheck.isNotEmpty}');
      }

      agents.value = (response as List)
          .map((json) => AgentModel.fromJson(json))
          .toList();
      _filterAgents();
    } catch (e) {
      debugPrint('[DEBUG] Error fetching agents: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _startAgentChat(AgentModel agent) async {
    if (agent.userId == null) {
      Get.snackbar(
        'warning'.tr,
        'هذا الوكيل غير مرتبط بحساب نشط حالياً. يرجى استخدام الدعم الفني العام.',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final response = await SupabaseService.client.rpc(
        'fn_start_agent_chat',
        params: {'p_agent_id': agent.id},
      );

      Get.back(); // close loading dialog

      if (response != null && response['success'] == true) {
        final conversationId = response['conversation']['id'];
        Get.toNamed(Routes.socialChat, arguments: {
          'conversation_id': conversationId,
          'user_id': agent.userId,
          'user_name': agent.name,
          'is_agent_chat': true,
        });
      } else {
        Get.snackbar(
          'error'.tr,
          response['error'] ?? 'حدث خطأ أثناء بدء المحادثة',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('[AgentsView] Error starting agent chat: $e');
      Get.snackbar(
        'error'.tr,
        'فشل الاتصال بالوكيل. يرجى المحاولة لاحقاً',
        snackPosition: SnackPosition.BOTTOM,
      );
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
          onPressed: () => Get.back(),
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

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: filteredAgents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final agent = filteredAgents[index];
                  return GestureDetector(
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
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: isDark
                                ? AppColors.surface
                                : AppColors.surfaceLight,
                            child: Icon(
                              Icons.person,
                              color: AppColors.darkGold,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                          fontSize: 18,
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
                                Text(
                                  '${agent.city}, ${agent.country}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _getStatusColor(agent.availabilityStatus)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
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
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.darkGold,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _startAgentChat(agent);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'agency_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // ─── SEARCH BAR ──────────────────────────────────────
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
                hintText: 'search_agent_hint'.tr, // Search by agent name or city...
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.darkGold),
                suffixIcon: Obx(() => _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  'agents_list'.tr,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTabButton(
                  'apply_agency'.tr,
                  isSelected: false,
                  onTap: () => Get.toNamed(Routes.agencyApply),
                  isGlow: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
    bool isGlow = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkGold
              : (isDark ? AppColors.surface : AppColors.surfaceLight)
                    .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: isGlow
              ? Border.all(color: AppColors.darkGold.withValues(alpha: 0.5))
              : null,
          boxShadow: isGlow && !isSelected
              ? [
                  BoxShadow(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : AppColors.textBodyLight),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
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
