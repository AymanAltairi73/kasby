import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kasby/core/services/supabase_service.dart';

/// Waits until a [GlobalKey] target is laid out — no arbitrary time delays.
class TourTargetReadiness {
  TourTargetReadiness._();

  static bool isReady(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return false;
    return box.size.width > 0 && box.size.height > 0;
  }

  /// Waits up to [maxFrames] rendered frames for [key] to become ready.
  static Future<bool> waitFor(GlobalKey key, {int maxFrames = 120}) async {
    if (isReady(key)) return true;

    for (var frame = 0; frame < maxFrames; frame++) {
      await _waitNextFrame();
      if (isReady(key)) return true;
    }
    return isReady(key);
  }

  /// Waits for the next rendered frame (no arbitrary time delays).
  static Future<void> waitNextFrame() => _waitNextFrame();

  /// Waits until the authenticated user id is available for tour storage keys.
  static Future<bool> waitForAuthenticatedUser({int maxFrames = 90}) async {
    if (SupabaseService.userId != null) return true;

    for (var frame = 0; frame < maxFrames; frame++) {
      await _waitNextFrame();
      if (SupabaseService.userId != null) return true;
    }
    return SupabaseService.userId != null;
  }

  static Future<void> _waitNextFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete();
      });
    });
    return completer.future;
  }
}
