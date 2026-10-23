import 'package:regun/components/enemies/ground_projection.dart';
import 'package:regun/presentation/boss_vfx.dart';
import 'package:regun/components/weapons/weapon_impact.dart';

import 'dart:math';

import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

enum PatternBossPhase { arrival, approach, warning, active, recovery }

class PatternBoss extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements BossEncounter {
  PatternBoss(this.kind, {super.position, this.maximumHealth = 230})
    : super(size: Vector2.all(200), anchor: Anchor.center, priority: 5);
  @override
  final BossKind kind;
  final double maximumHealth;
  PatternBossPhase phase = PatternBossPhase.arrival;
  double clock = 0;
  int pattern = 0, _sequence = 0;
  bool _committed = false;
  final _target = Vector2.zero(),
      _origin = Vector2.zero(),
      _direction = Vector2(1, 0);
  final _zones = <Vector2>[];
  late SpriteAnimationComponent _body;
  late SpriteAnimation _walk, _idle;
  @override
  bool get isBoss => true;
  @override
  bool get enraged => combatHealth.fraction <= .5;
  @override
  int get xpReward => 20;
  @override
  int get scoreReward => 1000;
  bool get _charge => kind == BossKind.demon && pattern == 2;
  double get warningDuration => enraged ? .8 : 1.0;
  double get activeDuration => _charge ? .65 : .8;
  double get zoneRadius => kind == BossKind.demon
      ? 180
      : pattern == 0
      ? 170
      : 145;

