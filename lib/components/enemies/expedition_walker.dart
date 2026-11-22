import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/walker_boss.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/ariet_escort_study.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

/// Independent mini Walker. It shares Ariet's escort art and chassis scale.
class ExpeditionWalker extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ExpeditionWalker({required super.position})
    : super(size: Vector2.all(205 * scaleFactor), anchor: Anchor.center);

  static const scaleFactor = ArietEscortStudy.combatScale;
  static const radius = 88 * scaleFactor;
  static const wallClearance = 132 * scaleFactor;
  static const bossClearance = WalkerBoss.stanceRadius + radius + 16;
  static const _collapseTime = .38;
  static const _wreckTime = 1.45;
  final _router = ObstacleRouter();
  late WalkerRig _rig;
  Vector2? _shot;
  double _clock = .9;
  double _deathAge = 0;
  bool get shuttingDown => combatHealth.isDead && _deathAge < _collapseTime;

  @visibleForTesting
  Iterable<Offset> get footholds =>
      _rig.legs.map((leg) => leg.foot * scaleFactor);

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
      bodyBounds: bounds.deflate(wallClearance / scaleFactor),
      footBounds: bounds,
      footResolver: _clipFoot,
      moveResolver: (_, to) {
        game.moveTo(
          this,
          Vector2(to.dx, to.dy) * scaleFactor,
          radius,
          slide: true,
          clipStep: (from, to) {
            final boss = game.activeBoss;
            if (boss is! WalkerBoss || !boss.prepared || boss.fight.finished) {
              return to;
            }
            final offset = from - boss.position;
            if (offset.length2 < bossClearance * bossClearance) {
              return offset.dot(to - from) >= 0 ? to : from;
            }
            return WalkerCombat.segmentDistance(
                      boss.position.toOffset(),
                      from.toOffset(),
                      to.toOffset(),
                    ) <
                    bossClearance
                ? from
                : to;
          },
        );
        return position.toOffset() / scaleFactor;
      },
    )..plantAfterRush();
  }

  Offset _clipFoot(Offset hip, Offset foot) {
    final start = Vector2(hip.dx, hip.dy) * scaleFactor;
    final end = Vector2(foot.dx, foot.dy) * scaleFactor;
    final contact = game.geometry.firstSolidContact(start, end, padding: 14);
    return (contact ?? end).toOffset() / scaleFactor;
  }

  @override
  void onMount() {
    super.onMount();
    _syncRig();
  }

  void _syncRig() {
    if ((_rig.position * scaleFactor - position.toOffset()).distance <= .05) {
      return;
    }
    _rig.carryTo(position.toOffset() / scaleFactor);
    _rig.plantAfterRush();
  }

  Vector2? _avoidWalker(Vector2 player) {
    final boss = game.activeBoss;
    if (boss is! WalkerBoss || !boss.prepared || boss.fight.finished) {
      return null;
    }
    final outward = position - boss.position;
    final distance = outward.length;
    if (distance < .01) outward.setValues(combatId.isEven ? 1 : -1, 0);
    outward.normalize();
    if (distance < bossClearance) {
      final ahead = position + outward * 48;
      final legal = ahead.clone();
      game.geometry.constrain(legal, wallClearance);
      if (ahead.distanceToSquared(legal) < 1) return outward;
    } else if (WalkerCombat.segmentDistance(
              boss.position.toOffset(),
              position.toOffset(),
              player.toOffset(),
            ) >=
            bossClearance ||
        (player - position).dot(outward) > 0) {
      return null;
    }
    final tangent = Vector2(-outward.y, outward.x);
    final towardPlayer = (player - position).dot(tangent);
    final side = towardPlayer.abs() > 20
        ? towardPlayer.sign
        : combatId.isEven
        ? 1.0
        : -1.0;
    tangent.scale(side);
    final flank = (tangent + outward * .45).normalized();
    final trial = position + flank * 60;
    game.geometry.constrain(trial, wallClearance);
    return trial.distanceToSquared(position + flank * 60) < 4
        ? flank
        : (-tangent + outward * .45).normalized();
  }

  @override
  void update(double dt) {
    if (combatHealth.isDead) {
      if (game.inputBlocked ||
          game.gameState.gameplayState != GameplayState.playing) {
        return;
      }
      final previous = _deathAge;
      _deathAge += dt;
      if (!game.preferences.reducedMotion) {
        final progress = (_deathAge / _collapseTime).clamp(0.0, 1.0);
        _rig.height = 88 - 58 * progress * progress;
      }
      if (previous < _collapseTime && _deathAge >= _collapseTime) {
        game.addCombatEffect(
          CombatEffect(
            position: position.clone(),
            radius: 96,
            duration: .52,
            material: AttackMaterial.ember,
          ),
        );
        game.playEnemyMovement('blast.wav', position, 780);
      }
      if (_deathAge >= _wreckTime) removeFromParent();
      return;
    }
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
    final flank = _avoidWalker(player);
    final clear = flank == null && !game.segmentBlocked(position, player);
    if (flank != null && _shot != null) {
      _shot = null;
      _clock = .45;
    }
    final heading = delta.normalized();
    final intent =
        flank ??
        (_shot != null || (delta.length < 355 && clear)
            ? Vector2.zero()
            : _router.steer(
                this,
                heading,
                player,
                game.geometry,
                radius: wallClearance,
                side: combatId.isEven ? 1 : -1,
                dt: dt,
              ));
    _syncRig();
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
    for (final leg in _rig.legs) {
      leg.foot = _clipFoot(_rig.ground(leg.mount), leg.foot);
    }
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
    _shot = null;
    game.crowdOccupancy.forget(this);
    game.showGroundImpact(position.toOffset(), strength: 7, attenuate: true);
    game.playEnemyMovement('reload_carbine_1.wav', position, 720);
  }

  @override
  void render(Canvas canvas) {
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
    final art = WalkerArt(
      game.expeditionWalkerAssets,
      flashFilter: damagePaint?.colorFilter,
    );
    if (combatHealth.isDead && !shuttingDown) {
      art.part(
        canvas,
        'wreck',
        _rig.position,
        218,
        angle: _rig.yaw,
        alpha: ((_wreckTime - _deathAge) / .32).clamp(0, 1),
      );
    } else {
      art.paint(canvas, _rig);
    }
    canvas.restore();
  }
}
