import 'package:flame/components.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class CombatEffect extends PositionComponent with HasGameReference<RegunGame> {
  CombatEffect(
      {required super.position,
      this.endpoint,
      this.remains,
      this.flipRemains = false,
      this.radius = 90,
      this.material = AttackMaterial.stone,
      this.color = const Color(0xffE3BF83),
      this.duration = 0.25})
      : super(priority: material == AttackMaterial.ember &&
              endpoint == null && remains == null ? -10 : 20010);
  final Vector2? endpoint;
  final Sprite? remains;
  final bool flipRemains;
  final double radius, duration;
  final Color color;
  final AttackMaterial material;
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
      canvas.save();
      if (flipRemains) canvas.scale(-1, 1);
      remains!.render(canvas,
          size: Vector2(radius * 2, radius * 2 * remains!.srcSize.y / remains!.srcSize.x),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..color = Colors.white
                .withValues(alpha: (1 - age / duration).clamp(0, 1)));
      canvas.restore();
      return;
    }
    if (endpoint != null) {
      final end = (endpoint! - position).toOffset();
      AttackVfx.lightning(
          canvas, Offset.zero, end, (1 - age / duration).clamp(0, 1),
          heavy: true);
    } else if (material == AttackMaterial.ember) {
      AttackVfx.explosion(canvas, Offset.zero, radius,
          progress: (age / duration).clamp(0, 1),
          ambient: BossArt.ambient(game.loadout.arena),
          reducedMotion: game.preferences.reducedMotion);
    } else {
      AttackVfx.disk(canvas, Offset.zero, radius,
          warning: false,
          progress: game.preferences.reducedMotion
              ? .35
              : (age / duration).clamp(0, 1),
          material: material);
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
    AttackVfx.disk(canvas, Offset.zero, 90,
        warning: false,
        progress: (age / 2.5).clamp(0, 1),
        material: AttackMaterial.ember);
  }
}
