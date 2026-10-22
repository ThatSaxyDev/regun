import 'package:regun/presentation/burster_walk.dart';

import 'dart:math' as math;

import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Authored atlas poses for the five additional enemy roles.
class ArenaEnemy extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ArenaEnemy(this.kind, {super.position, this.elite = false})
    : super(
        size: Vector2.all(kind == EnemyKind.nest ? 104 : 82),
        anchor: Anchor.center,
      );
  final EnemyKind kind;
  _EnemyFootprint? _footprint;
  @override
  double get impactResponse => switch (kind) {
    EnemyKind.nest || EnemyKind.sentinel => 0,
    EnemyKind.shield => .35,
    _ => elite ? .65 : 1,
  };
  final bool elite;
  double clock = 0, _summonClock = 0;
  double walkDistance = 0;
  final walkDirection = Vector2(0, 1);
  int phase = 0;
  final _committed = Vector2(1, 0);
  final _shieldDirection = Vector2(1, 0);
  double _lungeDistance = 105, _lungeDuration = .3;
  static const lungeSpeed = 1050.0;
  static const lungeWarning = .75;
  @override
  int get xpReward => (kind == EnemyKind.nest ? 4 : 2) * (elite ? 3 : 1);
  @override
  int get scoreReward => elite ? 75 : 20;
  @override
  Future<void> onLoad() async {
    final health = switch (kind) {
      EnemyKind.runner => 2.0,
      EnemyKind.shield => 8.0,
      EnemyKind.burster => 3.0,
      EnemyKind.nest => 12.0,
      _ => 5.0,
    };
    initializeHealth(health * (elite ? 2 : 1) * game.director.healthScale);
    if ({
      EnemyKind.runner,
      EnemyKind.shield,
      EnemyKind.burster,
    }.contains(kind)) {
      _footprint = _EnemyFootprint(this);
      game.world.add(_footprint!);
    }
    add(
      CircleHitbox(
        radius: size.x * 0.3,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  bool takeDamage(double amount) {
    if (kind == EnemyKind.shield &&
        phase != 2 &&
        !lastHitWasSecondary &&
        incomingDirection != null &&
        incomingDirection!.dot(_shieldDirection) < -0.4) {
      amount *= incomingArmorPiercing ? .4 : .3;
    }
    return super.takeDamage(amount);
  }

  @override
  void onCombatDeath() {
    game.addCombatEffectForKill(
      position,
      radius: size.y / 2,
      remains: RegunArt.shared.sprite('enemies/${kind.name}', 7),
    );
    removeFromParent();
  }

  @override
  void onFreezeStarted() {
    phase = 0;
    clock = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (combatHealth.isDead ||
        freezeHeld ||
        game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    clock += dt;
    final toPlayer = game.myPlayer.position - position;
    final distance = toPlayer.length;
    final direction = toPlayer.normalized();
    final approach = game.enemyIntent(this, kind);
    switch (kind) {
      case EnemyKind.runner:
        if (phase == 0) {
          game.moveActor(this, approach, 105, dt);
          if (distance < 480 &&
              clock > 1.2 &&
              !game.segmentBlocked(position, game.myPlayer.position) &&
              !game.liveEnemies.whereType<ArenaEnemy>().any(
                (other) =>
                    other != this &&
                    other.kind == EnemyKind.runner &&
                    other.position.distanceToSquared(position) < 700 * 700 &&
                    (other.phase == 1 ||
                        other.phase == 2 ||
                        (other.phase == 3 && other.clock < .35)),
              )) {
            phase = 1;
            clock = 0;
            final aim = game.myPlayer.position.clone();
            // Mix direct attacks with route cuts. Lock before showing the lane;
            // turning after the warning always changes the player's escape.
            if (game.random.nextDouble() < .4) {
              final lead =
                  game.movementJoystick.relativeDelta *
                  game.playerWalkSpeed *
                  .8;
              if (lead.length > 200) lead.scale(200 / lead.length);
              aim.add(lead);
            }
            final delta = aim - position;
            _committed.setFrom(delta.normalized());
            if (_committed.isZero()) _committed.setValues(1, 0);
            _lungeDistance = (delta.length + 40).clamp(180, 520);
            final speedScale =
                (1 + math.min(.5, (game.director.cycle - 1) * .08)) *
                (elite ? 1.15 : 1);
            _lungeDuration = _lungeDistance / (lungeSpeed * speedScale);
          }
        } else if (phase == 1 && clock >= lungeWarning) {
          phase = 2;
          clock = 0;
        } else if (phase == 2) {
          final before = position.clone();
          final step = math.min(
            dt,
            math.max(0.0, _lungeDuration - (clock - dt)),
          );
          game.moveActor(this, _committed, lungeSpeed, step, avoidCrowd: false);
          if (BulletComponent.segmentDistanceSquared(
                    game.myPlayer.position,
                    before,
                    position,
                  ) <
                  52 * 52 &&
              !game.segmentBlocked(position, game.myPlayer.position)) {
            game.damagePlayer(cause: kind.title);
          }
          if (clock >= _lungeDuration) {
            phase = 3;
            clock = 0;
          }
        } else if (phase == 3 && clock >= 1.4) {
          phase = 0;
          clock = 0;
        }
      case EnemyKind.shield:
        if (phase == 0) {
          game.moveActor(this, direction, 55, dt);
          _shieldDirection.setFrom(direction);
          if (distance < 125) {
            phase = 1;
            clock = 0;
          }
        } else if (phase == 1 && clock > 0.75) {
          if (distance < 140) game.damagePlayer(cause: kind.title);
          game.addCombatEffect(
            CombatEffect(
              position: position.clone(),
              radius: 140,
              duration: .34,
              material: AttackMaterial.chain,
              floorEffect: true,
            ),
          );
          phase = 2;
          clock = 0;
        } else if (phase == 2 && clock >= 1.2) {
          phase = 0;
          clock = 0;
        }
      case EnemyKind.burster:
        if (phase == 0) {
          final before = position.clone();
          game.moveActor(this, approach, 90, dt);
          final movement = position - before;
          if (movement.length2 > 1e-8) {
            walkDistance += movement.length;
            walkDirection.setFrom(movement.normalized());
          }
          if (distance < 130) {
            phase = 1;
            clock = 0;
          }
        } else if (clock >= 0.9) {
          if (distance < 150) game.damagePlayer(cause: kind.title);
          combatHealth.damage(
            combatHealth.maximum,
          ); // A self-detonation grants no kill reward.
          game.addCombatEffect(
            CombatEffect(
              position: position.clone(),
              radius: 150,
              duration: .42,
              material: AttackMaterial.ember,
            ),
          );
          removeFromParent();
        }
      case EnemyKind.nest:
        _summonClock += dt;
        if (_summonClock >= 5 && distance < 1000) {
          _summonClock = 0;
          if (game.liveEnemies
                  .whereType<ArenaEnemy>()
                  .where((e) => e.kind == EnemyKind.runner)
                  .length <
              12) {
            for (var i = 0; i < 2; i++) {
              game.spawnAdd(
                EnemyKind.runner,
                position + Vector2(i == 0 ? -65 : 65, 0),
              );
            }
          }
        }
      case EnemyKind.sentinel:
        if (clock >= 3.6 && distance < 850) {
          clock = 0;
          game.addHostileArea(
            game.myPlayer.position.clone(),
            radius: 120,
            warning: 1.0,
            cause: kind.title,
            ownerHealth: combatHealth,
          );
        }
      default:
        game.moveActor(this, direction, 65, dt);
    }
  }

  @override
  void onRemove() {
    _footprint?.removeFromParent();
    super.onRemove();
  }

  void renderFootprint(Canvas canvas) {
    final center = (size / 2).toOffset();
    if (phase == 1 &&
        (kind == EnemyKind.runner ||
            kind == EnemyKind.shield ||
            kind == EnemyKind.burster)) {
      if (kind == EnemyKind.runner) {
        AttackVfx.lungeWarning(
          canvas,
          center,
          center + (_committed * _lungeDistance).toOffset(),
          progress: (clock / lungeWarning).clamp(0, 1),
          ambient: BossArt.ambient(game.loadout.arena),
        );
      } else {
        AttackVfx.disk(
          canvas,
          center,
          kind == EnemyKind.burster ? 150 : 140,
          warning: true,
          progress: (clock / (kind == EnemyKind.burster ? .9 : .75)).clamp(
            0,
            1,
          ),
          material: kind == EnemyKind.burster
              ? AttackMaterial.ember
              : AttackMaterial.chain,
          ambient: BossArt.ambient(game.loadout.arena),
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .82),
        width: size.x * .7,
        height: 15,
      ),
      Paint()..color = const Color(0x600D1315),
    );
    var frame = freezeHeld
        ? 0
        : phase == 1
        ? 5
        : phase == 2
        ? 6
        : (clock * (kind == EnemyKind.nest ? 6 : 12)).floor() % 4;
    final direction = game.myPlayer.position - position;
    final directional = kind == EnemyKind.burster || kind == EnemyKind.sentinel;
    if (directional && phase == 0) {
      frame = direction.y.abs() > direction.x.abs()
          ? (direction.y > 0 ? 1 : 2)
          : (direction.x > 0 ? 0 : 3);
    }
    canvas.save();
    final facingLeft = kind == EnemyKind.runner && (phase == 1 || phase == 2)
        ? _committed.x < 0
        : game.myPlayer.position.x < position.x;
    if (!directional && facingLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    if (kind == EnemyKind.runner &&
        phase == 2 &&
        !game.preferences.reducedMotion) {
      canvas.translate(
        0,
        -math.sin((clock / _lungeDuration).clamp(0, 1) * math.pi) * 24,
      );
    }
    final walking = kind == EnemyKind.burster && phase == 0;
    final sprite = walking
        ? RegunArt.shared.sprite(
            'enemies/burster_walk',
            BursterWalk.frame(walkDirection.toOffset(), walkDistance),
          )
        : RegunArt.shared.sprite('enemies/${kind.name}', frame);
    sprite.render(canvas, size: size, overridePaint: damagePaint);
    canvas.restore();
    if (elite) {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(center.dx - 12 + i * 9, 4, 6, 8),
          Paint()..color = const Color(0xffE6BE75),
        );
      }
    }
    super.render(canvas);
  }
}

/// Warning art lives below every actor, independent of actor draw ordering.
class _EnemyFootprint extends PositionComponent {
  _EnemyFootprint(this.owner) : super(priority: -10);
  final ArenaEnemy owner;
  @override
  void render(Canvas canvas) {
    if (owner.isRemoving || owner.combatHealth.isDead) return;
    final p = owner.position - owner.size / 2;
    if (!canvas
        .getLocalClipBounds()
        .inflate(700)
        .contains(owner.position.toOffset())) {
      return;
    }
    canvas.save();
    canvas.translate(p.x, p.y);
    owner.renderFootprint(canvas);
    canvas.restore();
  }
}
