import 'package:regun/components/weapons/weapon_impact.dart';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';

class HostileArea extends PositionComponent with HasGameReference<RegunGame> {
  HostileArea(
      {required super.position,
      this.radius = 130,
      this.warning = 0.9,
      this.active = 0.25,
      this.damage = 1,
      this.cause = 'Ground strike',
      this.poison = false,
      this.ownerHealth})
      : super(priority: 30000);
  final double radius, warning, active;
  final int damage;
  final String cause;
  final bool poison;
  final CombatHealth? ownerHealth;
  double age = 0;
  bool _impacted = false;
  @override
  void onRemove() {
    game.unregisterHazard(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ownerHealth?.isDead ?? false) {
      removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    age += dt;
    if (age >= warning + active) {
      removeFromParent();
      return;
    }
    if (!_impacted && age >= warning) {
      _impacted = true;
      game.addCombatEffect(HeavyImpact(
          position: position.clone(), radius: radius * .8, poison: poison));
      game.audio.play(poison ? 'impact_poison.wav' : 'impact_boss.wav');
    }
    if (age >= warning &&
        position.distanceToSquared(game.myPlayer.position) < radius * radius) {
      game.damagePlayer(amount: damage, cause: cause);
    }
  }

  @override
  void render(Canvas canvas) {
    final live = age >= warning;
    final color = poison ? const Color(0xffB2BB78) : const Color(0xffDD947A);
    canvas.drawCircle(Offset.zero, radius,
        Paint()..color = color.withValues(alpha: live ? 0.32 : 0.08));
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = live ? 4 : 2;
    canvas.drawCircle(Offset.zero, radius, line);
    // Interrupted border and center marks make the warning readable without hue.
    for (var i = 0; i < 12; i++) {
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius - 8),
          i * pi / 6, pi / 12, false, line);
    }
    if (!live) {
      canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius * 0.35),
          -pi / 2,
          (age / warning).clamp(0, 1) * pi * 2,
          false,
          line);
    }
  }
}
