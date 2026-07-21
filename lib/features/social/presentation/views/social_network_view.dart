import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:kasby/core/theme/app_colors.dart';

import 'package:kasby/core/theme/kasby_design.dart';

import 'package:kasby/core/tour/tour_feature_host.dart';

import 'package:kasby/core/tour/tour_ids.dart';

import 'package:kasby/core/tour/tour_target_keys.dart';

import 'package:kasby/core/utils/safe_getx.dart';

import 'package:kasby/core/widgets/kasby_shimmer.dart';

import 'package:kasby/features/social/domain/models/friend_request_model.dart';

import 'package:kasby/features/social/domain/models/social_user_model.dart';

import 'package:kasby/features/social/presentation/controllers/social_network_controller.dart';

import 'package:kasby/features/social/presentation/widgets/friend_card.dart';

import 'package:kasby/features/social/presentation/widgets/friend_request_card.dart';

import 'package:kasby/features/social/presentation/widgets/invite_friends_sheet.dart';

import 'package:kasby/features/social/presentation/widgets/social_avatar.dart';

import 'package:kasby/features/social/presentation/widgets/social_dashboard_header.dart';

import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';

import 'package:kasby/features/agent_chat/presentation/views/agent_conversations_view.dart';



class SocialNetworkView extends StatefulWidget {

  const SocialNetworkView({super.key});



  @override

  State<SocialNetworkView> createState() => _SocialNetworkViewState();

}



