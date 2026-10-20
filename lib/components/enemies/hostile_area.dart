import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/presentation/attack_vfx.dart';
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
      : super(priority: 9000);
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
    AttackVfx.disk(canvas, Offset.zero, radius,
        warning: age < warning,
        progress: age < warning
            ? (age / warning).clamp(0, 1)
            : ((age - warning) / active).clamp(0, 1),
        material: poison
            ? AttackMaterial.poison
            : cause == 'Foundry vent'
                ? AttackMaterial.ember
                : AttackMaterial.stone);
  }
}
