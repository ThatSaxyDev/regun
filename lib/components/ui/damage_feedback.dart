import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// A single fading hit cue keeps the center and aiming controls readable.
class DamageFeedback extends PositionComponent
    with HasGameReference<RegunGame> {
  DamageFeedback() : super(priority: 100000);
  static const duration = .5;
  final healthLost = ValueNotifier<int>(0);
  double remaining = 0;
  void trigger({required int amount}) {
    remaining = duration;
    healthLost.value = amount;
  }

  void reset() {
    remaining = 0;
    healthLost.value = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState == GameplayState.playing) {
      remaining = (remaining - dt).clamp(0, duration);
      if (remaining == 0) healthLost.value = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (remaining <= 0) return;
    final size = game.camera.viewport.virtualSize;
    final fade = (remaining / .32).clamp(0.0, 1.0);
    final reduced = game.preferences.reducedMotion;
    const red = Color(0xffEF8B76);
    // Pixel steps follow the HUD's framing; no full-screen flash or camera kick.
    for (var step = 0; step < 4; step++) {
      final inset = step * 7.0;
      final paint = Paint()
        ..color = red.withValues(
          alpha: fade * (reduced ? .045 : .09) * (1 - step / 4),
        );
      canvas.drawRect(
        Rect.fromLTWH(inset, inset, size.x - inset * 2, 7),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(inset, size.y - inset - 7, size.x - inset * 2, 7),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(inset, inset, 7, size.y - inset * 2),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.x - inset - 7, inset, 7, size.y - inset * 2),
        paint,
      );
    }
    final ink = Paint()
      ..color = const Color(0xffEF8B76).withValues(alpha: fade * .85)
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
          ink,
        );
      }
    }
  }
}
