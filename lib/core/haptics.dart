// Vibration helper, gated on the user's Settings "Vibration" toggle.
// Thin wrapper over HapticFeedback so game events stay one-liners.
import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  /// Mirrors ProgressState.vibration; synced by each screen's build().
  static bool enabled = true;

  static void _buzz(Future<void> Function() f) {
    if (!enabled) return;
    try {
      f();
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
    }
  }

  static void light() => _buzz(HapticFeedback.lightImpact);
  static void medium() => _buzz(HapticFeedback.mediumImpact);
  static void heavy() => _buzz(HapticFeedback.heavyImpact);
}
