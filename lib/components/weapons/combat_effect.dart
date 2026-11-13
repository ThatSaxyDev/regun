import 'package:flame/components.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class CombatEffect extends PositionComponent with HasGameReference<RegunGame> {
  CombatEffect({
    required super.position,
    this.endpoint,
    bool floorEffect = false,
    this.upgradePulse = false,
    this.signatureImpact = false,
    this.signatureHeal = false,
    this.companion = false,
    this.perkChain = false,
    this.dashDirection,
    this.dashLaunch = false,
    this.remains,
    this.flipRemains = false,
    this.remainsOpacity = 1,
    this.radius = 90,
    this.material = AttackMaterial.stone,
    this.color = const Color(0xffE3BF83),
    this.duration = 0.25,
  }) : super(
         priority:
             floorEffect ||
                 remains != null ||
                 upgradePulse ||
                 dashDirection != null ||
                 material == AttackMaterial.ember &&
                     endpoint == null &&
                     remains == null
             ? -10
             : 20010,
       );
  final bool upgradePulse,
      companion,
      perkChain,
      dashLaunch,
      signatureImpact,
      signatureHeal;
  final double remainsOpacity;
  final Vector2? dashDirection;
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
    if (dashDirection != null) {
      AttackVfx.dashDust(
        canvas,
        Offset.zero,
        dashDirection!.toOffset(),
        progress: (age / duration).clamp(0, 1),
        ambient: BossArt.ambient(game.loadout.arena),
        launch: dashLaunch,
        reducedMotion: game.preferences.reducedMotion,
      );
      return;
    }
    if (signatureHeal) {
      final p = (age / duration).clamp(0.0, 1.0);
      final rise = game.preferences.reducedMotion ? 12.0 : p * 38;
      const color = Color(0xffb5ce9b);
      for (final (x, y) in const [(-24.0, 6.0), (17.0, -4.0), (0.0, -20.0)]) {
        final at = Offset(x, y - rise);
        final ink = color.withValues(alpha: 1 - p);
        AttackVfx.chip(canvas, at, 7, ink);
        for (final d in const [
          Offset(6, 0),
          Offset(-6, 0),
          Offset(0, 6),
          Offset(0, -6),
        ]) {
          AttackVfx.chip(canvas, at + d, 4, ink);
        }
      }
      return;
    }
    if (upgradePulse) {
      AttackVfx.upgradePulse(
        canvas,
        Offset.zero,
        radius,
        progress: (age / duration).clamp(0, 1),
        reducedMotion: game.preferences.reducedMotion,
      );
      return;
    }
    if (remains != null) {
      canvas.save();
      if (flipRemains) canvas.scale(-1, 1);
      remains!.render(
        canvas,
        size: Vector2(
          radius * 2,
          radius * 2 * remains!.srcSize.y / remains!.srcSize.x,
        ),
        anchor: Anchor.center,
        overridePaint: Paint()
          ..color = Colors.white.withValues(
            alpha: remainsOpacity * (1 - age / duration).clamp(0, 1),
          ),
      );
      canvas.restore();
      return;
    }
    if (endpoint != null) {
      final end = (endpoint! - position).toOffset();
      if (companion) {
        AttackVfx.companionLightning(
          canvas,
          Offset.zero,
          end,
          (1 - age / duration).clamp(0, 1),
        );
        return;
      }
      AttackVfx.lightning(
        canvas,
        Offset.zero,
        end,
        (1 - age / duration).clamp(0, 1),
        heavy: true,
        perk: perkChain,
        contact: true,
        reducedMotion: game.preferences.reducedMotion,
      );
    } else if (signatureImpact) {
      final progress = (age / duration).clamp(0.0, 1.0);
      final reduced = game.preferences.reducedMotion;
      final p = reduced ? .30 : progress;
      final frame = material == AttackMaterial.glass ? 5 : 1;
      AttackVfx.floorArea(
        canvas,
        frame,
        Offset.zero,
        radius * 2,
        alpha: (1 - progress) * .85,
      );
      for (final (x, y) in const [(-.44, -.23), (.42, -.25), (.15, .24)]) {
        AttackVfx.stamp(
          canvas,
          AttackVfx.row(material) * 6 + (p * 4).floor(),
          Offset(x * radius, y * radius),
          radius * .58,
          alpha: 1 - progress,
          material: material,
        );
      }
    } else if (material == AttackMaterial.ember) {
      AttackVfx.explosion(
        canvas,
        Offset.zero,
        radius,
        progress: (age / duration).clamp(0, 1),
        ambient: BossArt.ambient(game.loadout.arena),
        reducedMotion: game.preferences.reducedMotion,
      );
    } else {
      AttackVfx.disk(
        canvas,
        Offset.zero,
        radius,
        ambient: BossArt.ambient(game.loadout.arena),
        warning: false,
        progress: game.preferences.reducedMotion
            ? .35
            : (age / duration).clamp(0, 1),
        material: material,
      );
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
        if (game.targetDistance(enemy, position, body: 0) < 90 &&
            game.targetVisible(enemy, position)) {
          game.hitEnemy(
            enemy,
            damage * game.burnMultiplier(enemy),
            primary: false,
          );
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    AttackVfx.disk(
      canvas,
      Offset.zero,
      90,
      ambient: BossArt.ambient(game.loadout.arena),
      warning: false,
      progress: (age / 2.5).clamp(0, 1),
      material: AttackMaterial.ember,
    );
  }
}
