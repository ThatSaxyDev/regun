import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class CombatEffect extends PositionComponent with HasGameReference<RegunGame> {
  CombatEffect(
      {required super.position,
      this.endpoint,
      this.remains,
      this.radius = 90,
      this.color = const Color(0xffE3BF83),
      this.duration = 0.25})
      : super(priority: 20010);
  final Vector2? endpoint;
  final Sprite? remains;
  final double radius, duration;
  final Color color;
  double age = 0;
  @override
  void onRemove() {
    game.unregisterEffect(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    age += dt;
    if (age >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (remains != null) {
      remains!.render(canvas,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..color = Colors.white
                .withValues(alpha: (1 - age / duration).clamp(0, 1)));
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - age / duration).clamp(0, 1))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (endpoint != null) {
      final end = (endpoint! - position).toOffset();
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(end.dx * 0.35, end.dy * 0.35 + 12)
        ..lineTo(end.dx * 0.6, end.dy * 0.6 - 12)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawCircle(
          Offset.zero,
          radius *
              (game.preferences.reducedMotion ? 1 : 0.5 + age / duration * 0.5),
          paint);
    }
  }
}

class BurningGround extends PositionComponent with HasGameReference<RegunGame> {
  BurningGround({required super.position, this.damage = 0.8})
      : super(priority: -10);
  final double damage;
  double age = 0, tick = 0;
  @override
  void onRemove() {
    game.unregisterFire(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    age += dt;
    tick += dt;
    if (age >= 2.5) removeFromParent();
    if (tick >= 0.5) {
      tick = 0;
      for (final enemy in game.liveEnemies.toList()) {
        if (enemy.position.distanceToSquared(position) < 90 * 90) {
          game.hitEnemy(enemy, damage, primary: false);
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
        Offset.zero, 90, Paint()..color = const Color(0x397E4635));
    canvas.drawCircle(
        Offset.zero,
        85,
        Paint()
          ..color = const Color(0xffBE825A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }
}
