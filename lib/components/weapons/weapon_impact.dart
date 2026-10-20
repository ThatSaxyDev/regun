import 'dart:math';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/weapon_feel.dart';

/// Fixed-cost strokes, not emitted particle entities. Uses the existing FX cap.
class WeaponImpact extends CombatEffect {
  WeaponImpact(
      {required super.position,
      required this.weapon,
      required Vector2 direction})
      : direction = direction.clone(),
        super(duration: .22);
  final WeaponType weapon;
  final Vector2 direction;
  @override
  void render(Canvas canvas) {
    final feel = WeaponFeel.of(weapon);
    final t = (age / duration).clamp(0.0, 1.0);
    final reduced = game.preferences.reducedMotion;
    final radius = feel.impact * (reduced ? .55 : .35 + t * .65);
    final ink = Paint()
      ..color = feel.color.withValues(alpha: 1 - t)
      ..strokeWidth = weapon == WeaponType.carbine ? 1.5 : 2.5
      ..strokeCap = StrokeCap.square;
    canvas.save();
    canvas.rotate(atan2(direction.y, direction.x));
    final count = weapon == WeaponType.carbine ? 3 : 6;
    for (var i = 0; i < count; i++) {
      final a = (i / (count - 1) - .5) * pi * 1.15;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(d * (radius * .35), d * radius, ink);
    }
    if (weapon == WeaponType.arcCaster) {
      final path = Path()
        ..moveTo(-radius, 0)
        ..lineTo(-radius * .3, -radius * .3)
        ..lineTo(radius * .15, radius * .25)
        ..lineTo(radius, 0);
      ink.style = PaintingStyle.stroke;
      canvas.drawPath(path, ink);
      AttackVfx.lightning(canvas, Offset(-radius, 0), Offset(radius, 0), 1 - t,
          heavy: true);
    } else if (weapon == WeaponType.revolver) {
      canvas.drawLine(Offset(-radius * .8, 0), Offset(radius * .6, 0),
          ink..strokeWidth = 4);
    }
    if (t < .35) {
      canvas.drawRect(const Rect.fromLTWH(-3, -3, 6, 6),
          Paint()..color = const Color(0xffFFF1CF));
    }
    canvas.restore();
  }
}

class HeavyImpact extends CombatEffect {
  HeavyImpact(
      {required super.position, super.radius = 110, this.poison = false})
      : super(duration: .34);
  final bool poison;
  @override
  void render(Canvas canvas) {
    final t = (age / duration).clamp(0.0, 1.0);
    final r = radius * (game.preferences.reducedMotion ? .75 : .5 + t * .5);
    canvas.save();
    canvas.scale(1 - t * .12);
    AttackVfx.disk(canvas, Offset.zero, r,
        warning: false,
        progress: t,
        material: poison ? AttackMaterial.poison : AttackMaterial.ember);
    canvas.restore();
  }
}
