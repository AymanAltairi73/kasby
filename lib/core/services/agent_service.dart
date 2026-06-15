import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/supabase_service.dart';

/// Fetches real agents linked to user accounts (not orphan/placeholder rows).
class AgentService {
  AgentService._();

  static Future<List<AgentModel>> fetchActiveAgents({int limit = 20}) async {
    final response = await SupabaseService.client
        .from('agents')
        .select('*, profiles(*)')
        .eq('status', 'active')
        .not('user_id', 'is', null)
        .order('is_available_now', ascending: false)
        .order('last_active_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AgentModel.fromJson(json))
        .where((agent) => agent.userId != null && agent.name.trim().isNotEmpty)
        .toList();
  }
}
