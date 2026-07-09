import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/supabase_service.dart';

/// Fetches real agents linked to user accounts (not orphan/placeholder rows).
class AgentService {
  AgentService._();

  /// Agents available for deposit/withdrawal assignment (online + active).
  /// Excludes the currently authenticated user so agents never see themselves.
  static Future<List<AgentModel>> fetchActiveAgents({int limit = 20}) async {
    final currentUserId = SupabaseService.userId;

    var query = SupabaseService.client
        .from('agents')
        .select('*, profiles(*)')
        .eq('status', 'active')
        .eq('is_available_now', true)
        .not('user_id', 'is', null);

    if (currentUserId != null) {
      query = query.neq('user_id', currentUserId);
    }

    final response = await query
        .order('last_active_at', ascending: false)
        .limit(limit);

    return _mapAgents(response);
  }

  /// All active agents (includes offline) for browsing.
  /// Excludes the currently authenticated user at the query level.
  static Future<List<AgentModel>> fetchAllActiveAgents({int limit = 50}) async {
    final currentUserId = SupabaseService.userId;

    var query = SupabaseService.client
        .from('agents')
        .select('*, profiles(*)')
        .eq('status', 'active')
        .not('user_id', 'is', null);

    if (currentUserId != null) {
      query = query.neq('user_id', currentUserId);
    }

    final response = await query
        .order('is_available_now', ascending: false)
        .order('last_active_at', ascending: false)
        .limit(limit);

    return _mapAgents(response);
  }

  static List<AgentModel> _mapAgents(dynamic response) {
    return (response as List)
        .map((json) => AgentModel.fromJson(json))
        .where((agent) => agent.userId != null && agent.name.trim().isNotEmpty)
        .toList();
  }
}
