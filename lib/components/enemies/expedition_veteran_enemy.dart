import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/ariet_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/expedition.dart';

/// Smaller successors carry a recognizable attack into the following region.
class ExpeditionVeteranEnemy extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ExpeditionVeteranEnemy(this.kind, {required super.position})
    : assert(kind != ExpeditionVeteran.miniWalker),
      super(size: Vector2.all(144), anchor: Anchor.center);

  final ExpeditionVeteran kind;
  bool get _gunship => kind == ExpeditionVeteran.miniAriet;
  double get bodyRadius => _gunship ? 50 : 43;
  late final ArietRig _rig;
  late final SpriteAnimationComponent _demon;
  Vector2? _target;
  double _clock = 1;

  static const _scoutScale = .37;
  Offset get _scoutMuzzle => _rig.cannonSocket * _scoutScale;

  @override
  double get impactResponse => .5;

  @override
  void onLoad() {
    initializeHealth(_gunship ? 36 : 32);
    if (_gunship) {
      _rig = ArietRig()..hoverMotion = true;
    } else {
      _demon = SpriteAnimationComponent(
        animation: BossArt.walk(BossKind.demon),
        size: size.clone(),
        position: size / 2,
        anchor: Anchor.center,
      );
      add(_demon);
    }
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
    final range = _gunship ? 580.0 : 205.0;
    final clear = !game.segmentBlocked(position, player);
    if (_target == null && (delta.length > range * .84 || !clear)) {
      game.moveActor(
        this,
        delta.normalized(),
        _gunship ? 122 : 130,
        dt,
        radius: bodyRadius,
      );
    }
    if (_gunship) {
      final heading = (_target ?? player) - position;
      _rig.desiredYaw = math.atan2(heading.y, heading.x);
      _rig.reducedMotion = game.preferences.reducedMotion;
      _rig.advance(dt);
    } else {
      final facing = (_target ?? player).x - position.x;
      if (facing.abs() > 1 && _demon.isFlippedHorizontally != (facing < 0)) {
        _demon.flipHorizontallyAroundCenter();
      }
      _demon.paint.colorFilter =
          damagePaint?.colorFilter ?? BossArt.ambient(game.currentArena);
    }

    _clock -= dt;
    if (_clock > 0) return;
    if (_target case final target?) {
      if (_gunship) {
        final muzzle = position + Vector2(_scoutMuzzle.dx, _scoutMuzzle.dy);
        if (!game.segmentBlocked(position, muzzle)) {
          final heading = (target - muzzle).normalized();
          for (final spread in [-.15, 0.0, .15]) {
            game.world.add(
              Enemy3Projectile(
                position: muzzle.clone(),
                direction: heading.clone()..rotate(spread),
                speed: 590,
                damage: game.expedition?.enemyDamage(heavy: true) ?? 2,
                cause: 'Ariet scout volley',
              ),
            );
          }
          game.playEnemyMovement('sentry_fire.wav', muzzle, 900);
        }
      }
      _target = null;
      _clock = _gunship ? 1.7 : 1.4;
      if (!_gunship) _demon.animation = BossArt.walk(BossKind.demon);
    } else if (delta.length < range && clear) {
      _target = player.clone();
      _clock = _gunship ? .62 : .96;
      if (!_gunship) {
        _demon.animation = BossArt.clip(BossKind.demon, [8, 9, 10], .96);
        game.addHostileArea(
          _target!.clone(),
          radius: 113,
          warning: .8,
          active: .24,
          damage: game.expedition?.enemyDamage(heavy: true) ?? 2,
          cause: 'Mini Demon slam',
          ownerHealth: combatHealth,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (combatHealth.isDead || !_gunship) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    if (_target case final target?) {
      AttackVfx.lightning(
        canvas,
        _scoutMuzzle,
        (target - position).toOffset(),
        .28,
        reducedMotion: game.preferences.reducedMotion,
      );
    }
    canvas.scale(_scoutScale);
    ArietArt(
      game.expeditionArietAssets,
      flashFilter: damagePaint?.colorFilter,
    ).paint(canvas, _rig);
    canvas.restore();
  }

  @override
  void onCombatDeath() {
    game.showGroundImpact(position.toOffset(), strength: 8, attenuate: true);
    removeFromParent();
  }
}
