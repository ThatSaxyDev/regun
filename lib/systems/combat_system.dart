import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/boss_weak_point.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/components/weapons/mine_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class CombatSystem {
  CombatSystem(this.game);
  final RegunGame game;
  double droneClock = 0, angle = 0;
  int _chainBudget = 8;
  GameState get state => game.gameState;
  int rank(PowerUp p) => state.rank(p);
  double effect(PowerUp p) => state.effectRank(p);

  void update(double dt) {
    angle += dt;
    _chainBudget = 8;
    if (rank(PowerUp.orbitDrone) == 0) return;
    droneClock += dt;
    if (droneClock < max(0.3, 1.0 - effect(PowerUp.orbitDrone) * 0.15)) return;
    droneClock = 0;
    final count = state.fused('hunterSwarm') ? 3 : 1;
    for (var i = 0; i < count; i++) {
      final target = game.nearestEnemy(game.myPlayer.position,
          range: 600, preferMarked: rank(PowerUp.targetingLink) > 0);
      if (target == null) continue;
      final center = game.myPlayer.position +
          Vector2(cos(angle + i * 2), sin(angle + i * 2)) * 80;
      game.addCombatEffect(CombatEffect(
          position: center,
          endpoint: target.position.clone(),
          color: const Color(0xffBBC6A5),
          duration: 0.12));
      final marked = (target as CombatEnemy).marked;
      hit(
          target,
          (0.6 + effect(PowerUp.orbitDrone) * 0.35) *
              (marked ? 1 + effect(PowerUp.targetingLink) * 0.3 : 1),
          primary: false);
    }
  }

  bool hit(PositionComponent enemy, double amount,
      {bool primary = true, Vector2? direction}) {
    if (enemy is BossWeakPoint) return enemy.takeDamage(amount);
    if (enemy is! CombatEnemy ||
        enemy.isRemoving ||
        !enemy.isLoaded ||
        state.gameplayState != GameplayState.playing) {
      return false;
    }
    if (enemy.combatHealth.isDead) return false;
    enemy.lastHitWasSecondary = !primary;
    enemy.incomingDirection = direction;
    if (primary) {
      if (rank(PowerUp.hotShot) > 0) {
        enemy.ignite(0.25 + effect(PowerUp.hotShot) * 0.2);
      }
      if (rank(PowerUp.targetingLink) > 0) enemy.marked = true;
      if (enemy.combatHealth.fraction < 0.35) {
        amount *= 1 + effect(PowerUp.executioner) * 0.3;
      }
    }
    if (!enemy.takeDamage(amount)) return false;
    if (primary && direction != null) {
      enemy.receiveBulletImpact(direction, game.loadout.weapon);
    }
    if (primary) {
      final innate = game.loadout.weapon == WeaponType.arcCaster;
      if (_chainBudget > 0 &&
          (innate ||
              game.random.nextDouble() < effect(PowerUp.staticCharge) * 0.12)) {
        _chainBudget--;
        final count = (innate ? 2 : 0) +
            rank(PowerUp.conductiveCore) +
            (state.fused('stormCircuit') ? 2 : 0);
        final visited = <PositionComponent>{enemy};
        PositionComponent source = enemy;
        for (var i = 0; i < max(1, count); i++) {
          final target = game.nearestEnemy(source.position,
              excluding: visited,
              range: (innate ? 240 : 170) + rank(PowerUp.conductiveCore) * 55);
          if (target == null) break;
          visited.add(target);
          game.addCombatEffect(CombatEffect(
              position: source.position.clone(),
              endpoint: target.position.clone(),
              color: const Color(0xffBCD7AE),
              duration: 0.16));
          hit(target, amount * pow(innate ? .85 : .65, i + 1), primary: false);
          source = target;
        }
      }
    }
    return true;
  }

  void onKill(PositionComponent enemy) {
    if (enemy is! CombatEnemy) return;
    if (rank(PowerUp.fieldMedic) > 0 &&
        game.random.nextDouble() < effect(PowerUp.fieldMedic) * 0.05) {
      game.gameNotifier.heal();
    }
    if (enemy.burning && enemy.burnCanSpread && rank(PowerUp.accelerant) > 0) {
      final radius = 100 + effect(PowerUp.accelerant) * 30;
      for (final target in game.liveEnemies.toList()) {
        if (target != enemy &&
            target.position.distanceToSquared(enemy.position) <
                radius * radius) {
          (target as CombatEnemy).ignite(enemy.burnDamage, maySpread: false);
        }
      }
      if (state.fused('firebreak') &&
          game.world.children.whereType<BurningGround>().length < 12) {
        game.addFire(BurningGround(position: enemy.position.clone()));
      }
    }
    if (!enemy.lastHitWasSecondary &&
        rank(PowerUp.shrapnel) > 0 &&
        game.random.nextDouble() < effect(PowerUp.shrapnel) * 0.18) {
      shards(enemy.position,
          count: 3 + rank(PowerUp.shrapnel),
          damage: 0.65,
          direction: game.myPlayer.aimDirection);
    }
  }

  void shards(Vector2 position,
      {int count = 6, double damage = 1, Vector2? direction}) {
    for (var i = 0; i < count; i++) {
      if (game.projectileCount >= RegunGame.maxProjectiles) break;
      final baseAngle =
          direction == null ? 0.0 : atan2(direction.y, direction.x);
      final angle = direction == null
          ? i * 2 * pi / count
          : baseAngle + (i - (count - 1) / 2) * pi / 12;
      final shotDirection = Vector2(cos(angle), sin(angle));
      game.addProjectile(BulletComponent(
          position: position.clone(),
          direction: shotDirection,
          damage: damage,
          speed: 650,
          maxTravelDistance: 200,
          primary: false,
          angle: atan2(shotDirection.y, shotDirection.x)));
    }
  }

  void explode(Vector2 position,
      {required double radius, required double damage}) {
    game.addCombatEffect(CombatEffect(
        position: position.clone(),
        radius: radius,
        duration: .42,
        material: AttackMaterial.ember));
    for (final target in game.liveEnemies.toList()) {
      if (target.position.distanceToSquared(position) < radius * radius) {
        hit(target, damage, primary: false);
      }
    }
    if (rank(PowerUp.fragmentation) > 0) {
      shards(position,
          count: 4 + rank(PowerUp.fragmentation) * 2, damage: damage * 0.2);
    }
  }

  void onDash() {
    if (rank(PowerUp.sprintMine) == 0 && !state.triggerSprintMine) return;
    final count = state.fused('minefield') ? 3 : 1;
    for (var i = 0; i < count; i++) {
      if (game.world.children.whereType<MineComponent>().length >= 12) break;
      final position =
          game.myPlayer.position - game.myPlayer.dashDirection * (i * 45);
      game.map.bounds.constrainPlayer(position, 20);
      game.addMineAt(position);
    }
  }
}

class DroneVisual extends PositionComponent with HasGameReference<RegunGame> {
  @override
  void render(Canvas canvas) {
    if (game.gameState.rank(PowerUp.orbitDrone) == 0) return;
    final count = game.gameState.fused('hunterSwarm') ? 3 : 1;
    final center = game.myPlayer.position;
    for (var i = 0; i < count; i++) {
      final point = center +
          Vector2(cos(game.combat.angle + i * 2),
                  sin(game.combat.angle + i * 2)) *
              80;
      RegunArt.shared.rawSprite('items/items', 6).render(canvas,
          position: point, size: Vector2(30, 24), anchor: Anchor.center);
    }
  }
}
