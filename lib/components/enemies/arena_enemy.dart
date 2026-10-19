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
            anchor: Anchor.center);
  final EnemyKind kind;
  final bool elite;
  double clock = 0, _summonClock = 0;
  int phase = 0;
  final _committed = Vector2(1, 0);
  final _shieldDirection = Vector2(1, 0);
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
    add(CircleHitbox(
        radius: size.x * 0.3,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive));
  }

  @override
  bool takeDamage(double amount) {
    if (kind == EnemyKind.shield &&
        phase != 2 &&
        !lastHitWasSecondary &&
        incomingDirection != null &&
        incomingDirection!.dot(_shieldDirection) < -0.4) {
      amount *= 0.3;
    }
    return super.takeDamage(amount);
  }

  @override
  void onCombatDeath() {
    game.addCombatEffectForKill(position,
        radius: size.y / 2,
        remains: RegunArt.shared.sprite('enemies/${kind.name}', 7));
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (combatHealth.isDead ||
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
          if (distance < 260 && clock > 1.2) {
            phase = 1;
            clock = 0;
            _committed.setFrom(direction);
          }
        } else if (phase == 1 && clock >= 0.55) {
          phase = 2;
          clock = 0;
        } else if (phase == 2) {
          game.moveActor(this, _committed, 350, dt, avoidCrowd: false);
          if (distance < 52) game.damagePlayer(cause: kind.title);
          if (clock >= 0.3) {
            phase = 3;
            clock = 0;
          }
        } else if (phase == 3 && clock >= 0.8) {
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
          phase = 2;
          clock = 0;
        } else if (phase == 2 && clock >= 1.2) {
          phase = 0;
          clock = 0;
        }
      case EnemyKind.burster:
        if (phase == 0) {
          game.moveActor(this, approach, 90, dt);
          if (distance < 130) {
            phase = 1;
            clock = 0;
          }
        } else if (clock >= 0.9) {
          if (distance < 150) game.damagePlayer(cause: kind.title);
          combatHealth.damage(
              combatHealth.maximum); // A self-detonation grants no kill reward.
          game.addCombatEffectForKill(position, radius: 150);
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
                  EnemyKind.runner, position + Vector2(i == 0 ? -65 : 65, 0));
            }
          }
        }
      case EnemyKind.sentinel:
        if (clock >= 3.6 && distance < 850) {
          clock = 0;
          game.addHostileArea(game.myPlayer.position.clone(),
              radius: 120,
              warning: 1.0,
              cause: kind.title,
              ownerHealth: combatHealth);
        }
      default:
        game.moveActor(this, direction, 65, dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    if (phase == 1 &&
        (kind == EnemyKind.runner ||
            kind == EnemyKind.shield ||
            kind == EnemyKind.burster)) {
      final r = kind == EnemyKind.burster
          ? 150.0
          : kind == EnemyKind.shield
              ? 140.0
              : 58.0;
      canvas.drawCircle(center, r, Paint()..color = const Color(0x20DFA17A));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = const Color(0xffDFA17A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.x * .5, size.y * .82),
            width: size.x * .7,
            height: 15),
        Paint()..color = const Color(0x600D1315));
    var frame = phase == 1
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
    if (!directional && game.myPlayer.position.x < position.x) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    RegunArt.shared
        .sprite('enemies/${kind.name}', frame)
        .render(canvas, size: size, overridePaint: damagePaint);
    canvas.restore();
    if (elite) {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(Rect.fromLTWH(center.dx - 12 + i * 9, 4, 6, 8),
            Paint()..color = const Color(0xffE6BE75));
      }
    }
    super.render(canvas);
  }
}