class _SocialNetworkViewState extends State<SocialNetworkView>

    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  final _friendsFilterController = TextEditingController();

  final _userSearchController = TextEditingController();

  final _controller = SocialNetworkController.to;



  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  bool get _isAgent => Get.isRegistered<AuthController>() && AuthController.to.userRole == 'agent';



  @override

  void initState() {

    super.initState();

    _tabController = TabController(length: _isAgent ? 6 : 5, vsync: this);

    _userSearchController.addListener(() {

      _controller.searchUsers(_userSearchController.text);

    });

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (mounted) TourFeatureHost.scheduleForRoute(context, TourId.social);

    });

  }



  @override

  void dispose() {

    _tabController.dispose();

    _friendsFilterController.dispose();

    _userSearchController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,

      appBar: AppBar(

        title: Text('social_network'.tr),

        leading: IconButton(

          icon: const Icon(Icons.arrow_back_ios_new_rounded),

          tooltip: 'back'.tr,

          onPressed: () => Get.safeBack(),

        ),

        actions: [

          IconButton(

            icon: const Icon(Icons.person_add_rounded),

            tooltip: 'invite_friends'.tr,

            onPressed: InviteFriendsSheet.show,

          ),

        ],

        bottom: TabBar(

          key: TourTargetKeys.socialRequests,

          controller: _tabController,

          isScrollable: true,

          tabAlignment: TabAlignment.start,

          indicatorColor: AppColors.darkGold,

          labelColor: AppColors.darkGold,

          unselectedLabelColor:

              isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,

          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),

          tabs: [

            Tab(text: 'social_dashboard'.tr),

            Obx(() => Tab(

                  child: _badgedTab(

                      'incoming_requests'.tr, _controller.incomingRequests.length),

                )),

            Obx(() => Tab(

                  child: _badgedTab(

                      'outgoing_requests'.tr, _controller.outgoingRequests.length),

                )),

            Tab(text: 'my_friends_tab'.tr),

            Tab(text: 'search_users'.tr),

            if (_isAgent) Tab(text: 'users_chats_tab'.tr),

          ],

        ),

      ),

      body: TabBarView(

        controller: _tabController,

        physics: const BouncingScrollPhysics(),

        children: [

          _buildDashboardTab(),

          _buildIncomingTab(),

          _buildOutgoingTab(),

          _buildFriendsTab(),

          _buildSearchTab(),

          if (_isAgent) const AgentConversationsView(),

        ],

      ),

    );

  }



  Widget _badgedTab(String label, int count) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Text(label),

        if (count > 0) ...[

          const SizedBox(width: KasbySpacing.xs),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

            decoration: BoxDecoration(

              color: AppColors.error,

              borderRadius: BorderRadius.circular(10),

            ),

            child: Text(

              '$count',

              style: const TextStyle(

                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),

            ),

          ),

        ],

      ],

    );

  }



  Widget _buildDashboardTab() {

    return Obx(() {

      if (_controller.isLoading.value && _controller.suggestions.isEmpty) {

        return ListView.builder(

          padding: KasbyLayout.listPadding(context),

          itemCount: 4,

          itemBuilder: (_, __) =>

              const KasbyShimmer.listItem(margin: EdgeInsets.only(bottom: KasbySpacing.sm)),

        );

      }

      return RefreshIndicator(

        onRefresh: _controller.refreshAll,

        color: AppColors.darkGold,

        child: ListView(

          physics: const AlwaysScrollableScrollPhysics(),

          padding: KasbyLayout.listPadding(context),

          children: [

            Obx(() => KeyedSubtree(

                  key: TourTargetKeys.socialDashboard,

                  child: SocialDashboardHeader(stats: _controller.dashboardStats.value),

                )),

            const SizedBox(height: KasbySpacing.lg),

            Row(

              children: [

                Expanded(

                  child: Text('suggestions_tab'.tr,

                      style: const TextStyle(fontWeight: FontWeight.bold)),

                ),

                TextButton.icon(

                  onPressed: InviteFriendsSheet.show,

                  icon: const Icon(Icons.share_rounded, size: 18),

                  label: Text('invite_friends'.tr),

                ),

              ],

            ),

            const SizedBox(height: KasbySpacing.sm),

            Obx(() {

              if (_controller.suggestions.isEmpty) {

                return _emptyState('no_suggestions'.tr, Icons.person_search_rounded);

              }

              return Column(

                children: _controller.suggestions

                    .take(5)

                    .map((s) => _SuggestionTile(user: s))

                    .toList(),

              );

            }),

          ],

        ),

      );

    });

  }



  Widget _buildIncomingTab() {

    return RefreshIndicator(

      onRefresh: _controller.fetchIncomingRequests,

      color: AppColors.darkGold,

      child: Obx(() {

        if (_controller.isLoading.value && _controller.incomingRequests.isEmpty) {

          return _tabShimmer();

        }

        if (_controller.incomingRequests.isEmpty) {

          return ListView(

            physics: const AlwaysScrollableScrollPhysics(),

            padding: KasbyLayout.listPadding(context),

            children: [_emptyState('no_requests'.tr, Icons.inbox_rounded)],

          );

        }

        return ListView.builder(

          physics: const AlwaysScrollableScrollPhysics(),

          padding: KasbyLayout.listPadding(context),

          itemCount: _controller.incomingRequests.length,

          itemBuilder: (_, i) => FriendRequestCard(

            request: _controller.incomingRequests[i],

            animationIndex: i,

          ),

        );

      }),

    );

  }



  Widget _buildOutgoingTab() {

    return RefreshIndicator(

      onRefresh: _controller.fetchOutgoingRequests,

      color: AppColors.darkGold,

      child: Obx(() {

        if (_controller.isLoading.value && _controller.outgoingRequests.isEmpty) {

          return _tabShimmer();

        }

        if (_controller.outgoingRequests.isEmpty) {

          return ListView(

            physics: const AlwaysScrollableScrollPhysics(),

            padding: KasbyLayout.listPadding(context),

            children: [_emptyState('no_outgoing_requests'.tr, Icons.outbox_rounded)],

          );

        }

        return ListView.builder(

          physics: const AlwaysScrollableScrollPhysics(),

          padding: KasbyLayout.listPadding(context),

          itemCount: _controller.outgoingRequests.length,

          itemBuilder: (_, i) => FriendRequestCard(

            request: _controller.outgoingRequests[i],

            animationIndex: i,

          ),

        );

      }),

    );

  }



  Widget _buildFriendsTab() {

    return Column(

      children: [

        _buildSearchBar(_friendsFilterController, 'search_friends'.tr),

        Expanded(

          child: RefreshIndicator(

            onRefresh: _controller.fetchFriends,

            color: AppColors.darkGold,

            child: Obx(() {

              if (_controller.isLoading.value && _controller.friends.isEmpty) {

                return _tabShimmer();

              }



              final query = _friendsFilterController.text.toLowerCase();

              final filtered = query.isEmpty

                  ? _controller.friends

                  : _controller.friends

                      .where((f) => f.fullName.toLowerCase().contains(query))

                      .toList();



              if (filtered.isEmpty) {

                return ListView(

                  padding: KasbyLayout.listPadding(context),

                  children: [

                    _emptyState('no_friends_found'.tr, Icons.people_outline_rounded),

                  ],

                );

              }



              return ListView.separated(

                physics: const AlwaysScrollableScrollPhysics(),

                padding: KasbyLayout.listPadding(context),

                itemCount: filtered.length,

                separatorBuilder: (_, __) =>

                    const SizedBox(height: KasbyLayout.listItemGap),

                itemBuilder: (_, i) {

                  final card = FriendCard(friend: filtered[i], animationIndex: i);

                  if (i == 0) {

                    return KeyedSubtree(key: TourTargetKeys.socialFriends, child: card);

                  }

                  return card;

                },

              );

            }),

          ),

        ),

      ],

    );

  }



  Widget _buildSearchTab() {

    return Column(

      children: [

        KeyedSubtree(

          key: TourTargetKeys.socialInvite,

          child: _buildSearchBar(_userSearchController, 'search_users_hint'.tr),

        ),

        Expanded(

          child: Obx(() {

            if (_controller.isSearching.value) {

              return Center(

                  child: CircularProgressIndicator(color: AppColors.darkGold));

            }

            if (_userSearchController.text.trim().length < 2) {

              return _emptyState('search_users_min_chars'.tr, Icons.search_rounded);

            }

            if (_controller.searchResults.isEmpty) {

              return _emptyState('no_users_found'.tr, Icons.person_off_rounded);

            }

            return ListView.separated(

              padding: KasbyLayout.listPadding(context),

              itemCount: _controller.searchResults.length,

              separatorBuilder: (_, __) =>

                  const SizedBox(height: KasbyLayout.listItemGap),

              itemBuilder: (_, i) => _SuggestionTile(

                user: _controller.searchResults[i],

                animationIndex: i,

              ),

            );

          }),

        ),

      ],

    );

  }



  Widget _tabShimmer() {

    return ListView.builder(

      padding: KasbyLayout.listPadding(context),

      itemCount: 5,

      itemBuilder: (_, __) =>

          const KasbyShimmer.listItem(margin: EdgeInsets.only(bottom: KasbySpacing.sm)),

    );

  }



  Widget _buildSearchBar(TextEditingController controller, String hint) {

    return Padding(

      padding: const EdgeInsets.fromLTRB(

        KasbySpacing.lg,

        KasbySpacing.sm,

        KasbySpacing.lg,

        0,

      ),

      child: TextField(

        controller: controller,

        onChanged: (_) => setState(() {}),

        style: TextStyle(color: isDark ? Colors.white : AppColors.textBodyLight),

        decoration: InputDecoration(

          hintText: hint,

          isDense: true,

          prefixIcon: Icon(Icons.search_rounded, color: AppColors.darkGold, size: 20),

          filled: true,

          fillColor: isDark ? AppColors.surface : AppColors.surfaceLight,

          border: OutlineInputBorder(

            borderRadius: KasbyRadius.inputR,

            borderSide: BorderSide(

              color: AppColors.textSecondary.withValues(alpha: 0.2),

            ),

          ),

          enabledBorder: OutlineInputBorder(

            borderRadius: KasbyRadius.inputR,

            borderSide: BorderSide(

              color: AppColors.textSecondary.withValues(alpha: 0.15),

            ),

          ),

          contentPadding: const EdgeInsets.symmetric(

            horizontal: KasbySpacing.md,

            vertical: KasbySpacing.sm,

          ),

        ),

      ),

    );

  }



  Widget _emptyState(String text, IconData icon) {

    return Padding(

      padding: const EdgeInsets.only(top: KasbySpacing.giant),

      child: Center(

        child: Column(

          children: [

            Icon(icon, size: 52, color: AppColors.textSecondary.withValues(alpha: 0.4)),

            const SizedBox(height: KasbySpacing.md),

            Text(text, style: TextStyle(color: AppColors.textSecondary)),

          ],

        ),

      ),

    );

  }

}



