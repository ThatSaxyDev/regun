import 'dart:math';
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
      canvas.drawCircle(Offset.zero, radius * .7, ink..strokeWidth = 1.5);
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
    final ink = Paint()
      ..color = (poison ? const Color(0xffB6C87D) : const Color(0xffE6AA7B))
          .withValues(alpha: (1 - t) * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - t) + 1;
    canvas.drawCircle(Offset.zero, r, ink);
    for (var i = 0; i < 7; i++) {
      final a = i * pi * 2 / 7;
      final d = Offset(cos(a), sin(a));
      final p = Path()
        ..moveTo(d.dx * r * .3, d.dy * r * .3)
        ..lineTo(d.dx * r * .65 - d.dy * 6, d.dy * r * .65 + d.dx * 6)
        ..lineTo(d.dx * r, d.dy * r);
      canvas.drawPath(p, ink);
    }
  }
}
