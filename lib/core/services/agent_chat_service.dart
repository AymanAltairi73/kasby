import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Starts or resumes a user ↔ agent chat via Supabase RPC.
class AgentChatService {
  AgentChatService._();

  static const String _rpcName = 'fn_start_agent_chat';

  static Future<AgentChatStartResult> startChat({
    required String agentRecordId,
    String? agentUserId,
    String? agentName,
  }) async {
    final stopwatch = Stopwatch()..start();
    final currentUserId = SupabaseService.userId;
    final params = {'p_agent_id': agentRecordId};

    SafeGetx.debugTrace(
      className: 'AgentChatService',
      method: 'startChat',
      feature: 'AgentChat',
      status: 'INFO',
      message: 'Starting agent chat RPC',
      params: {
        'rpc': _rpcName,
        'p_agent_id': agentRecordId,
        'currentUserId': currentUserId,
        'agentUserId': agentUserId,
        'agentName': agentName,
      },
    );

    if (currentUserId == null) {
      return AgentChatStartResult.failure(
        error: 'login_required'.tr,
        rpcName: _rpcName,
        params: params,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (agentUserId != null && agentUserId == currentUserId) {
      return AgentChatStartResult.failure(
        error: 'agent_chat_self_not_allowed'.tr,
        rpcName: _rpcName,
        params: params,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        _rpcName,
        params: params,
      );

      final parsed = response is Map
          ? Map<String, dynamic>.from(response)
          : null;

      SafeGetx.debugTrace(
        className: 'AgentChatService',
        method: 'startChat',
        feature: 'AgentChat',
        status: parsed?['success'] == true ? 'SUCCESS' : 'WARN',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {
          'rpc': _rpcName,
          'responseSuccess': parsed?['success'],
          'responseError': parsed?['error'],
          'conversationId': parsed?['conversation'] is Map
              ? (parsed!['conversation'] as Map)['id']
              : null,
        },
      );

      if (parsed == null) {
        return AgentChatStartResult.failure(
          error: 'chat_connection_error'.tr,
          rpcName: _rpcName,
          params: params,
          rawResponse: response,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      if (parsed['success'] != true) {
        return AgentChatStartResult.failure(
          error: parsed['error']?.toString() ?? 'chat_connection_error'.tr,
          rpcName: _rpcName,
          params: params,
          rawResponse: parsed,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final conversation = parsed['conversation'];
      if (conversation is! Map) {
        return AgentChatStartResult.failure(
          error: 'chat_connection_error'.tr,
          rpcName: _rpcName,
          params: params,
          rawResponse: parsed,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'RPC succeeded but conversation payload missing',
        );
      }

      final conversationMap = Map<String, dynamic>.from(conversation);
      final conversationId = conversationMap['id']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        return AgentChatStartResult.failure(
          error: 'chat_connection_error'.tr,
          rpcName: _rpcName,
          params: params,
          rawResponse: parsed,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'RPC succeeded but conversation id missing',
        );
      }

      return AgentChatStartResult.success(
        conversationId: conversationId,
        conversation: conversationMap,
        agentUserId: agentUserId,
        agentName: agentName,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on PostgrestException catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentChatService',
        method: 'startChat',
        feature: 'AgentChat',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
        params: {
          'rpc': _rpcName,
          'p_agent_id': agentRecordId,
          'currentUserId': currentUserId,
          'pgCode': e.code,
          'pgMessage': e.message,
          'pgDetails': e.details,
        },
      );
      return AgentChatStartResult.failure(
        error: e.message,
        rpcName: _rpcName,
        params: params,
        exception: e,
        stackTrace: stack,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentChatService',
        method: 'startChat',
        feature: 'AgentChat',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
        params: {
          'rpc': _rpcName,
          'p_agent_id': agentRecordId,
          'currentUserId': currentUserId,
        },
      );
      return AgentChatStartResult.failure(
        error: e.toString(),
        rpcName: _rpcName,
        params: params,
        exception: e,
        stackTrace: stack,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}

class AgentChatStartResult {
  final bool success;
  final String? conversationId;
  final Map<String, dynamic>? conversation;
  final String? agentUserId;
  final String? agentName;
  final String? error;
  final String? rpcName;
  final Map<String, dynamic>? rpcParams;
  final Object? exception;
  final StackTrace? stackTrace;
  final int? durationMs;

  const AgentChatStartResult._({
    required this.success,
    this.conversationId,
    this.conversation,
    this.agentUserId,
    this.agentName,
    this.error,
    this.rpcName,
    this.rpcParams,
    this.exception,
    this.stackTrace,
    this.durationMs,
  });

  factory AgentChatStartResult.success({
    required String conversationId,
    required Map<String, dynamic> conversation,
    String? agentUserId,
    String? agentName,
    int? durationMs,
  }) {
    return AgentChatStartResult._(
      success: true,
      conversationId: conversationId,
      conversation: conversation,
      agentUserId: agentUserId,
      agentName: agentName,
      durationMs: durationMs,
    );
  }

  factory AgentChatStartResult.failure({
    required String error,
    required String rpcName,
    Map<String, dynamic>? params,
    Object? rawResponse,
    Object? exception,
    StackTrace? stackTrace,
    String? message,
    int? durationMs,
  }) {
    return AgentChatStartResult._(
      success: false,
      error: message != null ? '$error ($message)' : error,
      rpcName: rpcName,
      rpcParams: params,
      exception: exception ?? rawResponse,
      stackTrace: stackTrace,
      durationMs: durationMs,
    );
  }
}