class _SuggestionTile extends StatelessWidget {

  const _SuggestionTile({required this.user, this.animationIndex = 0});



  final SocialUserModel user;

  final int animationIndex;



  @override

  Widget build(BuildContext context) {

    final controller = SocialNetworkController.to;

    final isSent = controller.sentRequestIds.contains(user.id);

    final isDark = Theme.of(context).brightness == Brightness.dark;



    return Container(

      margin: const EdgeInsets.only(bottom: KasbySpacing.sm),

      padding: const EdgeInsets.all(KasbySpacing.md),

      decoration: BoxDecoration(

        color: isDark ? AppColors.surface : Colors.white,

        borderRadius: KasbyRadius.cardR,

        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.12)),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),

            blurRadius: 6,

            offset: const Offset(0, 2),

          ),

        ],

      ),

      child: Row(

        children: [

          SocialAvatar(

            name: user.fullName,

            avatarUrl: user.avatarUrl,

            userId: user.id,

            lastSeenAt: user.lastSeenAt,

            radius: 22,

          ),

          const SizedBox(width: KasbySpacing.md),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(user.fullName,

                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),

                if (user.username != null)

                  Text('@${user.username}',

                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),

                if (user.mutualFriends > 0)

                  Text(

                    'mutual_friends_count'.trParams({'count': '${user.mutualFriends}'}),

                    style: TextStyle(color: AppColors.darkGold, fontSize: 11),

                  ),

              ],

            ),

          ),

          if (user.isFriend)

            Icon(Icons.check_circle, color: AppColors.softGreen, size: 22)

          else if (isSent)

            TextButton(

              onPressed: () {

                FriendRequestModel? outgoing;

                for (final r in controller.outgoingRequests) {

                  if (r.userId == user.id) {

                    outgoing = r;

                    break;

                  }

                }

                if (outgoing != null) controller.cancelRequest(outgoing);

              },

              child: Text('cancel'.tr, style: TextStyle(color: AppColors.error, fontSize: 12)),

            )

          else

            FilledButton(

              onPressed: () => controller.sendFriendRequest(user.id),

              style: FilledButton.styleFrom(

                backgroundColor: AppColors.darkGold,

                foregroundColor: Colors.black,

                minimumSize: const Size(0, 32),

                padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.md),

              ),

              child: Text('add_friend'.tr, style: const TextStyle(fontSize: 12)),

            ),

        ],

      ),

    );

  }

}



