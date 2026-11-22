import 'package:regun/systems/expedition_signature.dart';
import 'package:regun/systems/expedition.dart';
import 'package:regun/systems/target_shape.dart';
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
    _advanceAftershocks(dt);
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
          companion: true,
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
    bool supportBallistic = false,
    bool allowChain = true,
    bool armorPiercing = false,
    int releaseId = 0,
    double releaseBonus = 0,
    double? travel,
    String source = 'secondary',
    WeaponReaction? reaction,
    Vector2? direction,
    Offset? hitPoint,
    Offset? blastCenter,
    double? blastRadius,
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
    if (enemy is BossWeakPoint) {
      if (game.presentationHeld) return false;
      if (supportBallistic && owner is CombatEnemy) {
        owner.lastHitWasSecondary = true;
        owner.lastDamageSource = source;
        owner.incomingDirection = null;
      }
      final accepted = enemy.takeDamage(amount);
      if (accepted && (primary || weaponHit)) {
        _expeditionWeaponHit(enemy.position);
      }
      return accepted;
    }
    if (enemy is! CombatEnemy ||
        enemy.isRemoving ||
        !enemy.isLoaded ||
        state.gameplayState != GameplayState.playing ||
        game.presentationHeld) {
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
    final precisionContact =
        (primary || weaponHit) &&
        ((enemy.freezeHeld && effect(PowerUp.exposedSeam) > 0) ||
            (travel != null &&
                travel <= 160 &&
                effect(PowerUp.closeQuarters) > 0));
    final executionContact =
        primary &&
        enemy.combatHealth.fraction < .35 &&
        effect(PowerUp.executioner) > 0;
    enemy.incomingSupportBallistic = supportBallistic;
    bool accepted;
    try {
      accepted = enemy is LocalDamageTarget
          ? (enemy as LocalDamageTarget).receiveLocalDamage(
              amount,
              point: hitPoint,
              blastCenter: blastCenter,
              blastRadius: blastRadius,
            )
          : enemy.takeDamage(amount);
    } finally {
      enemy.incomingSupportBallistic = false;
    }
    if (!accepted) return false;
    if (primary || weaponHit) _expeditionWeaponHit(enemy.position);
    if (precisionContact || executionContact) enemy.showMechanicContact(4);
    if (primary) {
      game.upgradePresentation.observe('heavyLoad', 'Stronger primary hit');
      if (enemy.burning) {
        game.upgradePresentation.observe('hotShot', 'Burn applied');
      }
    }
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
                innate ? 0 : 1,
                (innate
                        ? game.gameNotifier.weaponPower
                              .behavior(WeaponType.arcCaster, 'chainJumps')
                              .toInt()
                        : game.gameNotifier.buildBalance >= 2
                        ? 1
                        : 0) +
                    state.countRank(PowerUp.conductiveCore) +
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
                : (innate
                          ? game.gameNotifier.weaponPower.behavior(
                              WeaponType.arcCaster,
                              'chainRange',
                            )
                          : 170) +
                      state.countRank(PowerUp.conductiveCore) * 55,
          );
          if (target == null) {
            if (i < normalCount && coil) {
              i = normalCount - 1;
              continue;
            }
            break;
          }
          visited.add(target);
          final retention = min(
            .92,
            (innate
                    ? game.gameNotifier.weaponPower.behavior(
                        WeaponType.arcCaster,
                        'chainRetention',
                      )
                    : .65) +
                .02 * effect(PowerUp.faradayReserve),
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
            game.addCombatEffect(
              CombatEffect(
                position: source.position.clone(),
                endpoint: target.position.clone(),
                color: const Color(0xffBCD7AE),
                perkChain: !innate || coilJump || i >= normalCount,
                duration: .16,
              ),
            );
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

  void _expeditionWeaponHit(Vector2 position) {
    final run = game.expedition;
    if (run == null || run.phase != ExpeditionPhase.combat) return;
    if (run.signatures[ExpeditionSignature.breachCharge] case final rank?
        when run.breachChargeReady) {
      run.breachChargeReady = false;
      game.revision.value++;
      expeditionBurst(
        position,
        cue: ExpeditionCue.breach,
        radius: 130 + 38.0 * rank,
        damage: 1.6 + (run.generator >= 4 ? 1.4 : .85) * rank,
        targets: 4 + rank,
      );
    }
    if (run.signatures[ExpeditionSignature.coldSnap] case final rank?
        when run.coldSnapReady) {
      run.coldSnapReady = false;
      game.revision.value++;
      expeditionBurst(
        position,
        cue: ExpeditionCue.frost,
        radius: 112 + rank * 30,
        damage: 2.0 + rank * 1.7,
        targets: 3 + rank,
      );
    }
    if (run.signatures[ExpeditionSignature.quickdraw] case final rank?
        when run.quickdrawReady) {
      run.quickdrawReady = false;
      game.revision.value++;
      expeditionBurst(
        position,
        cue: ExpeditionCue.quickdraw,
        radius: 110,
        damage: 2.0 + rank * 2,
        targets: 3,
      );
      if (run.fusions.contains(ExpeditionFusion.runningShot)) {
        expeditionBurst(
          game.myPlayer.position,
          cue: ExpeditionCue.deadeye,
          radius: 165,
          damage: 2.0 + rank * 2,
          targets: 3,
        );
      }
    }
    if (run.signatures[ExpeditionSignature.deadeye] case final rank?) {
      final charged = ++run.signatureHits >= 4;
      if (charged) run.signatureHits = 0;
      game.revision.value++;
      if (charged) {
        expeditionBurst(
          position,
          cue: ExpeditionCue.deadeye,
          radius: 75 + rank * 28,
          damage: 2.0 + rank * 2,
          targets: rank + 1,
        );
      }
    }
  }

  void onKill(PositionComponent enemy) {
    if (enemy is! CombatEnemy) return;
    final runtime = game.gameNotifier.survivor;
    runtime.kill();
    final run = game.expedition;
    final flashpoint = run?.signatures[ExpeditionSignature.flashpoint];
    if (run != null &&
        flashpoint != null &&
        run.phase == ExpeditionPhase.combat &&
        (!enemy.lastHitWasSecondary ||
            enemy.lastDamageSource == 'expedition' ||
            (enemy.lastDamageSource == 'grenade' &&
                enemy.burning &&
                run.fusions.contains(ExpeditionFusion.flashover))) &&
        run.flashpointCooldown <= 0) {
      run.flashpointCooldown = .8;
      expeditionBurst(
        enemy.position,
        radius: 115 + 32.0 * flashpoint,
        damage: 1.8 + (run.generator >= 4 ? 1.4 : .85) * flashpoint,
        targets: 4 + flashpoint,
        cue: ExpeditionCue.flash,
        ignite: run.fusions.contains(ExpeditionFusion.flashover),
      );
    }
    final blood = run?.signatures[ExpeditionSignature.bloodTax];
    if (run != null && blood != null && run.phase == ExpeditionPhase.combat) {
      final threshold = ExpeditionSignature.bloodTaxKills(blood);
      run.signatureKills = min(threshold, run.signatureKills + 1);
      if (run.signatureKills >= threshold && state.health < state.maxHealth) {
        run.signatureKills = 0;
        game.gameNotifier.heal();
        game.audio.play(ExpeditionCue.blood.sound);
        if (run.fusions.contains(ExpeditionFusion.fieldTransfusion)) {
          run.coldSnapReady = true;
          expeditionScreen(game.myPlayer.position, 190);
        }
        game.addCombatEffect(
          CombatEffect(
            position: game.myPlayer.position.clone(),
            radius: 62,
            duration: .5,
            signatureHeal: true,
            floorEffect: true,
          ),
        );
      }
      game.revision.value++;
    }
    final burningKill =
        enemy.burning ||
        enemy.cinderRemaining > 0 ||
        {'burn', 'cinder'}.contains(enemy.lastDamageSource);
    if (burningKill) runtime.burningKills++;
    if (enemy.lastDamageSource == 'grenade') runtime.grenadeKills++;
    if (rank(PowerUp.fieldMedic) > 0 &&
        runtime.healGate <= 0 &&
        state.health < state.maxHealth &&
        game.random.nextDouble() <
            min(.225, effect(PowerUp.fieldMedic) * 0.05)) {
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
        count: 3 + state.countRank(PowerUp.shrapnel),
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
      if (game.targetDistance(target, origin, body: game.crowdRadius(target)) >
              250 ||
          !game.targetVisible(target, origin)) {
        continue;
      }
      hit(target, 1, primary: false);
      if (target is CombatEnemy && !target.combatHealth.isDead) {
        target.receiveUpgradePulse(delta.isZero() ? Vector2(1, 0) : delta, 145);
      }
    }
  }

  void expeditionScreen(Vector2 center, double radius) {
    var impacts = 0;
    game.clearHostileShots(
      center,
      radius,
      onClear: (position) {
        if (impacts++ >= 4) return;
        expeditionCue(
          Vector2(position.dx, position.dy),
          ExpeditionCue.curtain,
          28,
          duration: .24,
          sound: false,
        );
      },
    );
    expeditionCue(center, ExpeditionCue.curtain, radius);
  }

  void expeditionCue(
    Vector2 center,
    ExpeditionCue cue,
    double radius, {
    double duration = .42,
    double age = 0,
    bool sound = true,
  }) {
    if (sound) game.audio.play(cue.sound);
    game.reserveWeaponPatch();
    game.addCombatEffect(
      CombatEffect(
        position: center.clone(),
        radius: radius,
        duration: duration,
        expeditionCue: cue,
        floorEffect: true,
      )..age = age,
    );
  }

  void expeditionBurst(
    Vector2 center, {
    required ExpeditionCue cue,
    required double radius,
    required double damage,
    required int targets,
    double shove = 0,
    bool ignite = false,
    bool shatterFrozen = false,
    bool shapedCharge = false,
  }) {
    final bonus = game.expedition?.hasSynergy == true ? 1.25 : 1.0;
    radius *= bonus;
    final frost = cue == ExpeditionCue.frost;
    final lightning =
        cue == ExpeditionCue.thunder ||
        cue == ExpeditionCue.deadeye ||
        cue == ExpeditionCue.quickdraw;
    expeditionCue(center, cue, radius);
    final nearby =
        game.liveEnemies
            .where(
              (target) =>
                  game.targetDistance(
                        target,
                        center,
                        body: game.crowdRadius(target),
                      ) <=
                      radius &&
                  game.targetVisible(target, center),
            )
            .toList()
          ..sort(
            (a, b) => a.position
                .distanceToSquared(center)
                .compareTo(b.position.distanceToSquared(center)),
          );
    PositionComponent? firstHit;
    for (final target in nearby.take(targets)) {
      final frozen =
          shatterFrozen && target is CombatEnemy && target.freezeState.frozen;
      if (lightning) {
        game.addCombatEffect(
          CombatEffect(
            position: center.clone(),
            endpoint: target.position.clone(),
            perkChain: true,
            duration: .24,
          ),
        );
      }
      final landed = hit(
        target,
        damage * bonus * (frozen ? 1.8 : 1),
        primary: false,
        allowChain: false,
        source: 'expedition',
        blastCenter: center.toOffset(),
        blastRadius: radius,
      );
      if (!landed) continue;
      firstHit ??= target;
      if (target is CombatEnemy && !target.combatHealth.isDead) {
        if (frozen) target.breakExpeditionFreeze();
        if (frost) target.freeze(duration: .38);
        if (ignite) target.ignite(1.1, maySpread: false);
        if (shove > 0) {
          target.receiveUpgradePulse(target.position - center, shove);
        }
      }
      if (frozen) {
        expeditionCue(target.position, ExpeditionCue.shatter, 83);
        final origin = target.position;
        for (final neighbor
            in nearby
                .where(
                  (other) =>
                      other != target &&
                      other.position.distanceToSquared(origin) < 10000 &&
                      game.targetVisible(other, origin),
                )
                .take(2)) {
          hit(
            neighbor,
            damage * .4,
            primary: false,
            allowChain: false,
            source: 'expedition',
          );
        }
      }
    }
    if (shapedCharge && firstHit != null) {
      expeditionBurst(
        firstHit.position,
        cue: ExpeditionCue.breach,
        radius: 105,
        damage: damage * .75,
        targets: 3,
        shove: 75,
      );
    }
  }

  void explode(
    Vector2 position, {
    required double radius,
    required double damage,
    WeaponReaction reaction = WeaponReaction.grenade,
    bool grenade = false,
    bool allowFragments = true,
    int releaseId = 0,
    double releaseBonus = 0,
  }) {
    final pressureRadius = grenade ? radius + 130 : radius;
    game.audio.play('blast.wav');
    game.reserveWeaponPatch();
    game.addCombatEffect(
      CombatEffect(
        position: position.clone(),
        radius: pressureRadius,
        duration: .48,
        material: AttackMaterial.ember,
      ),
    );
    for (final target in game.liveEnemies.toList()) {
      final body = game.crowdRadius(target);
      final distance = game.targetDistance(target, position, body: body) + body;
      if (grenade &&
          distance > radius + body &&
          distance <= pressureRadius + body &&
          !game.segmentBlocked(position, target.position)) {
        final direction = target.position - position;
        final falloff = (1 - (distance - radius - body) / (130 + body)).clamp(
          .35,
          1.0,
        );
        (target as CombatEnemy).receiveWeaponImpact(
          direction.isZero() ? game.myPlayer.aimDirection : direction,
          WeaponReaction.grenade.scaled(
            falloff * (1 + .10 * effect(PowerUp.blastHarness)),
            hold: true,
          ),
        );
      }
      final reach = radius + body;
      if (distance <= reach && game.targetVisible(target, position)) {
        final delta = target.position - position;
        hit(
          target,
          damage,
          primary: false,
          source: grenade ? 'grenade' : 'secondary',
          blastCenter: position.toOffset(),
          blastRadius: radius,
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
    final run = game.expedition;
    if (grenade && run != null && run.phase == ExpeditionPhase.combat) {
      if (run.signatures[ExpeditionSignature.fuseLink] case final rank?) {
        final shock = ExpeditionAftershock(
          center: position.toOffset(),
          radius: radius * (.66 + rank * .09),
          damage: 2.5 + rank * 2,
          targets: 4 + rank,
          shaped: run.fusions.contains(ExpeditionFusion.shapedCharge),
        );
        if (run.aftershocks.length >= ExpeditionAftershock.limit) {
          _detonateAftershock(run.aftershocks.removeAt(0));
        }
        run.aftershocks.add(shock);
        expeditionCue(
          position,
          ExpeditionCue.fusePrimer,
          42,
          duration: ExpeditionAftershock.delay,
        );
      }
      if (run.signatures[ExpeditionSignature.thermite] case final rank?) {
        expeditionSlag(position, 1.0 + rank * .8);
      }
    }
    if (allowFragments && rank(PowerUp.fragmentation) > 0) {
      shards(
        position,
        count: 4 + state.countRank(PowerUp.fragmentation) * 2,
        damage: damage * 0.2,
      );
    }
  }

  void expeditionSlag(Vector2 position, double damage) {
    game.audio.play(ExpeditionCue.slag.sound);
    game.addFire(
      BurningGround(
        position: position.clone(),
        damage: damage,
        expeditionSlag: true,
      ),
    );
  }

  void restoreAftershockCues() {
    for (final shock
        in game.expedition?.aftershocks ?? const <ExpeditionAftershock>[]) {
      expeditionCue(
        Vector2(shock.center.dx, shock.center.dy),
        ExpeditionCue.fusePrimer,
        42,
        duration: ExpeditionAftershock.delay,
        age: ExpeditionAftershock.delay - shock.remaining,
        sound: false,
      );
    }
  }

  void _advanceAftershocks(double dt) {
    final run = game.expedition;
    if (run == null ||
        run.phase != ExpeditionPhase.combat ||
        run.aftershocks.isEmpty) {
      return;
    }
    final due = <ExpeditionAftershock>[];
    run.aftershocks.removeWhere((shock) {
      shock.remaining -= dt;
      if (shock.remaining > 1e-8) return false;
      due.add(shock);
      return true;
    });
    for (final shock in due) {
      _detonateAftershock(shock);
    }
  }

  void _detonateAftershock(ExpeditionAftershock shock) {
    expeditionBurst(
      Vector2(shock.center.dx, shock.center.dy),
      cue: ExpeditionCue.fuse,
      radius: shock.radius,
      damage: shock.damage,
      targets: shock.targets,
      shove: 75,
      shapedCharge: shock.shaped,
    );
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
