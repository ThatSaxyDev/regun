import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';

/// One simulation-clock choreography for deployment and training recovery.
/// The world waits; pause/background freezes the same timeline.
class PlayerEntrance {
  bool active = false, respawning = false, reduced = false;
  double elapsed = 0;
  final cameraFrom = Vector2.zero();
  final landingPosition = Vector2.zero();
  double get fall => respawning ? (reduced ? .25 : .5) : 0;
  double get pan => respawning ? (reduced ? .25 : 1.0) : 0;
  double get landingStart => fall + pan + .2;
  double get dropDuration => reduced ? .25 : .55;
  double get duration => landingStart + dropDuration + .45;
  bool get atCenter => elapsed >= fall + pan;
  bool get fallen => respawning && elapsed < fall;
  bool get landing =>
      elapsed >= landingStart && elapsed < landingStart + dropDuration + .2;
  double get drop => ((elapsed - landingStart) / dropDuration).clamp(0, 1);
  double get bodyOpacity => fallen
      ? (1 - elapsed / fall).clamp(0, 1)
      : !atCenter
      ? 0
      : drop;
  double get height => reduced ? 0 : 150 * (1 - drop * drop);
  double get cameraProgress {
    final t = ((elapsed - fall) / math.max(.001, pan)).clamp(0.0, 1.0);
    return reduced ? (t < .5 ? 0 : 1) : t * t * (3 - 2 * t);
  }

  void begin({
    required bool respawn,
    required bool reducedMotion,
    required Vector2 camera,
    Vector2? target,
  }) {
    active = true;
    respawning = respawn;
    reduced = reducedMotion;
    elapsed = 0;
    cameraFrom.setFrom(camera);
    landingPosition.setFrom(target ?? Vector2.zero());
  }

  void cancel() {
    active = false;
  }

  void advance(double dt) {
    elapsed = math.min(duration, elapsed + dt);
  }
}

/// Reduced-motion camera relocation happens under a brief charcoal curtain;
/// ordinary deployment uses the world-space dust and survivor poses instead.
class EntranceVeil extends PositionComponent with HasGameReference<RegunGame> {
  EntranceVeil() : super(priority: 1000000);
  @override
  void render(Canvas canvas) {
    final entrance = game.playerEntrance;
    if (!entrance.active || !entrance.respawning || !entrance.reduced) return;
    final alpha = entrance.elapsed < entrance.fall
        ? entrance.elapsed / entrance.fall
        : entrance.atCenter
        ? 1 - entrance.drop
        : 1.0;
    canvas.drawRect(
      Offset.zero & game.camera.viewport.virtualSize.toSize(),
      Paint()..color = Color.fromRGBO(20, 17, 23, alpha.clamp(0, 1)),
    );
  }
}
