import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/social/domain/models/friend_model.dart';
import 'package:kasby/features/social/domain/models/friend_request_model.dart';
import 'package:kasby/features/social/domain/models/social_dashboard_stats.dart';
import 'package:kasby/features/social/domain/models/social_user_model.dart';

class SocialRepository {
  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'success': false, 'error': 'invalid_response'};
  }

  Future<List<FriendRequestModel>> getIncomingRequests() async {
    final result = _asMap(await SupabaseService.client.rpc('get_friend_requests'));
    if (result['success'] != true) return [];
    return List<Map<String, dynamic>>.from(result['requests'] ?? [])
        .map((m) => FriendRequestModel.fromMap(m, outgoing: false))
        .toList();
  }

  Future<List<FriendRequestModel>> getOutgoingRequests() async {
    final result =
        _asMap(await SupabaseService.client.rpc('get_outgoing_friend_requests'));
    if (result['success'] != true) return [];
    return List<Map<String, dynamic>>.from(result['requests'] ?? [])
        .map((m) => FriendRequestModel.fromMap(m, outgoing: true))
        .toList();
  }

  Future<List<FriendModel>> getFriends() async {
    final result = _asMap(await SupabaseService.client.rpc('get_friends'));
    if (result['success'] != true) return [];
    return List<Map<String, dynamic>>.from(result['friends'] ?? [])
        .map(FriendModel.fromMap)
        .toList();
  }

  Future<List<SocialUserModel>> getSuggestions({int limit = 20}) async {
    final result = _asMap(
      await SupabaseService.client.rpc(
        'get_friend_suggestions',
        params: {'p_limit': limit},
      ),
    );
    if (result['success'] != true) return [];
    return List<Map<String, dynamic>>.from(result['suggestions'] ?? [])
        .map(SocialUserModel.fromMap)
        .toList();
  }

  Future<({List<SocialUserModel> users, int total})> searchUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final result = _asMap(
      await SupabaseService.client.rpc(
        'search_social_users',
        params: {
          'p_query': query,
          'p_limit': limit,
          'p_offset': offset,
        },
      ),
    );
    if (result['success'] != true) {
      return (users: <SocialUserModel>[], total: 0);
    }
    final users = List<Map<String, dynamic>>.from(result['users'] ?? [])
        .map(SocialUserModel.fromMap)
        .toList();
    return (users: users, total: result['total'] as int? ?? users.length);
  }

  Future<SocialDashboardStats> getDashboardStats() async {
    final result =
        _asMap(await SupabaseService.client.rpc('get_social_dashboard_stats'));
    if (result['success'] != true) return const SocialDashboardStats();
    return SocialDashboardStats.fromMap(result);
  }

  Future<Map<String, dynamic>> sendFriendRequest(String receiverId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'send_friend_request',
        params: {'p_receiver_id': receiverId},
      ),
    );
  }

  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'accept_friend_request',
        params: {'p_request_id': requestId},
      ),
    );
  }

  Future<Map<String, dynamic>> rejectRequest(String requestId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'reject_friend_request',
        params: {'p_request_id': requestId},
      ),
    );
  }

  Future<Map<String, dynamic>> cancelRequest(String receiverId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'cancel_friend_request',
        params: {'p_receiver_id': receiverId},
      ),
    );
  }

  Future<Map<String, dynamic>> removeFriend(String friendId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'remove_friend',
        params: {'p_friend_id': friendId},
      ),
    );
  }

  Future<Map<String, dynamic>> startSocialChat(String friendId) async {
    return _asMap(
      await SupabaseService.client.rpc(
        'start_social_chat',
        params: {'p_friend_id': friendId},
      ),
    );
  }
}
