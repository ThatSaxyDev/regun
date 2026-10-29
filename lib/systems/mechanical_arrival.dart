import 'dart:math' as math;

import 'package:flame/components.dart';

/// Arrival-only camera clock. It never follows a corpse or replays on Continue.
class MechanicalArrival {
  PositionComponent? actor;
  final cameraFrom = Vector2.zero();
  double elapsed = 0, zoomFrom = 1, combatZoom = 1, arrivalTime = 0;
  bool reduced = false;
  bool get active => actor != null;
  double get duration => arrivalTime + .65;
  void begin(
    PositionComponent target,
    Vector2 camera,
    double zoom, {
    required double targetZoom,
    required double arrivalDuration,
    required bool reducedMotion,
  }) {
    actor = target;
    cameraFrom.setFrom(camera);
    zoomFrom = zoom;
    combatZoom = targetZoom;
    arrivalTime = arrivalDuration;
    reduced = reducedMotion;
    elapsed = 0;
  }

  bool advance(double dt, {required bool ready}) {
    if (!active) return true;
    if (actor!.isRemoving || actor!.isRemoved) {
      reset();
      return true;
    }
    if (!ready || !dt.isFinite || dt <= 0) return false;
    elapsed = math.min(duration, elapsed + dt);
    return elapsed >= duration;
  }

  static double ease(double t) {
    t = t.clamp(0, 1);
    return t * t * (3 - 2 * t);
  }

  double get zoom => reduced
      ? combatZoom
      : zoomFrom + (combatZoom - zoomFrom) * ease(elapsed / .65);
  Vector2 camera(Vector2 player, Vector2 focus) {
    if (reduced) return player.clone();
    if (elapsed < .65) {
      return cameraFrom + (focus - cameraFrom) * ease(elapsed / .65);
    }
    if (elapsed < arrivalTime) return focus.clone();
    return focus + (player - focus) * ease((elapsed - arrivalTime) / .65);
  }

  void reset() {
    actor = null;
    elapsed = 0;
  }
}
