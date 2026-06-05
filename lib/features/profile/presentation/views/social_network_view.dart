import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kasby/routes/app_routes.dart';

class SocialNetworkView extends StatefulWidget {
  const SocialNetworkView({super.key});

  @override
  State<SocialNetworkView> createState() => _SocialNetworkViewState();
}

class _SocialNetworkViewState extends State<SocialNetworkView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // Data from server
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _suggestions = [];

  bool _isLoadingRequests = true;
  bool _isLoadingFriends = true;
  bool _isLoadingSuggestions = true;

  // Track sent requests to update UI optimistically
  final Set<String> _sentRequestIds = {};
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchRequests(),
      _fetchFriends(),
      _fetchSuggestions(),
    ]);
  }

  Future<void> _fetchRequests() async {
    try {
      final result = await SupabaseService.client.rpc('get_friend_requests');
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response['requests'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _fetchFriends() async {
    try {
      final result = await SupabaseService.client.rpc('get_friends');
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(response['friends'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _fetchSuggestions() async {
    try {
      final result = await SupabaseService.client.rpc('get_friend_suggestions');
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(response['suggestions'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Future<void> _acceptRequest(String requestId, int index) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));

    try {
      final result = await SupabaseService.client.rpc(
        'accept_friend_request',
        params: {'p_request_id': requestId},
      );
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        HapticFeedback.mediumImpact();
        final accepted = _requests[index];
        setState(() {
          _requests.removeAt(index);
          _friends.insert(0, {
            'id': accepted['requester_id'],
            'full_name': accepted['full_name'],
            'avatar_url': accepted['avatar_url'],
            'referral_code': accepted['referral_code'],
          });
        });
        Get.snackbar(
          'success'.tr,
          'request_accepted'.tr,
          backgroundColor: AppColors.softGreen.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _rejectRequest(String requestId, int index) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));

    try {
      final result = await SupabaseService.client.rpc(
        'reject_friend_request',
        params: {'p_request_id': requestId},
      );
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() => _requests.removeAt(index));
        HapticFeedback.lightImpact();
        Get.snackbar(
          'success'.tr,
          'request_rejected'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    if (_sentRequestIds.contains(receiverId)) return;
    setState(() => _sentRequestIds.add(receiverId));

    try {
      final result = await SupabaseService.client.rpc(
        'send_friend_request',
        params: {'p_receiver_id': receiverId},
      );
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        HapticFeedback.lightImpact();
        Get.snackbar(
          'success'.tr,
          'friend_request_sent'.tr,
          backgroundColor: AppColors.softGreen.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );

        if (response['auto_accepted'] == true) {
          // Move from suggestions to friends
          final idx = _suggestions.indexWhere((s) => s['id'] == receiverId);
          if (idx != -1) {
            final user = _suggestions[idx];
            setState(() {
              _suggestions.removeAt(idx);
              _friends.insert(0, user);
            });
          }
        }
      } else {
        // Revert on error
        setState(() => _sentRequestIds.remove(receiverId));
        Get.snackbar(
          'error'.tr,
          response['error'] ?? 'حدث خطأ',
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setState(() => _sentRequestIds.remove(receiverId));
      debugPrint('Error sending request: $e');
    }
  }

  Future<void> _cancelRequest(String receiverId) async {
    if (_processingIds.contains(receiverId)) return;
    setState(() => _processingIds.add(receiverId));

    try {
      final result = await SupabaseService.client.rpc(
        'cancel_friend_request',
        params: {'p_receiver_id': receiverId},
      );
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() {
          _sentRequestIds.remove(receiverId);
        });
        HapticFeedback.lightImpact();
        Get.snackbar(
          'success'.tr,
          'request_cancelled'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling request: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(receiverId));
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final index = _friends.indexWhere((f) => f['id'] == friendId);
    if (index == -1) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('remove_friend'.tr),
        content: Text('confirm_remove_friend'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('remove_friend'.tr, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(friendId));
    try {
      final result = await SupabaseService.client.rpc(
        'remove_friend',
        params: {'p_friend_id': friendId},
      );
      final response = result as Map<String, dynamic>;
      if (response['success'] == true) {
        setState(() => _friends.removeAt(index));
        HapticFeedback.mediumImpact();
        Get.snackbar(
          'success'.tr,
          'friend_removed'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );
        _fetchSuggestions(); // Refresh suggestions as they might reappear
      }
    } catch (e) {
      debugPrint('Error removing friend: $e');
    } finally {
      if (mounted) setState(() => _processingIds.remove(friendId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('social_network'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.darkGold,
          labelColor: AppColors.darkGold,
          unselectedLabelColor:
              isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('social_network_tab'.tr),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'my_friends_tab'.tr),
            Tab(text: 'suggestions_tab'.tr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildFriendsTab(),
          _buildSuggestionsTab(),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _fetchRequests,
      color: AppColors.darkGold,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _buildInviteSection(),
          const SizedBox(height: 24),
          if (_isLoadingRequests)
            ...List.generate(5, (index) => const KasbyShimmer.listItem(margin: EdgeInsets.only(bottom: 12)))
          else if (_requests.isEmpty)
            _buildEmptyRequestsState()
          else
            ..._requests.asMap().entries.map((entry) {
              final index = entry.key;
              final request = entry.value;
              return _buildRequestItem(index, request);
            }),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    final filteredFriends = _friends
        .where((f) => f['full_name'].toString().toLowerCase().contains(_searchQuery))
        .toList();

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchFriends,
            color: AppColors.darkGold,
            child: _isLoadingFriends
                ? ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const KasbyShimmer.listItem(),
                  )
                : filteredFriends.isEmpty
                    ? _buildEmptyState('no_friends_found'.tr, Icons.people_outline_rounded)
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredFriends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final friend = filteredFriends[index];
                          return _buildFriendItem(friend);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsTab() {
    final filteredSuggestions = _suggestions
        .where((s) => s['full_name'].toString().toLowerCase().contains(_searchQuery))
        .toList();

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchSuggestions,
            color: AppColors.darkGold,
            child: _isLoadingSuggestions
                ? ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const KasbyShimmer.listItem(),
                  )
                : filteredSuggestions.isEmpty
                    ? _buildEmptyState('no_suggestions'.tr, Icons.person_search_rounded)
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredSuggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final suggestion = filteredSuggestions[index];
                          return _buildSuggestionItem(suggestion, index);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textBodyLight,
        ),
        decoration: InputDecoration(
          hintText: 'search_friends'.tr,
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
          ),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: AppColors.darkGold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 60, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                text,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRequestsState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 60, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'no_requests'.tr,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    final referralCode = HomeController.to.profile.value?.referralCode ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkGold.withValues(alpha: 0.15),
            AppColors.darkGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'invite_friends'.tr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'invite_friends_desc'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'https://kasby.app/join?ref=$referralCode'));
                  HapticFeedback.lightImpact();
                  Get.snackbar(
                    'success'.tr,
                    'تم نسخ رابط الدعوة',
                    backgroundColor: AppColors.softGreen.withValues(alpha: 0.8),
                    colorText: Colors.white,
                  );
                },
                icon: Icon(Icons.copy, color: AppColors.darkGold),
              ),
              IconButton(
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'انضم إلى كاسبي! استخدم كود الإحالة: $referralCode\nhttps://kasby.app/join?ref=$referralCode',
                    ),
                  );
                },
                icon: Icon(Icons.share_rounded, color: AppColors.darkGold),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildRequestItem(int index, Map<String, dynamic> request) {
    final requestId = request['request_id'] as String;
    final isProcessing = _processingIds.contains(requestId);

    return KasbyCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            _buildAvatar(request['full_name'] ?? '?', request['avatar_url']),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request['full_name'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (request['referral_code'] != null)
                    Text(
                      request['referral_code'],
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (isProcessing)
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkGold))
            else
              Row(
                children: [
                  _CircularButton(
                    icon: Icons.check,
                    color: AppColors.softGreen,
                    onTap: () => _acceptRequest(requestId, index),
                  ),
                  const SizedBox(width: 8),
                  _CircularButton(
                    icon: Icons.close,
                    color: AppColors.error,
                    onTap: () => _rejectRequest(requestId, index),
                  ),
                ],
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX();
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final index = _friends.indexWhere((f) => f['id'] == friend['id']);
    return KasbyCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            _buildAvatar(friend['full_name'] ?? '?', friend['avatar_url']),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend['full_name'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (friend['referral_code'] != null)
                    Text(
                      friend['referral_code'],
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.darkGold, size: 22),
              onPressed: () {
                Get.toNamed(
                  Routes.socialChat,
                  arguments: {
                    'friendId': friend['id'],
                    'friendName': friend['full_name'] ?? 'مستخدم',
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _removeFriend(friend['id'] as String),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion, int index) {
    final userId = suggestion['id'] as String;
    final isSent = _sentRequestIds.contains(userId);

    return KasbyCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            _buildAvatar(suggestion['full_name'] ?? '?', suggestion['avatar_url']),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion['full_name'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (suggestion['referral_code'] != null)
                    Text(
                      suggestion['referral_code'],
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            isSent
                ? InkWell(
                    onTap: () => _cancelRequest(userId),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'cancel'.tr,
                        style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : InkWell(
                    onTap: () => _sendFriendRequest(userId),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'add_friend'.tr,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
  }

  Widget _buildAvatar(String name, String? avatarUrl) {
    final initials = _getInitials(name);
    return CircleAvatar(
      radius: 25,
      backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? NetworkImage(avatarUrl)
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: AppColors.darkGold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _CircularButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircularButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
