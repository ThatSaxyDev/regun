import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/presentation/animation_playback.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class PlayerComponent extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  PlayerComponent({super.position, this.playerRadius = 25})
      : super(
            priority: 10,
            size: Vector2.all(playerRadius * 4),
            anchor: Anchor.center);

  final double playerRadius;
  static const collisionRadius = 30.0;
  final List<SpriteAnimation> _idle = [], _run = [];
  final List<SpriteAnimation> _dash = [], _brace = [], _hurt = [];
  int _facingRow = 0;
  final lastMovement = Vector2(1, 0);
  final dashDirection = Vector2(1, 0);
  final aimDirection = Vector2(1, 0);
  double recoil = 0, hurtFlash = 0;
  double _trailClock = 0;

  @override
  Future<void> onLoad() async {
    final atlas = 'characters/${game.loadout.character.name}';
    for (var row = 0; row < 4; row++) {
      _idle
          .add(RegunArt.shared.animation(atlas, row: row, count: 2, step: 0.3));
      _run.add(RegunArt.shared
          .survivorRun(game.loadout.character.name, facing: row));
      _dash.add(
          RegunArt.shared.animation('${atlas}_actions', row: row, count: 1));
      _brace.add(RegunArt.shared
          .animation('${atlas}_actions', row: row, from: 1, count: 1));
      _hurt.add(RegunArt.shared
          .animation('${atlas}_actions', row: row, from: 2, count: 1));
    }
    animation = _idle[0];
    add(CircleHitbox(
        radius: collisionRadius,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);
    priority = 10000 + (position.y + size.y * .38).round();
    if (game.playerEntrance.active) {
      animation =
          game.playerEntrance.landing ? _brace[_facingRow] : _idle[_facingRow];
      recoil = 0;
      hurtFlash = 0;
      return;
    }
    final movement = game.movementJoystick.relativeDelta;
    final aim = game.weaponJoystick.relativeDelta;
    if (!aim.isZero()) aimDirection.setFrom(aim.normalized());
    recoil = max(0, recoil - dt / WeaponFeel.of(game.loadout.weapon).recovery);
    hurtFlash = max(0, hurtFlash - dt);
    final facing = aim.isZero() ? movement : aim;
    if (!facing.isZero()) {
      _facingRow = facing.x.abs() > facing.y.abs()
          ? (facing.x < 0 ? 2 : 0)
          : (facing.y > 0 ? 1 : 3);
    }
    final moving = !movement.isZero();
    final nextAnimation = game.boostButtonComponent.tapped
        ? _dash[_facingRow]
        : hurtFlash > .12
            ? _hurt[_facingRow]
            : (!moving && recoil > .5)
                ? _brace[_facingRow]
                : moving
                    ? _run[_facingRow]
                    : _idle[_facingRow];
    if (_run.contains(animation) && _run.contains(nextAnimation)) {
      switchLoopFacing(this, nextAnimation);
    } else {
      animation = nextAnimation;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    if (!movement.isZero()) lastMovement.setFrom(movement.normalized());
    _trailClock += dt;
    if (!movement.isZero() &&
        game.preferences.profile.cosmetic == 'endless' &&
        !game.preferences.reducedMotion &&
        _trailClock > .12) {
      _trailClock = 0;
      game.addCombatEffect(CombatEffect(
          position: position.clone(),
          radius: 8,
          duration: .25,
          color: const Color(0xffD5BA75)));
    }

    if (game.boostButtonComponent.tapped) {
      game.moveActor(this, dashDirection, 1300, dt, radius: collisionRadius);
    } else {
      game.moveActor(this, movement, game.gameState.movementSpeed, dt,
          radius: collisionRadius);
    }
    // Direct geometric bounds also handle large dash steps and corner sliding.
    game.constrainActor(position, collisionRadius);
  }

  @override
  // The sprite's super.render is invoked by _renderSurvivor inside the layer.
  // ignore: must_call_super
  void render(Canvas canvas) {
    final entrance = game.playerEntrance;
    if (!entrance.active) {
      _renderSurvivor(canvas);
      return;
    }
    if (entrance.atCenter) {
      final foot = Offset(size.x / 2, size.y * .83);
      canvas.drawOval(Rect.fromCenter(center: foot, width: 42, height: 12),
          Paint()..color = const Color(0x650C1113));
      final settle =
          ((entrance.elapsed - entrance.landingStart - entrance.dropDuration) /
                  .45)
              .clamp(0.0, 1.0);
      AttackVfx.stamp(canvas, 5, foot + const Offset(0, 12), 140,
          alpha: (.2 + entrance.drop * .4) * (1 - settle));
      if (entrance.drop >= .9) {
        for (final side in [-1, 1]) {
          AttackVfx.stamp(canvas, settle < .4 ? 3 : 4,
              foot + Offset(side * (18 + settle * 45), 12), 95 + settle * 35,
              alpha: .65 * (1 - settle));
        }
      }
    }
    if (entrance.bodyOpacity <= 0) return;
    canvas.saveLayer(null,
        Paint()..color = Color.fromRGBO(255, 255, 255, entrance.bodyOpacity));
    canvas.translate(0, entrance.fallen ? 0 : -entrance.height);
    _renderSurvivor(canvas);
    canvas.restore();
  }

  void _renderSurvivor(Canvas canvas) {
    final style = game.preferences.profile.cosmetic;
    final tint = switch (style) {
      'copper' => const Color(0xffE9BD92),
      'moss' => const Color(0xffCAD8A3),
      'ivory' => const Color(0xffFFF4DC),
      'shadowPalette' => const Color(0xffD7B8EA),
      'emberPalette' => const Color(0xffF2B58C),
      'engineer' => const Color(0xffF2D28D),
      _ => null,
    };
    paint.colorFilter = hurtFlash > .17 && !game.preferences.reducedMotion
        ? const ColorFilter.mode(Color(0xffFFF0DB), BlendMode.srcATop)
        : tint == null
            ? null
            : ColorFilter.mode(tint, BlendMode.modulate);
    if (!game.playerEntrance.active) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(size.x * .5, size.y * .83), width: 42, height: 12),
          Paint()..color = const Color(0x650C1113));
    }
    if (game.gameState.gameplayState == GameplayState.gameOver ||
        game.playerEntrance.fallen) {
      RegunArt.shared
          .sprite('characters/${game.loadout.character.name}_actions',
              _facingRow * 4 + 3)
          .render(canvas, size: size, overridePaint: paint);
      return;
    }
    void weapon() {
      canvas.save();
      canvas.translate(
          size.x * .5 + aimDirection.x * 8, size.y * .56 + aimDirection.y * 8);
      canvas.rotate(atan2(aimDirection.y, aimDirection.x));
      if (aimDirection.x < 0) canvas.scale(1, -1);
      paintWeapon(canvas, game.loadout.weapon,
          reload: game.gameNotifier.quickRefillProgress.value >= 0
              ? (game.preferences.reducedMotion
                  ? 1
                  : game.gameNotifier.quickRefillProgress.value)
              : game.gameState.reloading
                  ? game.gameNotifier.reloadProgress.value
                  : -1,
          recoil: recoil,
          reloadShells: game.gameState.maxBullets - game.gameState.noOfBullets,
          reducedMotion: game.preferences.reducedMotion);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-11, -2, 7, 7), const Radius.circular(2)),
          Paint()..color = const Color(0xff454A43));
      canvas.restore();
    }

    if (aimDirection.y < -.35) weapon();
    super.render(canvas);
    if (aimDirection.y >= -.35) weapon();
    if (style == 'queenTrophy') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(Rect.fromLTWH(35 + i * 7, 10 - (i == 1 ? 4 : 0), 5, 8),
            Paint()..color = const Color(0xffE3C480));
      }
    } else if (style == 'veteran' ||
        style == 'scorpionCharm' ||
        style == 'eliteHunter' ||
        style == 'survivor') {
      canvas.drawRect(
          const Rect.fromLTWH(31, 40, 8, 8),
          Paint()
            ..color = style == 'survivor'
                ? const Color(0xffAABDE0)
                : const Color(0xffD5BA75));
    }
    if (style == 'veteran') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(Rect.fromLTWH(30, 44 + i * 4, 10, 2),
            Paint()..color = const Color(0xffD5BA75));
      }
    } else if (style == 'scorpionCharm') {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(26 + i * 2, 56 - i * 3, 3, 3),
            Paint()..color = const Color(0xffA4AE76));
      }
    } else if (style == 'eliteHunter') {
      canvas.drawRect(const Rect.fromLTWH(32, 39, 3, 14),
          Paint()..color = const Color(0xffD5BA75));
    }
    if (hurtFlash > 0) {
      for (final dx in [-1, 1]) {
        AttackVfx.stroke(
            canvas,
            [
              Offset(size.x / 2 + dx * 26, size.y / 2 - 13),
              Offset(size.x / 2 + dx * 33, size.y / 2),
              Offset(size.x / 2 + dx * 26, size.y / 2 + 13)
            ],
            const Color(0xffD7A69C),
            4);
      }
    }
    if (game.gameState.guard) {
      AttackVfx.armour(canvas, (size / 2).toOffset(), 35);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is EnemyComponent &&
        !other.isRemoving &&
        game.damagePlayer(cause: 'Scorpion')) {
      // Contact hurts the player; it does not bypass enemy health.
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    if (other is CoinComponent && !other.isCollected) {
      other.isCollected = true;
      other.removeFromParent();
      game.audio.play('coinSound2.wav');
      game.gameNotifier.increaseXP(other.value);
    } else if (other is Enemy3Projectile || other is ShadowProjectile) {
      if (other.isRemoving) return;
      other.removeFromParent();
      game.damagePlayer(
          cause: other is ShadowProjectile ? 'Shadow bolt' : 'Revenant shot');
    }
  }
}
