import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Brief edge brackets communicate health loss without hiding the arena.
class DamageFeedback extends PositionComponent
    with HasGameReference<RegunGame> {
  DamageFeedback() : super(priority: 100000);
  double remaining = 0;
  void trigger() => remaining = .24;
  void reset() => remaining = 0;
  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState == GameplayState.playing) {
      remaining = (remaining - dt).clamp(0, .24);
    }
  }

  @override
  void render(Canvas canvas) {
    if (remaining <= 0) return;
    final size = game.camera.viewport.virtualSize;
    final ink = Paint()
      ..color = const Color(0xffEF8B76).withValues(alpha: remaining / .24 * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = game.preferences.reducedMotion ? 3 : 5;
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        final x = right ? size.x - 14 : 14.0, y = bottom ? size.y - 14 : 14.0;
        final dx = right ? -1.0 : 1.0, dy = bottom ? -1.0 : 1.0;
        canvas.drawPath(
            Path()
              ..moveTo(x + dx * 55, y)
              ..lineTo(x, y)
              ..lineTo(x, y + dy * 45),
            ink);
      }
    }
  }
}
