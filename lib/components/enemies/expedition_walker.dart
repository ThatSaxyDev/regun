import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/ariet_escort_study.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/walker_rig.dart';

/// Independent mini Walker. It shares Ariet's escort art and chassis scale.
class ExpeditionWalker extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ExpeditionWalker({required super.position})
    : super(size: Vector2.all(205 * scaleFactor), anchor: Anchor.center);

  static const scaleFactor = ArietEscortStudy.combatScale;
  static const radius = 88 * scaleFactor;
  final _router = ObstacleRouter();
  late WalkerRig _rig;
  Vector2? _shot;
  double _clock = .9;

  Offset get _muzzle =>
      _rig.muzzle.projected * scaleFactor - position.toOffset();

  @override
  double get impactResponse => _veteran ? .42 : .7;
  bool get _veteran => (game.expedition?.generator ?? 0) >= 7;

  @override
  void onLoad() {
    initializeHealth(_veteran ? 35 : 12);
    final floor = game.map.bounds.interior;
    final bounds = Rect.fromLTRB(
      floor.left / scaleFactor,
      floor.top / scaleFactor,
      floor.right / scaleFactor,
      floor.bottom / scaleFactor,
    );
    _rig = WalkerRig(
      position: position.toOffset() / scaleFactor,
      maxSpeed: 385 / scaleFactor,
      acceleration: 1050 / scaleFactor,
      agileGait: true,
      agileStepTime: .18,
      agileLift: 12,
      bodyBounds: bounds.deflate(88),
      footBounds: bounds,
      moveResolver: (_, to) {
        game.moveTo(
          this,
          Vector2(to.dx, to.dy) * scaleFactor,
          radius,
          slide: true,
        );
        return position.toOffset() / scaleFactor;
      },
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.inputBlocked ||
        combatHealth.isDead ||
        freezeHeld ||
        impactHeld ||
        game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    priority = 10000 + position.y.round();
    final player = game.myPlayer.position;
    final delta = player - position;
    final clear = !game.segmentBlocked(position, player);
    final heading = delta.normalized();
    final intent = _shot != null || (delta.length < 355 && clear)
        ? Vector2.zero()
        : _router.steer(
            this,
            heading,
            player,
            game.geometry,
            radius: radius,
            side: combatId.isEven ? 1 : -1,
            dt: dt,
          );
    if ((_rig.position * scaleFactor - position.toOffset()).distance > .05) {
      _rig.carryTo(position.toOffset() / scaleFactor);
    }
    _rig.reducedMotion = game.preferences.reducedMotion;
    _rig.target = (_shot ?? player).toOffset() / scaleFactor;
    _rig.desiredYaw = math.atan2(delta.y, delta.x);
    _rig.command =
        intent.toOffset() *
        ((_veteran ? 320 : 265) *
            RegunGame.ordinaryEnemyPace *
            (game.expedition?.miniWalkerPursuitScale ?? 1) *
            impactStride /
            scaleFactor);
    _rig.advance(dt);
    _clock -= dt;
    if (_clock > 0) return;
    if (_shot case final aim?) {
      final muzzle = position + Vector2(_muzzle.dx, _muzzle.dy);
      if (!game.segmentBlocked(position, muzzle)) {
        final heading = (aim - muzzle).normalized();
        for (final spread in _veteran ? [-.10, 0.0, .10] : [0.0]) {
          game.world.add(
            Enemy3Projectile(
              position: muzzle.clone(),
              speed: _veteran ? 640 : 510,
              maxTravelDistance: 780,
              direction: heading.clone()..rotate(spread),
              cause: 'Mini Walker shot',
              damage: game.expedition?.enemyDamage(heavy: true) ?? 1,
            ),
          );
        }
        game.playEnemyMovement(
          _veteran ? 'sentry_fire.wav' : 'enemy3projectile.wav',
          muzzle,
          900,
        );
      }
      _shot = null;
      _clock = _veteran ? 1.35 : 1.65;
    } else if (clear && delta.length < 650 && delta.length > 55) {
      _shot = player.clone();
      _clock = .48;
    }
  }

  @override
  void onCombatDeath() {
    game.showGroundImpact(position.toOffset(), strength: 7, attenuate: true);
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (combatHealth.isDead) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    if (_shot case final aim?) {
      AttackVfx.lightning(
        canvas,
        _muzzle,
        (aim - position).toOffset(),
        .22,
        reducedMotion: game.preferences.reducedMotion,
      );
    }
    canvas.scale(scaleFactor);
    canvas.translate(-position.x / scaleFactor, -position.y / scaleFactor);
    WalkerArt(
      game.expeditionWalkerAssets,
      flashFilter: damagePaint?.colorFilter,
    ).paint(canvas, _rig);
    canvas.restore();
  }
}
