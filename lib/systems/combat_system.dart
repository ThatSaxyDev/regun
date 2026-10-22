import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/weapon_reaction.dart';
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
      final target = game.nearestEnemy(
        game.myPlayer.position,
        range: 600,
        preferMarked: rank(PowerUp.targetingLink) > 0,
      );
      if (target == null) continue;
      final center =
          game.myPlayer.position +
          Vector2(cos(angle + i * 2), sin(angle + i * 2)) * 80;
      game.addCombatEffect(
        CombatEffect(
          position: center,
          endpoint: target.position.clone(),
          color: const Color(0xffBBC6A5),
          duration: 0.12,
        ),
      );
      final marked = (target as CombatEnemy).marked;
      hit(
        target,
        ((game.gameNotifier.buildBalance >= 2 ? .8 : .6) +
                effect(PowerUp.orbitDrone) * 0.35) *
            (marked ? 1 + effect(PowerUp.targetingLink) * 0.3 : 1),
        primary: false,
      );
    }
  }

  bool hit(
    PositionComponent enemy,
    double amount, {
    bool primary = true,
    bool weaponHit = false,
    bool allowChain = true,
    bool armorPiercing = false,
    int releaseId = 0,
    double releaseBonus = 0,
    double? travel,
    String source = 'secondary',
    WeaponReaction? reaction,
    Vector2? direction,
  }) {
    final character = game.loadout.character;
    final owner = enemy is BossWeakPoint ? enemy.owner : enemy;
    final quarry =
        owner is CombatEnemy &&
        (owner.isBoss || (owner is ArenaEnemy && owner.elite));
    if (primary || weaponHit) {
      if (character == CharacterType.harrow) amount *= quarry ? 1.15 : .90;
      if (owner is CombatEnemy && owner.freezeHeld) {
        amount *= 1 + .06 * effect(PowerUp.exposedSeam);
      }
      if (travel != null && travel <= 160) {
        amount *=
            (1 + min(.60, releaseBonus + .06 * effect(PowerUp.closeQuarters))) /
            (1 + releaseBonus);
      }
    }
    if (enemy is BossWeakPoint) return enemy.takeDamage(amount);
    if (enemy is! CombatEnemy ||
        enemy.isRemoving ||
        !enemy.isLoaded ||
        state.gameplayState != GameplayState.playing) {
      return false;
    }
    if (enemy.combatHealth.isDead) return false;
    enemy.lastHitWasSecondary = !primary;
    enemy.lastDamageSource = source;
    enemy.incomingDirection = direction;
    enemy.incomingArmorPiercing = primary && armorPiercing;
    if (primary || weaponHit) {
      final runtime = game.gameNotifier.survivor;
      if (character == CharacterType.moth && runtime.emberGate <= 0) {
        runtime.emberGate = 1;
        enemy.ignite(.35);
      }
    }
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
    if (direction != null && (primary || reaction != null)) {
      enemy.receiveWeaponImpact(
        direction,
        reaction ?? WeaponReaction.of(game.loadout.weapon),
      );
    }
    if (primary || weaponHit) {
      final runtime = game.gameNotifier.survivor;
      final coil =
          runtime.qualifyingHit(
            releaseId,
            continuous: game.loadout.weapon.isContinuous,
          ) &&
          character == CharacterType.coil &&
          runtime.coilHit();
      final innate = game.loadout.weapon == WeaponType.arcCaster;
      final standard =
          primary &&
          (innate ||
              game.random.nextDouble() < effect(PowerUp.staticCharge) * .12);
      if (allowChain && _chainBudget > 0 && (standard || coil)) {
        _chainBudget--;
        final normalCount = standard
            ? max(
                1,
                (innate
                        ? 2
                        : game.gameNotifier.buildBalance >= 2
                        ? 1
                        : 0) +
                    rank(PowerUp.conductiveCore) +
                    (state.fused('stormCircuit') ? 2 : 0),
              )
            : 0;
        final wireReady =
            state.fused('groundWire') &&
            runtime.wire == 3 &&
            runtime.wireGate <= 0;
        final visited = <PositionComponent>{enemy};
        PositionComponent source = enemy;
        var acceptedAny = false;
        for (
          var i = 0;
          i < normalCount + (coil ? 1 : 0) + (wireReady ? 1 : 0);
          i++
        ) {
          final coilJump = coil && i == normalCount;
          if (coilJump) source = enemy;
          final target = game.nearestEnemy(
            source.position,
            excluding: visited,
            range: coilJump
                ? 200
                : (innate ? 240 : 170) + rank(PowerUp.conductiveCore) * 55,
          );
          if (target == null) {
            if (i < normalCount && coil) {
              i = normalCount - 1;
              continue;
            }
            break;
          }
          visited.add(target);
          game.addCombatEffect(
            CombatEffect(
              position: source.position.clone(),
              endpoint: target.position.clone(),
              color: const Color(0xffBCD7AE),
              duration: .16,
            ),
          );
          final retention = min(
            .92,
            (innate ? .85 : .65) + .02 * effect(PowerUp.faradayReserve),
          );
          final accepted = hit(
            target,
            amount *
                (coilJump
                    ? min(.92, .50 + .02 * effect(PowerUp.faradayReserve))
                    : pow(retention, i + 1)) *
                (character == CharacterType.coil ? 1.1 : 1),
            primary: false,
            direction: (target.position - source.position).normalized(),
            reaction: WeaponReaction.arcJump,
          );
          if (accepted) {
            acceptedAny = true;
            runtime.chainVictim((target as CombatEnemy).combatId);
          }
          source = target;
        }
        if (acceptedAny && state.fused('groundWire')) {
          runtime.wire = (runtime.wire + 1) % 4;
          if (wireReady) runtime.wireGate = 1;
        }
      }
    }
    return true;
  }

  void onKill(PositionComponent enemy) {
    if (enemy is! CombatEnemy) return;
    final runtime = game.gameNotifier.survivor;
    runtime.kill();
    final burningKill =
        enemy.burning ||
        enemy.cinderRemaining > 0 ||
        {'burn', 'cinder'}.contains(enemy.lastDamageSource);
    if (burningKill) runtime.burningKills++;
    if (enemy.lastDamageSource == 'grenade') runtime.grenadeKills++;
    if (rank(PowerUp.fieldMedic) > 0 &&
        runtime.healGate <= 0 &&
        state.health < state.maxHealth &&
        game.random.nextDouble() < effect(PowerUp.fieldMedic) * 0.05) {
      game.gameNotifier.heal();
      if (game.gameNotifier.buildBalance >= 2) {
        runtime.healGate = game.loadout.character == CharacterType.suture
            ? 12
            : 6;
      }
    }
    final spreadBurn =
        burningKill && enemy.burnCanSpread && rank(PowerUp.accelerant) > 0;
    final leavesFire =
        (spreadBurn && state.fused('firebreak')) ||
        (burningKill &&
            state.fused('kilnPact') &&
            (enemy.isBoss || (enemy is ArenaEnemy && enemy.elite)));
    if (leavesFire &&
        game.world.children.whereType<BurningGround>().length < 12) {
      game.addFire(BurningGround(position: enemy.position.clone()));
    }
    if (spreadBurn) {
      final modern = game.gameNotifier.buildBalance >= 2;
      final radius = modern
          ? 130 + 35 * effect(PowerUp.accelerant)
          : 100 + effect(PowerUp.accelerant) * 30;
      final targets = game.liveEnemies.toList()
        ..sort(
          (a, b) => a.position
              .distanceToSquared(enemy.position)
              .compareTo(b.position.distanceToSquared(enemy.position)),
        );
      var spread = 0;
      for (final target in targets) {
        if ((!modern || spread < 6) &&
            target != enemy &&
            !game.segmentBlocked(enemy.position, target.position) &&
            target.position.distanceToSquared(enemy.position) <
                radius * radius) {
          spread++;
          (target as CombatEnemy).ignite(
            enemy.burning || enemy.lastDamageSource == 'burn'
                ? enemy.burnDamage
                : .3,
            maySpread: false,
          );
        }
      }
    }
    if (!enemy.lastHitWasSecondary &&
        rank(PowerUp.shrapnel) > 0 &&
        game.random.nextDouble() < effect(PowerUp.shrapnel) * 0.18) {
      shards(
        enemy.position,
        count: 3 + rank(PowerUp.shrapnel),
        damage: 0.65,
        direction: game.myPlayer.aimDirection,
      );
    }
  }

  void shards(
    Vector2 position, {
    int count = 6,
    double damage = 1,
    Vector2? direction,
  }) {
    for (var i = 0; i < count; i++) {
      if (game.projectileCount >= RegunGame.maxProjectiles) break;
      final baseAngle = direction == null
          ? 0.0
          : atan2(direction.y, direction.x);
      final angle = direction == null
          ? i * 2 * pi / count
          : baseAngle + (i - (count - 1) / 2) * pi / 12;
      final shotDirection = Vector2(cos(angle), sin(angle));
      game.addProjectile(
        BulletComponent(
          position: position.clone(),
          direction: shotDirection,
          damage: damage,
          speed: 650,
          maxTravelDistance: 200,
          primary: false,
          reaction: WeaponReaction.shrapnel,
          angle: atan2(shotDirection.y, shotDirection.x),
        ),
      );
    }
  }

  void upgradePulse() {
    final origin = game.myPlayer.position.clone();
    game.clearHostileShots(origin, 250);
    game.audio.play('upgrade_pulse.wav');
    game.addCombatEffect(
      CombatEffect(
        position: origin.clone(),
        radius: 250,
        duration: .5,
        upgradePulse: true,
      ),
    );
    for (final target in game.liveEnemies.toList()) {
      final delta = target.position - origin;
      if (delta.length > 250 + game.crowdRadius(target) ||
          game.segmentBlocked(origin, target.position)) {
        continue;
      }
      hit(target, 1, primary: false);
      if (target is CombatEnemy && !target.combatHealth.isDead) {
        target.receiveUpgradePulse(delta.isZero() ? Vector2(1, 0) : delta, 145);
      }
    }
  }

  void explode(
    Vector2 position, {
    required double radius,
    required double damage,
    WeaponReaction reaction = WeaponReaction.grenade,
    bool grenade = false,
    int releaseId = 0,
    double releaseBonus = 0,
  }) {
    game.audio.play('blast.wav');
    game.addCombatEffect(
      CombatEffect(
        position: position.clone(),
        radius: radius,
        duration: .48,
        material: AttackMaterial.ember,
      ),
    );
    for (final target in game.liveEnemies.toList()) {
      final reach = radius + game.crowdRadius(target);
      if (target.position.distanceToSquared(position) <= reach * reach &&
          !game.segmentBlocked(position, target.position)) {
        final delta = target.position - position;
        hit(
          target,
          damage,
          primary: false,
          source: grenade ? 'grenade' : 'secondary',
          weaponHit: releaseId > 0,
          releaseId: releaseId,
          releaseBonus: releaseBonus,
          direction: delta.isZero()
              ? game.myPlayer.aimDirection
              : delta.normalized(),
          reaction: (grenade || identical(reaction, WeaponReaction.mine))
              ? reaction.scaled(
                  1 + .10 * effect(PowerUp.blastHarness),
                  hold: true,
                )
              : reaction,
        );
      }
    }
    if (rank(PowerUp.fragmentation) > 0) {
      shards(
        position,
        count: 4 + rank(PowerUp.fragmentation) * 2,
        damage: damage * 0.2,
      );
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
      final point =
          center +
          Vector2(
                cos(game.combat.angle + i * 2),
                sin(game.combat.angle + i * 2),
              ) *
              80;
      RegunArt.shared
          .rawSprite('items/items', 6)
          .render(
            canvas,
            position: point,
            size: Vector2(30, 24),
            anchor: Anchor.center,
          );
    }
  }
}