  late final GroundProjection _ground;

  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    _ground = GroundProjection(this, renderGround);
    game.world.add(_ground);
    add(
      CircleHitbox(
        radius: kind.bodyRadius,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
    _walk = BossArt.walk(kind);
    _idle = BossArt.idle(kind);
    _body = SpriteAnimationComponent(
      size: Vector2.all(kind.spriteSize),
      position: Vector2(size.x * .5, size.y * .85 - .38 * kind.spriteSize),
      anchor: Anchor.center,
      animation: _idle,
    );
    add(_body);
    _body.paint.colorFilter = BossArt.ambient(game.loadout.arena);
  }

  void _enter(PatternBossPhase next) {
    if (next == PatternBossPhase.recovery) game.releaseBossAttack(this);
    phase = next;
    clock = 0;
    _committed = false;
    final start = 8 + pattern * 8;
    _body.animation = switch (next) {
      PatternBossPhase.warning => BossArt.clip(kind, [
        start,
        start + 1,
        start + 2,
        start + 3,
      ], warningDuration),
      PatternBossPhase.active => BossArt.clip(
        kind,
        BossArt.impactFrames(kind, pattern),
        activeDuration,
      ),
      PatternBossPhase.approach => _walk,
      _ => _idle,
    };
  }

  void _commit() {
    if (!game.claimBossAttack(this)) return;
    final distance = position.distanceTo(game.myPlayer.position);
    pattern = kind == BossKind.demon
        ? (distance > 400
              ? 2
              : distance < 330 && _sequence.isEven
              ? 0
              : 1)
        : _sequence % 3;
    _sequence++;
    _origin.setFrom(position);
    final lead =
        game.movementJoystick.relativeDelta * game.playerWalkSpeed * .7;
    if (lead.length > 240) lead.scale(240 / lead.length);
    _target.setFrom(game.myPlayer.position + lead);
    _direction.setFrom((_target - position).normalized());
    if (_direction.isZero()) _direction.setValues(1, 0);
    _zones.clear();
    if (_charge) {
      _target.setFrom(
        position + _direction * (distance + 800).clamp(900.0, 2200.0),
      );
      game.constrainActor(_target, 75);
    } else if (kind == BossKind.demon && pattern == 1 ||
        kind == BossKind.queen && pattern != 1) {
      final forward = lead.isZero() ? _direction : lead.normalized();
      final side = Vector2(-forward.y, forward.x);
      final offsets = kind == BossKind.queen && pattern == 2
          ? [Vector2.zero(), forward * 280, if (enraged) side * 280]
          : [Vector2.zero(), forward * 320, if (enraged) -side * 280];
      for (final offset in offsets) {
        final point = _target + offset;
        // Snapshot the exact constrained hit areas before showing their markers.
        game.constrainActor(point, zoneRadius);
        _zones.add(point);
      }
    }
    _body.scale.x = _direction.x < 0 ? -1 : 1;
    _enter(PatternBossPhase.warning);
  }

  void _impact() {
    game.audio.play('impact_boss.wav');
    if (kind == BossKind.demon && pattern == 0) {
      final delta = game.myPlayer.position - position;
      if (delta.length < 340 &&
          delta.normalized().dot(_direction) >= cos(1.75) &&
          !game.segmentBlocked(position, game.myPlayer.position)) {
        game.damagePlayer(amount: 2, cause: 'Demon cleave');
      }
      game.addCombatEffect(
        HeavyImpact(bossKind: kind, position: position.clone(), radius: 260),
      );
    } else if (kind == BossKind.queen && pattern == 1) {
      for (var i = 0; i < (enraged ? 4 : 3); i++) {
        game.spawnAdd(
          EnemyKind.runner,
          position + Vector2(cos(i * 2), sin(i * 2)) * 220,
        );
      }
      game.addHostileArea(
        game.myPlayer.position +
            game.movementJoystick.relativeDelta * game.playerWalkSpeed * .7,
        radius: 155,
        warning: 1.05,
        active: 1.3,
        poison: true,
        cause: 'Queen brood eruption',
        ownerHealth: combatHealth,
        bossKind: kind,
      );
      game.addCombatEffect(
        HeavyImpact(
          bossKind: kind,
          position: position.clone(),
          radius: 220,
          poison: true,
        ),
      );
    } else if (!_charge) {
      for (var i = 0; i < _zones.length; i++) {
        final poison = kind == BossKind.queen && pattern == 2;
        game.addHostileArea(
          _zones[i].clone(),
          radius: zoneRadius,
          warning: .04 + i * .18,
          active: poison ? 3.5 : .3,
          poison: poison,
          damage: poison ? 1 : 2,
          cause: kind == BossKind.demon
              ? 'Demon slam'
              : poison
              ? 'Queen poison'
              : 'Queen tail strike',
          ownerHealth: combatHealth,
          bossKind: kind,
        );
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (combatHealth.isDead ||
        game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    clock += dt;
    switch (phase) {
      case PatternBossPhase.arrival:
        if (clock >= 1.5) _enter(PatternBossPhase.approach);
      case PatternBossPhase.approach:
        final delta = game.myPlayer.position - position;
        final moving = delta.length > 185;
        _body.animation = moving ? _walk : _idle;
        if (delta.x.abs() > 20) _body.scale.x = delta.x < 0 ? -1 : 1;
        if (moving) {
          game.moveActor(
            this,
            delta.normalized(),
            kind == BossKind.demon
                ? (enraged ? 320 : 275)
                : (enraged ? 290 : 250),
            dt,
            radius: 75,
          );
        }
        if (clock >= (enraged ? .65 : 1.0)) _commit();
      case PatternBossPhase.warning:
        if (clock >= warningDuration) _enter(PatternBossPhase.active);
      case PatternBossPhase.active:
        if (_charge) {
          final before = position.clone();
          game.moveTo(
            this,
            _origin +
                (_target - _origin) * (clock / activeDuration).clamp(0, 1),
            75,
          );
          if (BulletComponent.segmentDistanceSquared(
                    game.myPlayer.position,
                    before,
                    position,
                  ) <
                  85 * 85 &&
              !game.segmentBlocked(before, game.myPlayer.position)) {
            game.damagePlayer(amount: 2, cause: 'Demon charge');
          }
        } else if (!_committed && clock >= .18) {
          _committed = true;
          _impact();
        }
        if (clock >= activeDuration) _enter(PatternBossPhase.recovery);
      case PatternBossPhase.recovery:
        if (clock >= (enraged ? .55 : .85)) _enter(PatternBossPhase.approach);
    }
    game.constrainActor(position, 75);
  }

  void renderGround(Canvas canvas) {
    final vfx = BossVfx(
      kind: kind,
      ambient: BossArt.ambient(game.loadout.arena),
      reducedMotion: game.preferences.reducedMotion,
    );
    final center = (size / 2).toOffset();
    BossArt.contactShadow(
      canvas,
      Offset(size.x * .5, size.y * .86),
      kind.bodyRadius,
    );
    if (phase == PatternBossPhase.arrival) {
      vfx.disk(
        canvas,
        center,
        110,
        ambient: BossArt.ambient(game.loadout.arena),
        warning: true,
        progress: clock / 1.5,
      );
    }
    if (phase == PatternBossPhase.warning || phase == PatternBossPhase.active) {
      final warning = phase == PatternBossPhase.warning;
      final progress = warning
          ? (clock / warningDuration).clamp(0.0, 1.0)
          : (clock / activeDuration).clamp(0.0, 1.0);
      if (kind == BossKind.demon && pattern == 0) {
        final start = atan2(_direction.y, _direction.x) - 1.75;
        vfx.fan(
          canvas,
          center,
          340,
          start,
          3.5,
          warning: warning,
          progress: progress,
          material: AttackMaterial.ember,
        );
      } else if (_charge) {
        vfx.ribbon(
          canvas,
          center,
          (_target - position + size / 2).toOffset(),
          80,
          warning: warning,
          progress: progress,
        );
      } else if (kind == BossKind.queen && pattern == 1) {
        vfx.disk(
          canvas,
          center,
          220,
          ambient: BossArt.ambient(game.loadout.arena),
          warning: warning,
          progress: progress,
          material: AttackMaterial.poison,
        );
      } else if (warning || !_committed) {
        for (final point in _zones) {
          vfx.disk(
            canvas,
            (point - position + size / 2).toOffset(),
            zoneRadius,
            ambient: BossArt.ambient(game.loadout.arena),
            warning: warning,
            progress: progress,
            material: kind == BossKind.queen && pattern == 2
                ? AttackMaterial.poison
                : AttackMaterial.stone,
          );
        }
      }
    }
  }

  @override
  void onRemove() {
    _ground.removeFromParent();
    super.onRemove();
  }

  @override
  void onCombatDeath() {
    game.addCombatEffectForKill(
      position,
      radius: 150,
      remains: RegunArt.shared.sprite('bosses/${kind.name}', 39),
    );
    removeFromParent();
  }
}
