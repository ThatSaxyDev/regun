import 'package:regun/presentation/boss_art.dart';

import 'dart:math';

import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/weapon_feel.dart';

/// Fixed-cost strokes, not emitted particle entities. Uses the existing FX cap.
class WeaponImpact extends CombatEffect {
  WeaponImpact({
    required super.position,
    required this.weapon,
    required Vector2 direction,
  }) : direction = direction.clone(),
       super(duration: .22);
  final WeaponType weapon;
  final Vector2 direction;
  @override
  void render(Canvas canvas) {
    final feel = WeaponFeel.of(weapon);
    final t = (age / duration).clamp(0.0, 1.0);
    final reduced = game.preferences.reducedMotion;
    final radius = feel.impact * (reduced ? .55 : .35 + t * .65);
    if (weapon == WeaponType.arcCaster) {
      AttackVfx.stamp(
        canvas,
        5,
        const Offset(0, 14),
        70,
        alpha: .4 * (1 - t),
        material: AttackMaterial.shadow,
      );
    }
    final ink = Paint()
      ..color = feel.color.withValues(alpha: 1 - t)
      ..strokeWidth = weapon == WeaponType.carbine ? 2.5 : 3.5
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
      AttackVfx.lightning(
        canvas,
        Offset(-radius, 0),
        Offset(radius, 0),
        1 - t,
        heavy: true,
      );
    } else if (weapon == WeaponType.revolver) {
      canvas.drawLine(
        Offset(-radius * .8, 0),
        Offset(radius * .6, 0),
        ink..strokeWidth = 4,
      );
    }
    if (t < .35) {
      final core = weapon == WeaponType.shotgun ? 11.0 : 8.0;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: core, height: core),
        Paint()..color = const Color(0xffFFF1CF),
      );
    }
    if (!reduced && weapon == WeaponType.shotgun) {
      for (final side in [-1, 1]) {
        AttackVfx.chip(
          canvas,
          Offset(radius * .65, side * radius * .55),
          5 * (1 - t),
          feel.color.withValues(alpha: 1 - t),
        );
      }
    }
    canvas.restore();
  }
}

class HeavyImpact extends CombatEffect {
  HeavyImpact({
    required super.position,
    super.radius = 110,
    this.poison = false,
  }) : super(duration: .34, floorEffect: true);
  final bool poison;
  @override
  void render(Canvas canvas) {
    final t = (age / duration).clamp(0.0, 1.0);
    final r = radius * (game.preferences.reducedMotion ? .75 : .5 + t * .5);
    canvas.save();
    canvas.scale(1 - t * .12);
    AttackVfx.disk(
      canvas,
      Offset.zero,
      r,
      ambient: BossArt.ambient(game.loadout.arena),
      warning: false,
      progress: t,
      material: poison ? AttackMaterial.poison : AttackMaterial.ember,
    );
    canvas.restore();
  }
}
