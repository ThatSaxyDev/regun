import 'package:regun/systems/gunplay_flourish.dart';
import 'package:regun/systems/arena_machine.dart';
import 'package:regun/components/map/foundry_cart_view.dart';
import 'package:regun/systems/foundry_rail.dart';
import 'package:regun/systems/minion_navigation.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/mechanical_arrival.dart';
import 'package:regun/systems/boss_spawn.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/components/weapons/shootable_ordnance.dart';
import 'package:regun/components/enemies/ariet_boss.dart';
import 'package:regun/systems/target_shape.dart';
import 'package:regun/systems/ariet_hull.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/components/enemies/walker_boss.dart';
import 'package:uuid/uuid.dart';
import 'package:regun/presentation/freeze_focus.dart';
import 'package:regun/presentation/boss_portal.dart';
import 'package:regun/presentation/combat_status_art.dart';
import 'package:regun/models/accepted_upgrade.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/systems/friendly_impact.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_native.dart';
import 'package:regun/components/map/support_view.dart';
import 'package:regun/systems/boss_attack_shape.dart';
import 'package:regun/models/boss_history.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/models/solo_recovery.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/training_pressure.dart';
import 'package:regun/models/economy/scrap_reward.dart';
import 'package:regun/components/ui/boss_victory.dart';
import 'package:regun/presentation/arena_viewport.dart';
import 'package:regun/systems/weapon_mobility.dart';
import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/systems/arsenal_system.dart';
import 'package:regun/systems/burst_fire_clock.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/components/weapons/grenade_component.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/components/ui/damage_feedback.dart';
import 'package:regun/presentation/player_entrance.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/systems/enemy_tactics.dart';
import 'package:regun/systems/crowd_occupancy.dart';
import 'package:regun/systems/boss_encounter_runtime.dart';
import 'package:regun/components/enemies/boss_attack.dart';
import 'package:regun/components/enemies/boss_weak_point.dart';
import 'package:regun/components/enemies/expansion_boss.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/components/enemies/spawn_warning.dart';
import 'package:regun/components/weapons/death_burst.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:flutter/services.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/pattern_boss.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/enemies/demon_boss_component.dart';
import 'package:regun/components/enemies/hostile_area.dart';
import 'package:regun/components/map/arena_scenery.dart';
import 'package:regun/components/map/supply_drop_view.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/systems/combat_system.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/systems/encounter_director.dart';

import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/components/game_utils/player_component.dart';
import 'package:regun/components/map/map_component.dart';
import 'package:regun/components/movement/boost_component.dart';
import 'package:regun/components/movement/game_joystick_component.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/mine_component.dart';
import 'package:regun/components/weapons/reload_component.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/repeating_action.dart';
import 'package:regun/utils/soloud_play.dart';

part 'systems/solo_recovery_runtime.dart';

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale, RiverpodGameMixin {
  RegunGame(
    this.context, {
    this.loadout = const Loadout(),
    this.resumeSnapshot,
    this.startPaused = false,
    this.upgradeFeelMode = UpgradeFeelMode.full,
    this.reviewControlledSpawns = false,
    RunStore? runStore,
    this.recoveryTransport,
  }) : runStore = runStore ?? RunStore.shared,
       super(camera: CameraComponent(viewport: ArenaViewport()));

  final BuildContext context;
  Loadout loadout;
  final bool startPaused;
  final UpgradeFeelMode upgradeFeelMode;
  final bool reviewControlledSpawns;
  MechanicalTrial? mechanicalTrial;
  bool get walkerTrial => mechanicalTrial == MechanicalTrial.walker;
  set walkerTrial(bool value) {
    if (value) {
      mechanicalTrial = MechanicalTrial.walker;
    } else if (walkerTrial) {
      mechanicalTrial = null;
    }
  }

  bool get arietTrial => mechanicalTrial == MechanicalTrial.ariet;
  bool get mechanicalTrialActive => mechanicalTrial != null;
  bool get lodestarTrial => mechanicalTrial == MechanicalTrial.lodestar;
  LodestarBoss? lodestarCandidate;
  ArietBoss? arietCandidate;
  WalkerBoss? walkerCandidate;
  late final upgradePresentation = UpgradePresentationController(
    mode: upgradeFeelMode,
  );
  final upgradeArt = UpgradeArtLease();
  final statusArt = CombatStatusArt();
  final confirmationHolding = ValueNotifier<bool>(false);
  bool get presentationHeld => upgradePresentation.holding;
  bool get inputBlocked =>
      playerEntrance.active ||
      presentationHeld ||
      bossReveal.active ||
      mechanicalArrival.active;
  void _acceptedUpgrade() {
    final reward = gameNotifier.acceptedUpgrade.value;
    if (reward == null) return;
    _upgradePulsePending = true;
    if (upgradePresentation.accept(
      reward,
      reducedMotion: preferences.reducedMotion,
      rook: loadout.character == CharacterType.rook,
    )) {
      if (loadout.character == CharacterType.rook) {
        upgradeArt.prewarm([reward.family]);
      } else {
        upgradeArt.clear();
      }
      confirmationHolding.value = true;
      resetInput();
      audio.play('reload_carbine_1.wav');
      if (preferences.haptics) HapticFeedback.selectionClick();
    }
  }

  final RunStore runStore;
  final Map<String, dynamic>? resumeSnapshot;
  late String runId;
  String _recordOwner = 'guest', _recordEpoch = '0';
  SoloRecovery recovery = SoloRecovery(owner: 'guest', startingScrap: 0);
  bool applicationActive = true;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  recoveryTransport;
  bool _settled = false;
  bool _settlementSaved = false, _waitingToRestart = false;
  bool assisted = false;
  int trainingStep = 0, shotsFired = 0, dashCount = 0, manualReloads = 0;
  final _trainingOrigin = Vector2.zero();
  String get trainingHint => switch (trainingStep) {
    0 => 'Move with the movement stick',
    1 => 'Aim and fire with the aiming stick',
    2 => 'Dash while moving',
    3 => 'Fire, then reload',
    4 => 'Collect XP and choose an upgrade',
    _ => 'Training complete',
  };
  Future<void> completeTraining() async {
    await preferences.completeTraining();
  }

  double _checkpointElapsed = 0;
  Set<String> newUnlocks = {};
  String? saveIssue;
  Future<void>? _settlement;

  late CombatSystem combat;
  final random = RunRandom(DateTime.now().microsecondsSinceEpoch);
  double _fireCooldown = 0;
  final burstFire = BurstFireClock();
  ArsenalSystem? arsenal;
  int _nextCombatId = 1;
  bool _weaponArtHeld = false, _cinderArtHeld = false, _survivorArtHeld = false;
  bool _ringArtHeld = false;
  bool get ringArtReady => _ringArtHeld;
  int _trainingWeaponEpoch = 0;
  static const maxProjectiles = 256;
  late final supportCombat = SupportNative(this);
  static const maxHostileProjectiles = 128;
  final _projectiles = <BulletComponent>{};
  final _hostileProjectiles = <PositionComponent>{};
  final _effects = <CombatEffect>{};
  final _fires = <BurningGround>{};
  final _mines = <MineComponent>{};
  final _hazards = <HostileArea>{};
  final _bossAttacks = <BossAttack>{};
  final weakPoints = <BossWeakPoint>{};
  final bossEncounter = BossEncounterRuntime();
  final _bossDamageTaken = <PositionComponent, bool>{};
  bool bossRush = false;
  int bossRushRound = 0;
  double bossRushWait = 0;
  final _rushBag = <BossKind>[];
  Iterable<PositionComponent> get bosses => bossEncounter.live;
  PositionComponent? get activeBoss => bosses.isEmpty ? null : bosses.first;
  set activeBoss(PositionComponent? actor) {
    if (actor == null) {
      bossEncounter.clear();
    } else {
      if (actor is CombatEnemy && actor.combatId == 0) {
        actor.combatId = _nextCombatId++;
      }
      bossEncounter.add(actor);
    }
  }

  Iterable<WalkerBoss> get walkerActors sync* {
    yield* bosses.whereType<WalkerBoss>();
    final trial = walkerCandidate;
    if (trial != null && !bosses.contains(trial)) yield trial;
  }

  Iterable<PositionComponent> get projectileTargets sync* {
    yield* liveEnemies;
    for (final robot in walkerActors) {
      yield* robot.rocketTargets;
    }
    yield* arietCandidate?.rocketTargets ?? const <ShootableOrdnance>[];
    yield* lodestarCandidate?.mineTargets ?? const <ShootableOrdnance>[];
    yield* weakPoints.where((p) => !p.isRemoving && !p.combatHealth.isDead);
  }

  PositionComponent projectileOwner(PositionComponent target) =>
      target is BossWeakPoint ? target.owner : target;

  bool canStageBossMove(int count) =>
      _bossAttacks.length + _hazards.length + count <= 8;

  bool registerBossAttack(BossAttack attack) {
    if (attack.owner.isDead) return false;
    if (_bossAttacks.contains(attack)) return true;
    if (_bossAttacks.length + _hazards.length >= 8) return false;
    _bossAttacks.add(attack);
    return true;
  }

  bool addBossAttack(BossAttack attack) {
    if (!registerBossAttack(attack)) return false;
    world.add(attack);
    return true;
  }

  void unregisterBossAttack(BossAttack attack) => _bossAttacks.remove(attack);
  bool claimBossAttack(PositionComponent actor) => bossEncounter.claim(actor);
  void releaseBossAttack(PositionComponent actor) =>
      bossEncounter.release(actor);
  bool _lingeringBossAttack(PositionComponent actor) {
    final health = (actor as CombatEnemy).combatHealth;
    return _bossAttacks.any((a) => !a.isRemoving && a.owner == health) ||
        _hazards.any((a) => !a.isRemoving && a.ownerHealth == health) ||
        _hostileProjectiles.any(
          (shot) =>
              shot is ShadowProjectile &&
              !shot.isRemoving &&
              shot.ownerHealth == health,
        );
  }

  List<Vector2> clipBossPath(List<Vector2> path) {
    if (path.isEmpty) return [];
    final result = [path.first.clone()];
    for (final proposed in path.skip(1)) {
      final end = proposed.clone();
      geometry.constrain(end, 35);
      final start = result.last;
      if (start.distanceToSquared(end) < .01) continue;
      if (segmentBlocked(start, end)) {
        var lo = 0.0, hi = 1.0;
        for (var i = 0; i < 12; i++) {
          final mid = (lo + hi) / 2;
          if (segmentBlocked(start, start + (end - start) * mid)) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        result.add(start + (end - start) * lo);
        break;
      }
      result.add(end);
    }
    if (result.length == 1) result.add(result.first.clone());
    return result;
  }

  bool bossMoveHasEscape(List<AttackCue> cues) {
    // Delayed echoes are separate beats, not simultaneous walls.
    for (final cue in cues) {
      final time = cue.delay + cue.warning;
      final overlapping = cues
          .where(
            (other) =>
                other.delay + other.warning <= time + .001 && other.end > time,
          )
          .toList();
      if (!_bossBeatHasEscape(overlapping, cue.warning)) return false;
    }
    return true;
  }

  bool _bossBeatHasEscape(List<AttackCue> cues, double warning) {
    final budget = gameState.movementSpeed * warning * .85;
    final origin = myPlayer.position;
    // Connected search through floor and current body occupancy. Candidate
    // points must avoid the active beat and existing floor hazards.
    final queue = <Vector2>[origin.clone()];
    final seen = <(int, int)>{(0, 0)};
    final distances = <(int, int), double>{(0, 0): 0};
    for (var i = 0; i < queue.length && i < 225; i++) {
      final point = queue[i];
      final key = (
        ((point.x - origin.x) / 45).round(),
        ((point.y - origin.y) / 45).round(),
      );
      final safe =
          cues.every((cue) => !cue.shape.hits(point, 1, body: 32)) &&
          _hazards.every(
            (area) =>
                area.isRemoving ||
                point.distanceToSquared(area.position) >
                    pow(area.radius + 32, 2),
          );
      if (safe) return true;
      for (final direction in [
        Vector2(45, 0),
        Vector2(-45, 0),
        Vector2(0, 45),
        Vector2(0, -45),
      ]) {
        final next = point + direction;
        final nextKey = (
          ((next.x - origin.x) / 45).round(),
          ((next.y - origin.y) / 45).round(),
        );
        final travel = distances[key]! + 45;
        if (travel > budget || !seen.add(nextKey)) continue;
        final constrained = next.clone();
        geometry.constrain(constrained, 32);
        if (constrained.distanceToSquared(next) > 1 ||
            segmentBlocked(point, next)) {
          continue;
        }
        if (liveEnemies.any(
          (enemy) =>
              next.distanceToSquared(enemy.position) <
              pow(crowdRadius(enemy) + 30, 2),
        )) {
          continue;
        }
        distances[nextKey] = travel;
        queue.add(next);
      }
    }
    return false;
  }

  final _bursts = <DeathBurst>{};
  void unregisterBurst(DeathBurst burst) => _bursts.remove(burst);
  void addDeathParticles(Vector2 position, {required Color color}) {
    if (_bursts.length >= 32 || preferences.reducedMotion) return;
    final burst = DeathBurst(position: position.clone(), color: color);
    _bursts.add(burst);
    world.add(burst);
  }

  double get playerWalkSpeed {
    final weight = WeaponMobility.of(loadout.weapon);
    final recovered =
        (1 - weight) * min(.40, .08 * gameState.effectRank(PowerUp.sureFoot));
    return gameState.movementSpeed *
        (weight + recovered) *
        (gameState.reloading
            ? 1 + .04 * gameState.effectRank(PowerUp.braceLoader)
            : 1);
  }

  int get readyPerkFlags {
    if (gameState.reloading ||
        gameState.noOfBullets <= 0 ||
        gameState.health <= 0) {
      return 0;
    }
    return (loadout.weapon.hasLastRound &&
                gameState.noOfBullets == 1 &&
                gameState.rank(PowerUp.lastShell) > 0
            ? 1
            : 0) |
        (loadout.weapon.hasLastRound &&
                _breachCharged &&
                gameState.rank(PowerUp.breachLoader) > 0
            ? 2
            : 0) |
        (gameState.effectRank(PowerUp.measuredShot) > 0 &&
                gameNotifier.survivor.rest >= .8 - 1e-8
            ? 4
            : 0);
  }

  double primaryRelease(double amount) {
    myPlayer.mechanicFeedback.release(readyPerkFlags);
    return amount *
        gameNotifier.survivor.release(
          loadout.character,
          gameState.effectRank(PowerUp.measuredShot),
          continuous: loadout.weapon.isContinuous,
        );
  }

  double burnMultiplier(PositionComponent enemy) =>
      (loadout.character == CharacterType.moth ? 1.25 : 1) *
      ((enemy is CombatEnemy &&
              (enemy.isBoss || (enemy is ArenaEnemy && enemy.elite)))
          ? 1 + .10 * gameState.effectRank(PowerUp.scouringHeat)
          : 1);
  int get projectileCount =>
      _projectiles.length +
      (arsenal?.projectileReservations ?? 0) +
      supportCombat.runtime.rounds.length;
  ({int arena, int visible, int pending}) get enemyPopulation {
    var arena = 0, visible = 0, pending = 0;
    final view = camera.visibleWorldRect.inflate(60);
    for (final enemy in [..._enemies, ...bosses]) {
      if (enemy.isRemoving || enemy.isRemoved) continue;
      arena++;
      if (!enemy.isLoaded) pending++;
      if (view.contains(enemy.position.toOffset())) visible++;
    }
    return (arena: arena, visible: visible, pending: pending);
  }

  bool get canReinforce {
    final population = enemyPopulation;
    if (loadout.training) {
      return !bossRush &&
          population.arena < trainingPressure.arenaLimit &&
          population.visible < trainingPressure.nearbyTarget;
    }
    return director.canReinforce(
      arena: population.arena,
      visible: population.visible,
    );
  }

  bool registerProjectile(BulletComponent bullet) {
    if (_projectiles.contains(bullet)) return true;
    if (projectileCount >= maxProjectiles) return false;
    _projectiles.add(bullet);
    return true;
  }

  bool addProjectile(BulletComponent bullet) {
    if (!registerProjectile(bullet)) return false;
    world.add(bullet);
    return true;
  }

  void unregisterProjectile(BulletComponent bullet) =>
      _projectiles.remove(bullet);
  bool registerHostileProjectile(PositionComponent bullet) {
    if (_hostileProjectiles.length >= maxHostileProjectiles) return false;
    _hostileProjectiles.add(bullet);
    return true;
  }

  void clearHostileShots(Vector2 origin, double radius) {
    final lodestar = lodestarCandidate;
    if (lodestar != null && lodestar.prepared && !lodestar.retired) {
      lodestar.fight.shots.removeWhere(
        (s) => (s.position - origin.toOffset()).distance <= radius + 6,
      );
    }
    final ariet = arietCandidate;
    if (ariet != null && ariet.prepared && !ariet.retired) {
      ariet.fight.rounds.removeWhere(
        (r) => (r.position - origin.toOffset()).distance <= radius + r.radius,
      );
    }
    for (final walker in walkerActors.where((w) => w.prepared)) {
      walker.fight.rounds.removeWhere(
        (round) =>
            (round.position - origin.toOffset()).distance <=
            radius + round.radius,
      );
    }
    for (final shot in _hostileProjectiles.toList()) {
      final reach = radius + min(shot.size.x, shot.size.y) / 2;
      if (shot.position.distanceToSquared(origin) <= reach * reach) {
        shot.removeFromParent();
      }
    }
  }

  void unregisterHostileProjectile(PositionComponent bullet) =>
      _hostileProjectiles.remove(bullet);
  void unregisterEffect(CombatEffect effect) => _effects.remove(effect);
  void unregisterFire(BurningGround fire) => _fires.remove(fire);
  void unregisterMine(MineComponent mine) => _mines.remove(mine);
  void unregisterHazard(HostileArea hazard) => _hazards.remove(hazard);
  void addFire(BurningGround fire) {
    if (_fires.length >= 12) return;
    _fires.add(fire);
    world.add(fire);
  }

  void addMineAt(Vector2 position) {
    if (_mines.length >= 12) return;
    final mine = MineComponent(position: position);
    _mines.add(mine);
    world.add(mine);
  }

  Map<String, int> get runtimeCounts => {
    'enemies': _enemies.length,
    'visibleEnemies': enemyPopulation.visible,
    'pendingEnemies': enemyPopulation.pending,
    'populationLimit': loadout.training
        ? trainingPressure.arenaLimit
        : director.populationLimit,
    'xp': _coins.length,
    'playerProjectiles': projectileCount,
    'hostileProjectiles':
        (arietCandidate?.prepared == true && !arietCandidate!.retired
            ? arietCandidate!.fight.rounds.length
            : 0) +
        _hostileProjectiles.length +
        walkerActors
            .where((w) => w.prepared)
            .fold<int>(0, (n, w) => n + w.fight.rounds.length),
    'effects': _effects.length + (arsenal?.effectCount ?? 0),
    'fire': _fires.length,
    'mines': _mines.length,
    'hazards': _hazards.length + _bossAttacks.length,
    'particles': _bursts.length * 8,
  };
  Iterable<PositionComponent> get liveEnemies sync* {
    for (final enemy in _enemies) {
      if (enemy is CombatEnemy &&
          enemy.isLoaded &&
          !enemy.isRemoving &&
          !enemy.isRemoved &&
          !enemy.combatHealth.isDead) {
        yield enemy;
      }
    }
    for (final boss in bosses) {
      if (boss.isLoaded &&
          !boss.isRemoving &&
          !(boss as CombatEnemy).combatHealth.isDead) {
        yield boss;
      }
    }
  }

  double enemyRadius(PositionComponent enemy) => enemy is LodestarBoss
      ? 500
      : enemy is ArietBoss
      ? ArietHull.enclosingRadius
      : enemy is ArietEscort
      ? 88 * ArietEscort.rigScale
      : enemy is ShootableOrdnance
      ? enemy.hitRadius
      : enemy is WalkerBoss
      ? 88
      : enemy is BossWeakPoint
      ? 26
      : enemy is BossEncounter
      ? (enemy as BossEncounter).kind.bodyRadius
      : min(enemy.size.x, enemy.size.y) * 0.3;

  /// Narrow queries opt in only for compound machinery. One target stays one
  /// damage/proc owner even when multiple visible regions overlap.
  double? targetContact(
    PositionComponent target,
    Vector2 from,
    Vector2 to,
    double padding, {
    double? body,
    bool coverToCenter = true,
  }) {
    if (target is ShapedTarget) {
      if (BulletComponent.segmentDistanceSquared(target.position, from, to) >
          pow(enemyRadius(target) + padding, 2)) {
        return null;
      }
      double? best;
      for (final region in (target as ShapedTarget).targetShape) {
        final contact = region.contact(
          from.toOffset(),
          to.toOffset(),
          padding: padding,
        );
        if (contact != null && (best == null || contact < best)) best = contact;
      }
      if (best != null) {
        final delta = to - from;
        final point = delta.isZero() ? from : from + delta.normalized() * best;
        if (segmentBlocked(from, point)) return null;
        if (target is LocalDamageTarget) {
          (target as LocalDamageTarget).noteDamageContact(point.toOffset());
        }
      }
      return best;
    }
    final radius = (body ?? enemyRadius(target)) + padding;
    return BulletComponent.segmentDistanceSquared(target.position, from, to) <=
                radius * radius &&
            (!coverToCenter || !segmentBlocked(from, target.position))
        ? BulletComponent.contactDistance(target.position, from, to, radius)
        : null;
  }

  double targetDistance(
    PositionComponent target,
    Vector2 origin, {
    double? body,
  }) {
    if (target is ShapedTarget) {
      final regions = (target as ShapedTarget).targetShape.toList();
      if (target is LocalDamageTarget && regions.isNotEmpty) {
        regions.sort(
          (a, b) => a
              .distance(origin.toOffset())
              .compareTo(b.distance(origin.toOffset())),
        );
        final r = regions.first;
        (target as LocalDamageTarget).noteDamageContact((r.a + r.b) / 2);
      }
      return regions.fold<double>(
        double.infinity,
        (best, r) => min(best, r.distance(origin.toOffset())),
      );
    }
    return max(
      0,
      target.position.distanceTo(origin) - (body ?? enemyRadius(target)),
    );
  }

  bool targetVisible(PositionComponent target, Vector2 from) {
    if (target is! ShapedTarget) return !segmentBlocked(from, target.position);
    return (target as ShapedTarget).targetShape.any(
      (r) => !segmentBlocked(
        from,
        Vector2((r.a.dx + r.b.dx) / 2, (r.a.dy + r.b.dy) / 2),
      ),
    );
  }

  bool targetCone(
    PositionComponent target,
    Vector2 origin,
    Vector2 direction,
    double range,
    double halfAngle, {
    double? body,
  }) {
    final regions = target is ShapedTarget
        ? (target as ShapedTarget).targetShape
        : [
            TargetCapsule(
              target.position.toOffset(),
              target.position.toOffset(),
              body ?? enemyRadius(target),
            ),
          ];
    for (final r in regions) {
      final count = ((r.b - r.a).distance / 16).ceil().clamp(1, 16);
      for (var i = 0; i <= count; i++) {
        final point = Offset.lerp(r.a, r.b, i / count)!,
            delta = Vector2(point.dx - origin.x, point.dy - origin.y);
        if (delta.length > range + r.radius ||
            segmentBlocked(origin, Vector2(point.dx, point.dy))) {
          continue;
        }
        if (delta.isZero() ||
            acos(delta.normalized().dot(direction).clamp(-1.0, 1.0)) <=
                halfAngle +
                    asin(
                      (r.radius / max(r.radius, delta.length)).clamp(0.0, 1.0),
                    )) {
          if (target is LocalDamageTarget) {
            (target as LocalDamageTarget).noteDamageContact(point);
          }
          return true;
        }
      }
    }
    return false;
  }

  bool segmentBlocked(Vector2 start, Vector2 end) =>
      geometry.blocked(start, end);
  void constrainActor(
    Vector2 position,
    double radius, {
    double? bottomExtent,
  }) => geometry.constrain(position, radius, bottomExtent: bottomExtent);
  final enemyTactics = EnemyTactics();
  final minionNavigation = MinionNavigation();
  final _navigationPositions = <int, Offset>{};
  final _navigationOwners = <int, PositionComponent>{};
  final _steppedMinions = <PositionComponent>{};
  Offset? _navigationPlayerPosition;
  Offset _navigationPlayerVelocity = Offset.zero;
  double _navigationLastDt = 0;
  bool _advancingMinions = false;
  bool skipManagedMinion(PositionComponent actor) =>
      _steppedMinions.contains(actor);

  bool _ordinaryMinion(PositionComponent e) =>
      e is EnemyComponent ||
      e is Enemy2Component ||
      e is Enemy3Component ||
      e is ArenaEnemy;

  void _rebuildNavigation(double dt) {
    final bodies = <NavigationBody>[];
    final activeIds = <int>{};
    for (final e in {..._enemies, ...bosses}) {
      if (e.isRemoving || e.isRemoved || e is! CombatEnemy) continue;
      if (e.combatId == 0) e.combatId = _nextCombatId++;
      activeIds.add(e.combatId);
      _navigationOwners[e.combatId] = e;
      final at = e.position.toOffset();
      final before = _navigationPositions[e.combatId];
      var velocity = before == null || _navigationLastDt <= 0
          ? Offset.zero
          : (at - before) / _navigationLastDt;
      if ((at - (before ?? at)).distance > 120 || velocity.distance > 2200) {
        velocity = Offset.zero;
      }
      if ((e is ShadowBossComponent &&
              e.phase != ShadowPhase.pursuit &&
              e.phase != ShadowPhase.dash) ||
          (e is PatternBoss &&
              e.phase != PatternBossPhase.approach &&
              e.phase != PatternBossPhase.active) ||
          (e is ExpansionBoss && e.phase != ExpansionPhase.approach)) {
        velocity = Offset.zero;
      }
      if ((e is Enemy2Component && e.isAttacking) ||
          (e is Enemy3Component && e.isAttacking) ||
          (e is ArenaEnemy && e.phase != 0) ||
          e.freezeHeld ||
          e.impactHeld) {
        final memory = minionNavigation.memories[e.combatId];
        if (memory != null) {
          memory.waiting = 0;
          memory.progressAge = 0;
          memory.anchor = at;
        }
      }
      _navigationPositions[e.combatId] = at;
      if (isAirborneActor(e)) continue;
      final compound = e is CompoundGroundActor
          ? (e as CompoundGroundActor).groundShape.toList()
          : null;
      if (compound != null && compound.isEmpty) continue;
      bodies.add(
        NavigationBody(
          id: e.combatId,
          position: at,
          radius: crowdRadius(e),
          velocity: velocity,
          contact:
              e is Enemy2Component ||
              e is EnemyComponent ||
              (e is ArenaEnemy &&
                  e.kind != EnemyKind.ranged &&
                  e.kind != EnemyKind.nest &&
                  e.kind != EnemyKind.sentinel),
          boss: e.isBoss,
          motion: e is NavigationMotionSource
              ? (e as NavigationMotionSource).navigationMotion
              : null,
          shapes: compound ?? const [],
        ),
      );
    }
    _navigationPositions.removeWhere((id, _) => !activeIds.contains(id));
    _navigationOwners.removeWhere((id, _) => !activeIds.contains(id));
    minionNavigation.rebuild(bodies);
    final player = myPlayer.position.toOffset();
    final before = _navigationPlayerPosition;
    _navigationPlayerVelocity =
        before == null ||
            _navigationLastDt <= 0 ||
            (player - before).distance > 120
        ? Offset.zero
        : (player - before) / _navigationLastDt;
    _navigationPlayerPosition = player;
    _navigationLastDt = dt;
  }

  bool _navigationClear(Offset from, Offset to, double radius) {
    final p = Vector2(to.dx, to.dy);
    geometry.constrain(p, radius);
    return (p.toOffset() - to).distance < .01 &&
        !geometry.solids.any(
          (r) => ArenaGeometry.crosses(
            Vector2(from.dx, from.dy),
            Vector2(to.dx, to.dy),
            r.inflate(radius - .01),
          ),
        );
  }

  void _advanceOrdinaryMinions(double dt) {
    if (gameState.gameplayState != GameplayState.playing || dt <= 0) return;
    _rebuildNavigation(dt);
    // Loaded arrivals still reserve space, but Flame must mount them before
    // their first update so onMount state (such as Scorpion gait) exists.
    final actors = liveEnemies
        .where((actor) => actor.isMounted && _ordinaryMinion(actor))
        .toList();
    actors.sort((a, b) {
      final ai = (a as CombatEnemy).combatId, bi = (b as CombatEnemy).combatId;
      final aw = minionNavigation.memories[ai]?.waiting ?? 0;
      final bw = minionNavigation.memories[bi]?.waiting ?? 0;
      final waiting = bw.compareTo(aw);
      return waiting != 0 ? waiting : ai.compareTo(bi);
    });
    _advancingMinions = true;
    try {
      for (final actor in actors) {
        if (actor.isRemoving || (actor as CombatEnemy).combatHealth.isDead) {
          continue;
        }
        actor.update(dt);
        _steppedMinions.add(actor);
      }
    } finally {
      _advancingMinions = false;
    }
  }

  final _temporaryCoverRouter = ObstacleRouter();
  final crowdOccupancy = CrowdOccupancy();
  double crowdRadius(PositionComponent actor) => actor is ArietBoss
      ? ArietRig.navigationRadius
      : actor is ArietEscort
      ? 88 * ArietEscort.rigScale
      : actor is WalkerBoss
      ? 88
      : actor is BossEncounter
      ? (actor as BossEncounter).kind.bodyRadius
      : (min(actor.size.x, actor.size.y) * .45).clamp(30.0, 52.0);

  bool reserveEnemySpace(
    PositionComponent actor, {
    double minPlayerDistance = 0,
    Rect? excludedArea,
  }) {
    // Ariet arrivals validate their solid/bounds footprint in _placeAriet.
    // An airborne carrier must never reserve floor space, even during mounting.
    if (actor is ArietBoss || actor is CompoundGroundActor) {
      crowdOccupancy.forget(actor);
      return true;
    }
    return crowdOccupancy.place(
      actor,
      crowdRadius(actor),
      (point) => geometry.constrain(point, crowdRadius(actor)),
      allowed: (point) =>
          (excludedArea == null || !excludedArea.contains(point.toOffset())) &&
          (minPlayerDistance == 0 ||
              point.distanceToSquared(myPlayer.position) >=
                  minPlayerDistance * minPlayerDistance),
    );
  }

  Vector2 enemyIntent(PositionComponent actor, EnemyKind kind) =>
      EnemyTactics.intent(
        kind,
        actor.position,
        myPlayer.position,
        Vector2(_navigationPlayerVelocity.dx, _navigationPlayerVelocity.dy),
        MinionNavigation.sideFor(actor is CombatEnemy ? actor.combatId : 0),
      );

  bool isAirborneActor(PositionComponent actor) =>
      actor is ArietBoss ||
      (actor is ArenaEnemy && actor.airborne) ||
      (actor is WalkerBoss &&
          actor.prepared &&
          [WalkerPhase.charge, WalkerPhase.brake].contains(actor.fight.phase));

  double _crowdCueCooldown = 0;
  PositionComponent? _crowdCueActor;
  double _crowdCueDistanceSquared = 0;

  void playEnemyMovement(String asset, Vector2 origin, double range) {
    unawaited(
      audio.playEnemyMovement(
        asset,
        (origin - myPlayer.position).toOffset(),
        range,
      ),
    );
  }

  void moveActor(
    PositionComponent actor,
    Vector2 direction,
    double speed,
    double dt, {
    double radius = 30,
    bool avoidCrowd = true,
    bool airborne = false,
  }) {
    if (actor is! PlayerComponent) {
      speed *= 1 + min(0.5, (director.cycle - 1) * 0.08);
      if (actor is ArenaEnemy && actor.elite) speed *= 1.15;
    }
    if (actor is CombatEnemy) {
      // Committed leaps retain their exact travel timing; ordinary pursuit is
      // braked by the stronger response, never multiplicatively immobilized.
      final fieldStride = avoidCrowd ? arsenal?.sporeStride(actor) ?? 1.0 : 1.0;
      speed *= min(actor.impactStride, fieldStride);
    }
    if (actor is CombatEnemy && !actor.isBoss && avoidCrowd) {
      if (!_advancingMinions) _rebuildNavigation(dt);
      direction = _temporaryCoverRouter.steer(
        actor,
        direction,
        myPlayer.position,
        geometry,
        radius: max(radius, crowdRadius(actor)),
        side: MinionNavigation.sideFor(actor.combatId),
        dt: dt,
      );
      final steered = minionNavigation.steer(
        actor.combatId,
        actor.position.toOffset(),
        direction.toOffset(),
        speed,
        dt,
        target: myPlayer.position.toOffset(),
        clear: _navigationClear,
      );
      direction = Vector2(steered.dx, steered.dy);
    }
    if (actor is CombatEnemy) {
      final listen =
          _crowdCueCooldown <= 0 &&
          actor is EnemyComponent &&
          avoidCrowd &&
          !airborne;
      final beforeX = actor.position.x, beforeY = actor.position.y;
      crowdOccupancy.move(
        actor,
        direction * (speed * dt),
        radius: crowdRadius(actor),
        constrain: (point) {
          _constrainEnemyMove(actor, point, max(radius, crowdRadius(actor)));
        },
        slide: avoidCrowd,
        reserve: !airborne,
        blocks: airborne
            ? (other) => other is CombatEnemy && other.isBoss
            : null,
        side: enemyTactics.side(actor),
      );
      if (listen &&
          ((actor.position.x - beforeX).abs() > .4 ||
              (actor.position.y - beforeY).abs() > .4)) {
        final distance = actor.position.distanceToSquared(myPlayer.position);
        if (distance < 360 * 360 &&
            (_crowdCueActor == null || distance < _crowdCueDistanceSquared) &&
            !segmentBlocked(actor.position, myPlayer.position)) {
          _crowdCueActor = actor;
          _crowdCueDistanceSquared = distance;
        }
      }
      return;
    }
    final previous = actor.position.clone();
    geometry.move(
      actor.position,
      direction * (speed * dt),
      radius,
      bottomExtent: actor is PlayerComponent ? actor.boundaryFootExtent : null,
    );
    if (actor is! PlayerComponent &&
        actor.position.distanceToSquared(previous) <
            speed * speed * dt * dt * 0.2 &&
        !direction.isZero()) {
      final tangent = Vector2(-direction.y, direction.x);
      actor.position.addScaled(tangent, speed * dt);
      constrainActor(actor.position, radius);
    }
  }

  void _constrainEnemyMove(
    PositionComponent actor,
    Vector2 point,
    double radius,
  ) {
    geometry.constrain(point, radius);
    if (!(arsenal?.frontier.constrainCaptured(actor, point) ?? false)) return;
    final valid = point.clone();
    geometry.constrain(valid, radius);
    // A shrinking ring must never push a body through solid cover. If the two
    // constraints have no shared destination, occupancy keeps the current body.
    if (valid.distanceToSquared(point) > .001) point.setFrom(actor.position);
  }

  void clearMinionsInBossShape(
    BossAttackShape shape,
    double progress, {
    double previous = 0,
  }) {
    for (final enemy in liveEnemies.toList()) {
      if (enemy is CombatEnemy &&
          !enemy.isBoss &&
          shape.hits(
            enemy.position,
            progress,
            previous: previous,
            body: crowdRadius(enemy),
          ) &&
          !segmentBlocked(shape.points.first, enemy.position)) {
        enemy.crushByBoss();
      }
    }
  }

  void clearMinionsInBossPath(Vector2 from, Vector2 to, double radius) {
    bool touches(PositionComponent e) =>
        BulletComponent.segmentDistanceSquared(e.position, from, to) <=
            pow(radius + crowdRadius(e), 2) &&
        !segmentBlocked(from, e.position);
    for (final warning in _spawnWarnings.toList()) {
      if (touches(warning.enemy)) warning.cancel();
    }
    for (final enemy in liveEnemies.toList()) {
      if (enemy is CombatEnemy && !enemy.isBoss && touches(enemy)) {
        enemy.crushByBoss();
      }
    }
  }

  void moveTo(
    PositionComponent actor,
    Vector2 target,
    double radius, {
    bool crushMinions = false,
    bool slide = false,
  }) => crowdOccupancy.move(
    actor,
    target - actor.position,
    radius: crowdRadius(actor),
    constrain: (point) {
      _constrainEnemyMove(actor, point, max(radius, crowdRadius(actor)));
    },
    slide: slide,
    reserve: !isAirborneActor(actor),
    blocks: isAirborneActor(actor)
        ? (other) => other is CombatEnemy && other.isBoss
        : null,
    beforeStep: crushMinions && actor is CombatEnemy && actor.isBoss
        ? (from, to) => clearMinionsInBossPath(from, to, crowdRadius(actor) + 4)
        : null,
  );

  void addCombatEffectForKill(
    Vector2 position, {
    double radius = 45,
    Sprite? remains,
    bool flipRemains = false,
  }) => addCombatEffect(
    CombatEffect(
      position: position.clone(),
      radius: radius,
      remains: remains,
      flipRemains: flipRemains,
      duration: remains == null ? .25 : .65,
    ),
  );
  void addHostileArea(
    Vector2 position, {
    double radius = 130,
    double warning = 0.9,
    double active = 0.25,
    int damage = 1,
    String cause = 'Ground strike',
    bool poison = false,
    BossKind? bossKind,
    CombatHealth? ownerHealth,
    double initialAge = 0,
  }) {
    if (_hazards.length + _bossAttacks.length >= 8) return;
    constrainActor(position, radius);
    final hazard = HostileArea(
      position: position,
      radius: radius,
      warning: warning,
      active: active,
      damage: damage,
      cause: cause,
      poison: poison,
      ownerHealth: ownerHealth,
      bossKind: bossKind,
      initialAge: initialAge,
    );
    _hazards.add(hazard);
    world.add(hazard);
  }

  void spawnAdd(EnemyKind kind, Vector2 position) {
    _enemies.removeWhere((e) => e.isRemoved || e.isRemoving);
    if (_enemies.length >= maxEnemies) return;
    if (!canReinforce) return;
    constrainActor(position, 45);
    if (position.distanceToSquared(myPlayer.position) < 180 * 180) return;
    final enemy = ArenaEnemy(kind, position: position);
    if (!reserveEnemySpace(enemy, minPlayerDistance: 180)) return;
    _enemies.add(enemy);
    world.add(SpawnWarning(game: this, enemy: enemy));
  }

  PositionComponent? nearestEnemy(
    Vector2 position, {
    Set<PositionComponent> excluding = const {},
    double range = 800,
    bool preferMarked = false,
  }) {
    PositionComponent? nearest;
    var best = range * range;
    for (final enemy in liveEnemies) {
      if (excluding.contains(enemy)) continue;
      var distance = position.distanceToSquared(enemy.position);
      if (distance > range * range ||
          segmentBlocked(position, enemy.position)) {
        continue;
      }
      if (preferMarked && (enemy as CombatEnemy).marked) distance *= 0.1;
      if (distance < best) {
        best = distance;
        nearest = enemy;
      }
    }
    return nearest;
  }

  bool hitEnemy(
    PositionComponent enemy,
    double amount, {
    bool primary = true,
    bool weaponHit = false,
    bool allowChain = true,
    bool armorPiercing = false,
    int releaseId = 0,
    double releaseBonus = 0,
    double? travel,
    WeaponReaction? reaction,
    Vector2? direction,
    Vector2? hitPoint,
  }) {
    if (enemy is ShootableOrdnance) {
      if (gameState.gameplayState != GameplayState.playing || inputBlocked) {
        return false;
      }
      return enemy.hit(amount);
    }
    return combat.hit(
      enemy,
      amount,
      primary: primary,
      weaponHit: weaponHit,
      direction: direction,
      allowChain: allowChain,
      armorPiercing: armorPiercing,
      releaseId: releaseId,
      releaseBonus: releaseBonus,
      travel: travel,
      reaction: reaction,
      hitPoint: hitPoint?.toOffset(),
    );
  }

  void explode(
    Vector2 position, {
    required double radius,
    required double damage,
    WeaponReaction reaction = WeaponReaction.grenade,
    int releaseId = 0,
    double releaseBonus = 0,
  }) => combat.explode(
    position,
    radius: radius,
    damage: damage,
    reaction: reaction,
    releaseId: releaseId,
    releaseBonus: releaseBonus,
  );
  void addCombatEffect(CombatEffect effect) {
    if ((runtimeCounts['effects'] ?? 0) < 40) {
      _effects.add(effect);
      world.add(effect);
    }
  }

  /// A paid gameplay patch replaces a cosmetic cue at capacity, never gameplay.
  void reserveWeaponPatch() {
    if ((runtimeCounts['effects'] ?? 0) >= 40 && _effects.isNotEmpty) {
      final cosmetic = _effects.first;
      _effects.remove(cosmetic);
      cosmetic.removeFromParent();
    }
  }

  final preferences = LocalPreferences.shared;
  ControlLayout controls = const ControlLayout();
  bool _controlsLoaded = false;

  late PlayerComponent myPlayer;
  final playerEntrance = PlayerEntrance();
  bool trainingDamage = false;
  TrainingPressure trainingPressure = TrainingPressure.normal;
  final _trainingPressureClock = TrainingPressureClock();
  final _retiredActors = Expando<bool>('retired-practice-actor');
  bool isRetiredActor(PositionComponent actor) => _retiredActors[actor] == true;
  final _spawnWarnings = <SpawnWarning>{};
  void registerSpawnWarning(SpawnWarning warning) =>
      _spawnWarnings.add(warning);
  void unregisterSpawnWarning(SpawnWarning warning) =>
      _spawnWarnings.remove(warning);

  void setTrainingPressure(TrainingPressure value) {
    if (!loadout.training || trainingPressure == value) return;
    final lower = value.nearbyTarget < trainingPressure.nearbyTarget;
    trainingPressure = value;
    _trainingPressureClock.reset();
    if (lower && !bossRush) {
      final ordinary =
          _enemies
              .where((enemy) => enemy is! CombatEnemy || !enemy.isBoss)
              .toList()
            ..sort(
              (a, b) => b.position
                  .distanceToSquared(myPlayer.position)
                  .compareTo(a.position.distanceToSquared(myPlayer.position)),
            );
      for (final enemy in ordinary.take(
        max(0, ordinary.length - value.nearbyTarget),
      )) {
        _retirePracticeActor(enemy);
      }
    }
    resetInput();
    revision.value++;
  }

  int get trainingNearbyEnemies => _enemies
      .where(
        (enemy) =>
            !enemy.isRemoving &&
            !enemy.isRemoved &&
            !isRetiredActor(enemy) &&
            enemy.position.distanceToSquared(myPlayer.position) <= 750 * 750,
      )
      .length;

  void _retirePracticeActor(PositionComponent actor) {
    _retiredActors[actor] = true;
    for (final warning
        in _spawnWarnings.where((w) => identical(w.enemy, actor)).toList()) {
      warning.cancel();
    }
    if (actor.isLoaded && actor is CombatEnemy) {
      actor.combatHealth.damage(actor.combatHealth.maximum);
    }
    unregisterEnemy(actor);
    actor.removeFromParent();
  }

  void _advanceTrainingCrowd(double dt) {
    final budget = _trainingPressureClock.advance(dt, trainingPressure);
    if (budget == 0 || bossRush) return;
    if (trainingNearbyEnemies < trainingPressure.nearbyTarget) {
      // Keep the offscreen approach band alive; retire only crowds left behind.
      final outside = camera.visibleWorldRect.inflate(300);
      final distant = _enemies
          .where(
            (e) =>
                !outside.contains(e.position.toOffset()) &&
                e.position.distanceToSquared(myPlayer.position) > 850 * 850,
          )
          .take(budget)
          .toList();
      for (final enemy in distant) {
        _retirePracticeActor(enemy);
      }
    }
    for (
      var i = 0;
      i < budget &&
          trainingNearbyEnemies < trainingPressure.nearbyTarget &&
          canReinforce;
      i++
    ) {
      _spawnEnemy(_directorEnemy());
    }
  }

  PositionComponent _directorEnemy() {
    final kind = director.chooseEnemy(random);
    return switch (kind) {
      EnemyKind.scorpion => EnemyComponent(),
      EnemyKind.mummy => Enemy2Component(),
      EnemyKind.ranged => Enemy3Component(),
      _ => ArenaEnemy(
        kind,
        elite:
            director.elapsed > 150 &&
            random.nextDouble() < min(0.35, 0.12 + (director.cycle - 1) * 0.03),
      ),
    };
  }

  void setTrainingDamage(bool enabled) {
    if (!loadout.training) return;
    trainingDamage = enabled;
    if (!enabled && !playerEntrance.active) gameNotifier.refillPractice();
    resetInput();
    revision.value++;
  }

  late final MovementJoystickComponent movementJoystick;
  late final WeaponJoystickComponent weaponJoystick;
  late final BoostButtonComponent boostButtonComponent;
  late final ReloadButtonComponent reloadButtonComponent;
  late final GrenadeButtonComponent grenadeButtonComponent;
  bool _upgradePulsePending = false;
  final grenades = GrenadeInventory();
  void syncGrenadeCapacity() => grenades.setCapacity(gameState.grenadeCapacity);
  double get grenadeRecharge =>
      (GrenadeSpec.recharge(gameState.effectRank(PowerUp.grenadeRecharge)) -
              (loadout.character == CharacterType.fuse ? 2 : 0))
          .clamp(10, 18);
  Vector2 get quickGrenadeDirection {
    final movement = movementJoystick.relativeDelta;
    return movement.isZero()
        ? myPlayer.aimDirection.clone()
        : movement.normalized();
  }

  GrenadeFlight grenadeFlight(Vector2 direction, double power) {
    direction = direction.normalized();
    if (direction.isZero()) direction.setValues(1, 0);
    final start = myPlayer.position + direction * 36;
    if (geometry.solids.any(
      (r) => ArenaGeometry.crosses(myPlayer.position, start, r.inflate(8)),
    )) {
      start.setFrom(myPlayer.position);
    }
    constrainActor(start, 8);
    return GrenadeFlight(
      start.toOffset(),
      direction.toOffset() * GrenadeSpec.speed * power.clamp(.4, 1),
    );
  }

  bool throwGrenade({Vector2? aim, double power = 1}) {
    if (gameState.gameplayState != GameplayState.playing ||
        inputBlocked ||
        world.children.whereType<GrenadeComponent>().length >= 4 ||
        !grenades.spend(grenadeRecharge)) {
      return false;
    }
    final direction = aim ?? quickGrenadeDirection;
    world.add(
      GrenadeComponent(
        grenadeFlight(direction, power),
        damage:
            GrenadeSpec.damage(gameState.effectRank(PowerUp.grenadeDamage)) +
            (loadout.character == CharacterType.fuse ? 1.6 : 0),
        blastRadius: GrenadeSpec.radius(
          gameState.effectRank(PowerUp.grenadeRadius),
        ),
      ),
    );
    audio.play('grenade_throw.wav');
    return true;
  }

  final damageFeedback = DamageFeedback();
  final bossVictory = BossVictory();
  final bossReveal = BossReveal();
  final mechanicalArrival = MechanicalArrival();
  final _fireKick = Vector2.zero();
  final _fireKickFrom = Vector2.zero();
  double _fireKickTime = 0;

  static const _fireKickRise = .015;
  static const _fireKickDuration = .132;

  void showFireKick(Vector2 direction) {
    if (preferences.reducedMotion || inputBlocked || direction.isZero()) return;
    final amplitude = switch (loadout.weapon) {
      WeaponType.carbine ||
      WeaponType.burstRifle ||
      WeaponType.beltRepeater ||
      WeaponType.houndrack => 4.5,
      WeaponType.cinderHose || WeaponType.prismCutter => 3.5,
      WeaponType.shotgun ||
      WeaponType.cycloneBreacher ||
      WeaponType.frostShotgun ||
      WeaponType.revolver => 9.0,
      WeaponType.railLance ||
      WeaponType.longwatchSniper ||
      WeaponType.faultlineDriver ||
      WeaponType.mourningBell => 11.0,
      _ => 6.5,
    };
    _fireKickFrom.setFrom(_sampleFireKick());
    _fireKick.setFrom(direction.normalized() * amplitude);
    _fireKickTime = _fireKickDuration;
  }

  Vector2 _sampleFireKick() {
    if (_fireKickTime <= 0) return Vector2.zero();
    final age = _fireKickDuration - _fireKickTime;
    if (age < _fireKickRise) {
      final t = (age / _fireKickRise).clamp(0.0, 1.0);
      final eased = t * t * (3 - 2 * t);
      return _fireKickFrom + (_fireKick - _fireKickFrom) * eased;
    }
    final t = ((age - _fireKickRise) / (_fireKickDuration - _fireKickRise))
        .clamp(0.0, 1.0);
    return _fireKick * (1 - t * t * (3 - 2 * t));
  }

  double _groundKickTime = 0, _groundKickStrength = 0;
  static const _groundKickDuration = .27;

  void showGroundImpact(
    Offset at, {
    required double strength,
    bool attenuate = false,
  }) {
    if (preferences.reducedMotion) return;
    if (attenuate) {
      final distance = (at - myPlayer.position.toOffset()).distance;
      final proximity = (1 - (distance - 160) / 1100).clamp(0.0, 1.0);
      strength *= proximity * proximity;
    }
    if (strength < .2 ||
        (_groundKickTime > .19 && strength < _groundKickStrength)) {
      return;
    }
    _groundKickStrength = strength.clamp(0, 16);
    _groundKickTime = _groundKickDuration;
  }

  Vector2? _fireWorldOffset() {
    if ((_fireKickTime <= 0 && _groundKickTime <= 0) ||
        preferences.reducedMotion ||
        gameState.gameplayState != GameplayState.playing) {
      return null;
    }
    final offset = inputBlocked ? Vector2.zero() : _sampleFireKick();
    if (_groundKickTime > 0) {
      final t = (1 - _groundKickTime / _groundKickDuration).clamp(0.0, 1.0);
      final envelope = (1 - t) * (1 - t);
      offset.y += sin(t * pi * 2.2) * envelope * _groundKickStrength;
    }
    final base = camera.viewfinder.position;
    final desired = base - offset;
    final clamped = map.bounds.cameraPosition(
      desired,
      camera.viewport.virtualSize / camera.viewfinder.zoom,
    );
    return base - clamped;
  }

  int _weaponImpacts = 0;
  bool claimWeaponImpact() => _weaponImpacts++ < 8;
  late final MapComponent map;
  late GameNotifier gameNotifier;
  ProviderSubscription<GameplayState>? _phaseSubscription;

  final _enemies = <PositionComponent>{};
  final _coins = <CoinComponent>{};
  EncounterDirector director = EncounterDirector();
  ShadowBossComponent? get shadowBoss => activeBoss is ShadowBossComponent
      ? activeBoss as ShadowBossComponent
      : null;
  final bossWinCounts = <String, int>{};
  final defeatedBosses = <String>{},
      noHitBosses = <String>{},
      encounteredEnemies = <String>{};
  bool _bossWasHit = false;
  int scorpionKills = 0, eliteKills = 0;
  double _ventClock = 0;
  late ArenaGeometry geometry;
  bool _reloadWasActive = false;
  Offset? _escapeDashStart;
  double _escapeSlowRemaining = 0, _escapeCooldown = 0;
  final _escapeSegments = <(Offset, Offset, double)>[];

  void armDashEscape() {
    if (loadout.training &&
        !preferences.reducedMotion &&
        _escapeCooldown <= 0) {
      _escapeDashStart = myPlayer.position.toOffset();
    }
  }

  void observeDashEscape(Vector2 before, Vector2 after, double contact) {
    final start = _escapeDashStart;
    if (start == null || _escapeSegments.length >= 12) return;
    final dashOrigin = Vector2(start.dx, start.dy);
    if (BulletComponent.segmentDistanceSquared(dashOrigin, before, after) <=
            contact * contact &&
        !segmentBlocked(before, dashOrigin)) {
      _escapeSegments.add((before.toOffset(), after.toOffset(), contact));
    }
  }

  void _resolveDashEscape(Offset before, int healthBefore) {
    final start = _escapeDashStart;
    if (start == null ||
        playerEntrance.active ||
        gameState.health != healthBefore ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final after = myPlayer.position.toOffset();
    for (final (shotBefore, shotAfter, contact) in _escapeSegments) {
      if (!isDashNearMiss(
        dashStart: start,
        playerBefore: before,
        playerAfter: after,
        shotBefore: shotBefore,
        shotAfter: shotAfter,
        contact: contact,
      )) {
        continue;
      }
      _escapeDashStart = null;
      _escapeSlowRemaining = .20;
      _escapeCooldown = 3;
      myPlayer.markDashEscape();
      break;
    }
  }

  bool _breachCharged = false;
  bool breachEngine = false;
  final revision = ValueNotifier<int>(0);
  bool _enemy2Unlocked = false;
  bool _enemy3Unlocked = false;
  bool _started = false;
  bool disposed = false;
  final supplyDrops = SupplyDrops();
  bool _landingSupply = false;
  bool _supplyArtWanted = false,
      _supplyArtHeld = false,
      _supplyArtLoading = false;
  void _syncSupplyArt(bool wanted) {
    _supplyArtWanted = wanted && !disposed;
    const atlases = ['arenas/supply_pod', 'effects/landing_dust'];
    if (!_supplyArtWanted) {
      if (_supplyArtHeld && !_supplyArtLoading) {
        for (final atlas in atlases) {
          RegunArt.shared.release(atlas);
        }
        _supplyArtHeld = false;
      }
      return;
    }
    if (_supplyArtHeld || _supplyArtLoading) return;
    _supplyArtHeld = _supplyArtLoading = true;
    Future.wait(atlases.map(RegunArt.shared.acquire)).then(
      (_) {
        _supplyArtLoading = false;
        if (!_supplyArtWanted || disposed) _syncSupplyArt(false);
      },
      onError: (Object error) {
        _supplyArtLoading = false;
        supplyDrops.drop = null;
        supplyDrops.nextIn = 3;
        _syncSupplyArt(false);
        debugPrint('Supply art unavailable: $error');
      },
    );
  }

  static const maxEnemies = 120;
  static const maxCoins = 80;
  double bulletFireRate = 0.35;

  GameState get gameState => ref.read(gameNotifierProvider);
  SoloudPlay get audio => ref.read(soloudPlayProvider);

  @override
  Color backgroundColor() => const Color.fromRGBO(8, 5, 8, 1);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await preferences.load();
    await RegunArt.shared.load();
    await RegunArt.shared.acquireSurvivor(loadout.character.name);
    if (disposed) {
      RegunArt.shared.releaseSurvivor(loadout.character.name);
      return;
    }
    _survivorArtHeld = true;
    if (loadout.weapon.hasLeasedArt) {
      await RegunArt.shared.acquire(loadout.weapon.atlasName);
      if (disposed) {
        RegunArt.shared.release(loadout.weapon.atlasName);
        return;
      }
      _weaponArtHeld = true;
    }
    if (loadout.weapon == WeaponType.cinderHose) {
      await RegunArt.shared.acquire('effects/cinder_flame');
      if (disposed) {
        RegunArt.shared.release('effects/cinder_flame');
        return;
      }
      _cinderArtHeld = true;
    }
    if (loadout.weapon == WeaponType.ringCaster) {
      await RegunArt.shared.acquire('effects/cutter_ring');
      if (disposed) {
        RegunArt.shared.release('effects/cutter_ring');
        return;
      }
      _ringArtHeld = true;
    }
    controls = preferences.controls;

    map = await MapComponent.loadMap();
    world = _CombatWorld(this);
    _legacyArena =
        resumeSnapshot != null && resumeSnapshot!['arenaRevision'] != 1;
    _configureArenaGeometry();
    world.add(map);
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    boostButtonComponent = BoostButtonComponent();
    reloadButtonComponent = ReloadButtonComponent();
    grenadeButtonComponent = GrenadeButtonComponent();
    _controlsLoaded = true;
    camera.viewport.addAll([
      movementJoystick,
      weaponJoystick,
      boostButtonComponent,
      reloadButtonComponent,
      grenadeButtonComponent,
      damageFeedback,
      bossVictory,
      EntranceVeil(),
      SupportStatusHud(),
      FreezeFocusView(),
      UpgradeConfirmationView(),
      if (loadout.arena == ArenaType.breach) SupplyDropLocator(),
    ]);
  }

  @override
  void onMount() {
    super.onMount();
    gameNotifier = ref.read(gameNotifierProvider.notifier);
    audio.configure(music: preferences.musicVolume, sfx: preferences.sfxVolume);
    unawaited(audio.warmCombat(loadout.weapon));
    if (loadout.arena == ArenaType.breach) unawaited(audio.warmSupply());
    unawaited(audio.playMusic(loadout.arena.name));
    _phaseSubscription = ref.listenManual(
      gameNotifierProvider.select((state) => state.gameplayState),
      (previous, phase) {
        if (phase == GameplayState.gameOver) {
          supportCombat.clear();
          _settlement = handleSoloDeath();
        }
        if (_started && phase != GameplayState.gameOver) {
          scheduleMicrotask(() {
            if (isMounted && !disposed && !_settled) {
              unawaited(saveCheckpoint());
            }
          });
        }
        audio.pauseMusic(
          phase == GameplayState.paused || phase == GameplayState.gameOver,
        );
        if (phase == GameplayState.powerup) {
          audio.play(
            gameState.evolutionChoices.isNotEmpty ? 'fusion.wav' : 'level.wav',
          );
        }
        timeScale = phase == GameplayState.powerup ? 0.1 : 1;
        if (phase == GameplayState.playing || phase == GameplayState.powerup) {
          if (phase == GameplayState.powerup) {
            resetInput();
            if (upgradeFeelMode != UpgradeFeelMode.baseline &&
                loadout.character == CharacterType.rook) {
              upgradeArt.prewarm([
                ...gameState.powerUpChoices.map((p) => p.name),
                if (gameNotifier.support.offer != null)
                  gameNotifier.support.offer!.id,
              ]);
            }
          }
          resumeEngine();
        } else {
          resetInput();
          pauseEngine();
        }
      },
    );
    gameNotifier.acceptedUpgrade.addListener(_acceptedUpgrade);
    _startRun(clearSave: resumeSnapshot == null);
    if (resumeSnapshot != null) restoreRun(resumeSnapshot!);
    if (startPaused) gameNotifier.pauseGame();
  }

  bool get legacyArena => _legacyArena;

  bool _legacyArena = false;

  List<ArenaMachine> arenaMachines = const [];

  List<ArenaMachine> _createArenaMachines() {
    if (_legacyArena) return const [];
    switch (loadout.arena) {
      case ArenaType.breach:
        return const [];
      case ArenaType.foundry:
        return [
          for (final body in map.regions('foundry_obstacles'))
            ArenaMachine(
              ArenaMachineKind.press,
              body,
              Rect.fromLTWH(body.center.dx - 77, body.bottom, 154, 88),
            ),
        ];
      case ArenaType.floodworks:
        final body = map.regions('floodworks_gate').firstOrNull;
        final channel = map.regions('floodworks_landmarks').firstOrNull;
        if (body == null || channel == null) return const [];
        return [
          ArenaMachine(
            ArenaMachineKind.sluice,
            body,
            Rect.fromLTRB(
              channel.left,
              body.bottom,
              channel.right,
              channel.bottom,
            ),
          ),
        ];
      case ArenaType.relayGraveyard:
        return [
          for (final body in map.regions('relayGraveyard_obstacles'))
            ArenaMachine(
              ArenaMachineKind.relay,
              body,
              Rect.fromLTWH(body.center.dx - 43, body.bottom, 86, 430),
            ),
        ];
    }
  }

  List<FoundryRail> foundryRails = const [];
  bool get foundryRailActive {
    final lodestar = lodestarCandidate;
    return !bossRush &&
        !(lodestar != null &&
            lodestar.readyForFight &&
            !lodestar.fight.finished);
  }

  SoloudPlay? _arenaAudio;

  void _configureArenaGeometry() {
    foundryRails = loadout.arena == ArenaType.foundry && !_legacyArena
        ? [
            for (final (index, track) in map.foundryTracks.indexed)
              FoundryRail(track, offset: index * FoundryRail.stagger),
          ]
        : const [];
    geometry = ArenaGeometry(
      map.bounds,
      obstacles: map.obstacles(loadout.arena, legacy: _legacyArena),
      dynamicObstacles: () sync* {
        final drop = supplyDrops.drop;
        if (!_landingSupply && drop != null && drop.solid) yield drop.footprint;
        yield* supportCombat.solids;
        if (foundryRailActive) {
          for (final rail in foundryRails) {
            yield rail.bodyAt(director.elapsed);
          }
        }
      },
    );
  }

  void _startRun({bool clearSave = true}) {
    _arenaAudio?.syncFoundryRail(null);
    _arenaAudio?.stopMachines();
    _fireKickTime = 0;
    _groundKickTime = 0;
    upgradePresentation.cancel();
    bossReveal.reset();
    mechanicalArrival.reset();
    confirmationHolding.value = false;
    upgradeArt.clear();
    statusArt.clear();
    runId = const Uuid().v4();
    _settled = false;
    _recordOwner = preferences.profileOwner;
    _recordEpoch = AccountController.shared.progressEpoch;
    recovery = SoloRecovery(
      owner: preferences.profileOwner,
      startingScrap: preferences.profile.scrap,
    );
    _settlementSaved = false;
    assisted = preferences.aimAssist;
    trainingStep = 0;
    shotsFired = 0;
    dashCount = 0;
    manualReloads = 0;
    _trainingOrigin.setZero();
    _settlement = null;
    _checkpointElapsed = 0;
    newUnlocks = {};
    damageFeedback.reset();
    bossVictory.reset();
    bossReveal.reset();
    mechanicalArrival.reset();
    camera.viewfinder.zoom = 1;
    saveIssue = null;
    if (clearSave && !loadout.training) unawaited(runStore.clear());
    timeScale = 1;
    director = EncounterDirector(
      bossWins: loadout.training ? null : preferences.profile.bossWins,
    );
    _trainingPressureClock.reset();
    for (final warning in _spawnWarnings.toList()) {
      warning.cancel();
    }
    _spawnWarnings.clear();
    activeBoss = null;
    walkerCandidate = null;
    arietCandidate = null;
    lodestarCandidate = null;
    _bossDamageTaken.clear();
    _bossAttacks.clear();
    weakPoints.clear();
    bossRush = false;
    bossRushRound = 0;
    bossRushWait = 0;
    _rushBag.clear();
    _reloadWasActive = false;
    _escapeCooldown = 0;
    _breachCharged = false;
    breachEngine = false;
    _enemy2Unlocked = false;
    _enemy3Unlocked = false;
    _enemies.clear();
    enemyTactics.clear();
    minionNavigation.clear();
    _navigationPositions.clear();
    _navigationOwners.clear();
    _navigationPlayerPosition = null;
    _navigationPlayerVelocity = Offset.zero;
    _navigationLastDt = 0;
    _steppedMinions.clear();
    _temporaryCoverRouter.clear();
    crowdOccupancy.clear();
    _coins.clear();
    _projectiles.clear();
    _hostileProjectiles.clear();
    _effects.clear();
    _fires.clear();
    _mines.clear();
    grenades.setCapacity(2);
    grenades.reset();
    _upgradePulsePending = false;
    _hazards.clear();
    _bursts.clear();
    resetInput();
    gameNotifier.resetRun(loadout: loadout, seed: random.state);
    supportCombat.clear();
    combat = CombatSystem(this);
    arsenal?.dispose();
    arsenal = ArsenalSystem(this);
    _nextCombatId = 1;
    _fireCooldown = 0;
    burstFire.reset();
    _ventClock = 0;
    arenaMachines = _createArenaMachines();
    supplyDrops.reset(random.state ^ 0x51a7);
    _syncSupplyArt(false);
    defeatedBosses.clear();
    bossWinCounts.clear();
    noHitBosses.clear();
    encounteredEnemies.clear();
    scorpionKills = 0;
    eliteKills = 0;
    boostButtonComponent.reset();
    final landing = loadout.arena == ArenaType.floodworks
        ? Vector2(-375, -290)
        : Vector2.zero();
    _trainingOrigin.setFrom(landing);
    world.add(myPlayer = PlayerComponent(position: landing.clone()));
    world.addAll([
      BossPortalFloor(),
      ArsenalOverlay(floor: true),
      ArsenalOverlay(),
      GrenadeAimPreview(),
      DroneVisual(),
      SupportFieldView(),
      SupportBodyView(),
      SupportRoundsView(),
      ArenaScenery(),
      for (final rail in foundryRails) FoundryCartView(rail),
      if (loadout.arena == ArenaType.breach) ...[
        SupplyDropField(),
        SupplyDropBody(),
      ],
    ]);
    _started = true;
    _updateCamera();
    playerEntrance.begin(
      respawn: false,
      reducedMotion: preferences.reducedMotion,
      camera: camera.viewfinder.position,
      target: landing,
    );
    layoutControls();
    if (walkerTrial && loadout.training) _placeWalker();
    if (arietTrial && loadout.training) _placeAriet();
    if (lodestarTrial && loadout.training) _placeLodestar();
    revision.value++;
    resumeEngine();
  }

  Map<String, dynamic> checkpoint() {
    syncGrenadeCapacity();
    Map<String, dynamic> actor(PositionComponent entity) {
      final enemy = entity as CombatEnemy;
      return {
        'kind': enemyId(entity),
        if (entity is WalkerBoss) 'walker': entity.checkpointState,
        if (entity is ArietBoss) 'ariet': entity.checkpointState,
        if (entity is LodestarBoss) 'lodestar': entity.checkpointState,
        'combatId': enemy.combatId,
        'freeze': enemy.freezeState.toJson(),
        if (minionNavigation.memories[enemy.combatId] case final memory?)
          'navigation': memory.toJson(),
        if (entity is BossEncounter) 'actor': bossEncounter.idOf(entity),
        if (entity is BossEncounter)
          'bossHit': _bossDamageTaken[entity] ?? _bossWasHit,
        'x': entity.position.x,
        'y': entity.position.y,
        'health': entity.isLoaded
            ? enemy.combatHealth.current
            : (entity as BossEncounter).maximumHealth,
        'maximum': entity.isLoaded
            ? enemy.combatHealth.maximum
            : (entity as BossEncounter).maximumHealth,
        'elite': entity is ArenaEnemy && entity.elite,
        'burn': enemy.burnRemaining,
        'burnDamage': enemy.burnDamage,
        'cinder': enemy.cinderRemaining,
        'cinderTick': enemy.cinderTick,
        'spread': enemy.burnCanSpread,
        'marked': enemy.marked,
      };
    }

    return {
      'schema': 2,
      'recovery': recovery.toJson(),
      'recordOwner': _recordOwner,
      'recordEpoch': _recordEpoch,
      'weaponAccessVersion': 2,
      'arenaRevision': _legacyArena ? 0 : 1,
      'id': runId,
      'loadout': loadout.toJson(),
      ...gameNotifier.checkpoint(),
      'random': random.state,
      'assisted': assisted,
      'dash': boostButtonComponent.checkpoint(),
      'droneClock': combat.droneClock,
      'ventClock': _ventClock,
      if (arenaMachines.isNotEmpty)
        'arenaMachines': [
          for (final machine in arenaMachines) machine.toJson(),
        ],
      'arenaHazards': [
        for (final hazard in _hazards)
          if (!hazard.isRemoving &&
              (hazard.cause == 'Foundry vent' ||
                  hazard.cause == 'Sluice surge'))
            [hazard.position.x, hazard.position.y, hazard.age],
      ],
      'supplyDrops': supplyDrops.toJson(),
      'supportRuntime': supportCombat.runtime.toJson(),
      'upgradePulsePending': _upgradePulsePending,
      if (upgradePresentation.holding)
        'upgradeConfirmation': upgradePresentation.receipt!.toJson(),
      'dashCount': dashCount,
      'grenadeInventory': grenades.toJson(),
      'grenadeProjectiles': [
        for (final g in world.children.whereType<GrenadeComponent>())
          if (!g.flight.spent && !g.isRemoving) g.checkpoint(),
      ],
      'player': [myPlayer.position.x, myPlayer.position.y],
      'lastMovement': [myPlayer.lastMovement.x, myPlayer.lastMovement.y],
      'aim': [myPlayer.aimDirection.x, myPlayer.aimDirection.y],
      'director': director.toJson(),
      'fireCooldown': _fireCooldown,
      if (loadout.weapon == WeaponType.burstRifle)
        'burstRecovery': burstFire.recovery,
      if (loadout.weapon.usesArsenalRuntime) 'arsenal': arsenal!.checkpoint(),
      'breachCharged': _breachCharged,
      'bossWasHit': _bossWasHit,
      'enemies': [
        for (final e in liveEnemies)
          if (e is! ArietEscort) actor(e),
        for (final e in bosses)
          if (!e.isLoaded ||
              (e is WalkerBoss && e.prepared && e.fight.defeated) ||
              (e is ArietBoss && e.prepared && e.fight.defeated) ||
              (e is LodestarBoss && e.prepared && e.fight.defeated))
            actor(e),
      ],
      'drops': [
        for (final c in _coins)
          if (!c.isCollected && !c.isRemoving && !c.isRemoved)
            {'x': c.position.x, 'y': c.position.y, 'value': c.value},
      ],
      'mines': [
        for (final mine in world.children.whereType<MineComponent>())
          if (!mine.exploded && !mine.isRemoving)
            {'x': mine.position.x, 'y': mine.position.y, 'age': mine.age},
      ],
      'fire': [
        for (final fire in world.children.whereType<BurningGround>())
          if (!fire.isRemoving)
            {
              'x': fire.position.x,
              'y': fire.position.y,
              'age': fire.age,
              'damage': fire.damage,
            },
      ],
      'defeatedBosses': defeatedBosses.toList(),
      'bossWinCounts': Map<String, int>.of(bossWinCounts),
      'noHitBosses': noHitBosses.toList(),
      'encountered': encounteredEnemies.toList(),
      'scorpions': scorpionKills,
      'elites': eliteKills,
    };
  }

  Future<bool> saveCheckpoint() async {
    if (disposed ||
        !_started ||
        _settled ||
        loadout.training ||
        (gameState.health <= 0 && !recovery.pending)) {
      return false;
    }
    final saved = recovery.pending
        ? await runStore.writeRecovery(checkpoint())
        : await runStore.write(checkpoint());
    if (isMounted) {
      final issue = saved ? null : 'Run could not be saved.';
      if (saveIssue != issue) {
        saveIssue = issue;
        revision.value++;
      }
    }
    return saved;
  }

  ScrapReward get scrapReward => ScrapReward.run(
    salvage: gameState.scrap,
    kills: gameState.kills,
    bosses: gameState.bosses,
    seconds: gameState.survivalSeconds,
    training: loadout.training,
  );
  int get earnedScrap => scrapReward.total;

  Future<void> settleRun() async {
    if (_settled || loadout.training) return;
    if (recovery.stage != 'alive' || recovery.continued) {
      recovery.stage = 'ended';
      if (!await persistRecovery()) return;
    }
    _settled = true;
    final settledId = runId;
    final state = gameState;
    final earned = scrapReward.total;
    // Save the journal in the SAME owner-scoped profile commit as rewards.
    // A crash/lost response cannot leave a public summary without settled totals.
    final journal = preferences.profile.runRecords;
    if (journal.length >= 100) {
      final acknowledged = journal.entries
          .where(
            (e) => [
              'accepted',
              'pending_review',
              'excluded',
              'withdrawn',
              'personal_only',
            ].contains(e.value['status']),
          )
          .map((e) => e.key)
          .toList();
      for (final id in acknowledged.take(journal.length - 99)) {
        journal.remove(id);
      }
    }
    // Career usage must keep accumulating even when receipt storage is full.
    final balance = gameNotifier.weaponPower.snapshot;
    final Map<String, dynamic>? summary = balance == null
        ? null
        : {
            'schema': 1,
            'runId': runId,
            'epoch': _recordEpoch,
            'source': 'solo_reported',
            'mechanics': 'solo-records-1',
            'rules': 'solo1-${balance.hash.substring(0, 16)}',
            'catalog': balance.documentCatalogId,
            'balance': balance.hash,
            'arena': loadout.arena.name,
            'survivor': loadout.character.name,
            'weapon': loadout.weapon.name,
            'score': state.score,
            'seconds': state.survivalSeconds,
            'kills': state.kills,
            'bosses': state.bosses,
            'assisted': assisted,
            'revived': recovery.continued,
            'complete': gameNotifier.runStatistics.complete,
            'picks': Map<String, int>.of(gameNotifier.runStatistics.picks),
            'ranks': {
              for (final e in state.ranks.entries)
                if (e.value > 0) e.key.name: e.value,
            },
            'fusions': state.evolutions.toList(),
            'support': Map<String, int>.of(gameNotifier.runStatistics.support),
          };
    if (journal.length < 100 || journal.containsKey(runId)) {
      preferences.profile.recordQueueFull = false;
      if (summary != null) {
        journal.putIfAbsent(
          runId,
          () => {
            'owner': _recordOwner,
            'status':
                _recordOwner == 'guest' ||
                    recovery.continued ||
                    !gameNotifier.runStatistics.complete
                ? 'personal_only'
                : 'local',
            'summary': summary,
          },
        );
      }
    } else {
      preferences.profile.recordQueueFull = true;
    }
    newUnlocks = preferences.profile.settle(
      runId: runId,
      loadout: loadout,
      kills: state.kills,
      score: state.score,
      seconds: state.survivalSeconds,
      earnedScrap: earned,
      scorpions: scorpionKills,
      elites: eliteKills,
      bosses: defeatedBosses,
      bossVictories: gameState.bosses,
      bossWinCounts: bossWinCounts,
      noHitBosses: noHitBosses,
      foundFusions: state.evolutions,
      enemies: encounteredEnemies,
      assisted: assisted,
      continued: recovery.continued,
      survivorProgress: gameNotifier.survivor.toJson(),
      dashes: dashCount,
      trackedRun: summary,
    );
    if (!assisted && !recovery.continued) {
      await preferences.record(
        score: state.score,
        seconds: state.survivalSeconds,
      );
    }
    final saved = await preferences.saveProfile();
    if (!saved) {
      saveIssue = 'Progress could not be saved. Retry save before leaving.';
    }
    _settlementSaved = saved;
    if (saved) await runStore.clear(expectedRunId: settledId);
    if (isMounted && runId == settledId) revision.value++;
  }

  Future<void> leaveRun() async {
    resetInput();
    if (recovery.pending) {
      await persistRecovery();
      return;
    }
    if (gameState.gameplayState == GameplayState.gameOver) {
      await _settlement;
      if (!_settled) await settleRun();
      if (!_settled) return;
      if (preferences.profileSaveFailed) {
        final saved = await preferences.saveProfile();
        if (!saved) return;
      }
      saveIssue = null;
      _settlementSaved = true;
      await runStore.clear(expectedRunId: runId);
    } else {
      pauseGame();
      await saveCheckpoint();
    }
  }

  bool restoreRun(Map<String, dynamic> snapshot) {
    upgradePresentation.cancel();
    bossReveal.reset();
    mechanicalArrival.reset();
    confirmationHolding.value = false;
    upgradeArt.clear();
    playerEntrance.cancel();
    try {
      if (!RunCheckpoint.valid(snapshot)) {
        throw const FormatException('Unsupported checkpoint');
      }
      final stateSnapshot = GameState.fromJson(
        Map<String, dynamic>.from(snapshot['state'] as Map),
      );
      final savedLoadout = Loadout.fromJson(
        Map<String, dynamic>.from(snapshot['loadout'] as Map),
      );
      if (savedLoadout.weapon != loadout.weapon ||
          savedLoadout.character != loadout.character ||
          savedLoadout.arena != loadout.arena ||
          preferences.profile.settledRuns.contains(snapshot['id'])) {
        throw const FormatException('Checkpoint no longer available');
      }
      recovery = snapshot['recovery'] is Map
          ? SoloRecovery.fromJson(snapshot['recovery'] as Map)
          : SoloRecovery(owner: 'guest', startingScrap: 0);
      if (recovery.owner != preferences.profileOwner &&
          recovery.owner != 'guest') {
        throw const FormatException('Recovery belongs to another account');
      }
      if (stateSnapshot.health <= 0 &&
          !['offered', 'requested', 'ended'].contains(recovery.stage)) {
        throw const FormatException('Finished run');
      }
      // Retire the fresh run's pending actors before restoring IDs. Their late
      // mounts must not register beside checkpoint actors with the same IDs.
      _retireMechanical();
      _retirePracticeBosses();
      for (final old in _enemies.toList()) {
        _retirePracticeActor(old);
      }
      for (final warning in _spawnWarnings.toList()) {
        warning.cancel();
      }
      _spawnWarnings.clear();
      _enemies.clear();
      minionNavigation.clear();
      _navigationPositions.clear();
      _navigationOwners.clear();
      _navigationPlayerPosition = null;
      _navigationLastDt = 0;
      _temporaryCoverRouter.clear();
      final records = (snapshot['enemies'] as List).cast<Map>();
      if (records.length > maxEnemies + 1 ||
          (snapshot['drops'] as List).length > maxCoins) {
        throw const FormatException('Checkpoint exceeds limits');
      }
      Vector2 point(num x, num y) {
        if (!x.isFinite || !y.isFinite) {
          throw const FormatException('Invalid position');
        }
        final result = Vector2(x.toDouble(), y.toDouble());
        constrainActor(result, 50);
        return result;
      }

      runId = snapshot['id'] as String;
      _recordOwner = snapshot['recordOwner'] as String? ?? 'guest';
      _recordEpoch = snapshot['recordEpoch'] as String? ?? '0';
      random.state = snapshot['random'] as int;
      director.restore(Map<String, dynamic>.from(snapshot['director'] as Map));
      myPlayer.position.setFrom(
        point(
          (snapshot['player'] as List)[0] as num,
          (snapshot['player'] as List)[1] as num,
        ),
      );
      final movement = snapshot['lastMovement'] as List? ?? [1, 0];
      final aim = snapshot['aim'] as List? ?? [1, 0];
      myPlayer.lastMovement.setValues(
        (movement[0] as num).toDouble(),
        (movement[1] as num).toDouble(),
      );
      myPlayer.aimDirection.setValues(
        (aim[0] as num).toDouble(),
        (aim[1] as num).toDouble(),
      );
      for (final record in records) {
        final kind = record['kind'] as String;
        final position = point(record['x'] as num, record['y'] as num);
        final maximum = (record['maximum'] as num).toDouble();
        if (!maximum.isFinite || maximum <= 0 || maximum > 1000000) {
          throw const FormatException('Invalid health');
        }
        final PositionComponent entity;
        if (BossKind.values.any((k) => k.name == kind)) {
          if (bosses.length >= 2) {
            throw const FormatException('Multiple bosses');
          }
          entity = _createBoss(BossKind.read(kind), position, maximum);
          bossEncounter.add(entity, restoredId: record['actor'] as int?);
          _bossDamageTaken[entity] = record.containsKey('bossHit')
              ? record['bossHit'] == true
              : snapshot['bossWasHit'] == true;
        } else {
          entity = switch (EnemyKind.values.byName(kind)) {
            EnemyKind.scorpion => EnemyComponent(position: position),
            EnemyKind.mummy => Enemy2Component(position: position),
            EnemyKind.ranged => Enemy3Component(position: position),
            final kind => ArenaEnemy(
              kind,
              position: position,
              elite: record['elite'] == true,
            ),
          };
          _enemies.add(entity);
        }
        final enemy = entity as CombatEnemy;
        enemy.combatId = record['combatId'] as int? ?? _nextCombatId++;
        _nextCombatId = max(_nextCombatId, enemy.combatId + 1);
        _navigationOwners[enemy.combatId] = entity;
        final navigation = NavigationMemory.read(record['navigation']);
        if (navigation != null) {
          minionNavigation.memories[enemy.combatId] = navigation;
        }
        if (record['freeze'] case final Map raw) {
          enemy.freezeState.restore(
            Map<String, dynamic>.from(raw),
            durationCap: gameNotifier.weaponPower.behavior(
              WeaponType.frostShotgun,
              'freezeDuration',
            ),
            recoveryCap: gameNotifier.weaponPower.behavior(
              WeaponType.frostShotgun,
              'freezeRecovery',
            ),
            immunityCap: gameNotifier.weaponPower.behavior(
              WeaponType.frostShotgun,
              'freezeImmunity',
            ),
          );
        }
        if (entity is LodestarBoss && record['lodestar'] is Map) {
          entity.restoreFight(
            Map<String, dynamic>.from(record['lodestar'] as Map),
          );
        }
        if (entity is ArietBoss && record['ariet'] is Map) {
          entity.restoreFight(
            Map<String, dynamic>.from(record['ariet'] as Map),
          );
        }
        if (entity is WalkerBoss && record['walker'] is Map) {
          entity.restoreFight(
            Map<String, dynamic>.from(record['walker'] as Map),
          );
        }
        if ((record['health'] as num) > 0) {
          enemy.restoreHealth(
            (record['health'] as num).toDouble(),
            maximum: maximum,
          );
        }

        enemy.marked = record['marked'] == true;
        enemy.burnRemaining = (record['burn'] as num?)?.toDouble() ?? 0;
        enemy.burnDamage = (record['burnDamage'] as num?)?.toDouble() ?? 0;
        enemy.burnCanSpread = record['spread'] == true;
        enemy.cinderRemaining = (record['cinder'] as num?)?.toDouble() ?? 0;
        enemy.cinderTick = (record['cinderTick'] as num?)?.toDouble() ?? 0;
        world.add(entity);
      }
      director.bossActive = activeBoss != null;
      for (final raw in snapshot['drops'] as List) {
        final map = raw as Map;
        final value = map['value'] as int;
        if (value <= 0) throw const FormatException('Invalid XP');
        dropXP(point(map['x'] as num, map['y'] as num), value);
      }
      defeatedBosses.addAll(
        (snapshot['defeatedBosses'] as List).cast<String>(),
      );
      bossWinCounts.addAll(
        snapshot.containsKey('bossWinCounts')
            ? BossHistory.read(snapshot['bossWinCounts'])
            : {for (final id in defeatedBosses) id: 1},
      );
      noHitBosses.addAll((snapshot['noHitBosses'] as List).cast<String>());
      encounteredEnemies.addAll(
        (snapshot['encountered'] as List).cast<String>(),
      );
      scorpionKills = snapshot['scorpions'] as int;
      eliteKills = snapshot['elites'] as int;
      dashCount = snapshot['dashCount'] as int? ?? 0;
      _fireCooldown = (snapshot['fireCooldown'] as num).toDouble().clamp(0, 2);
      burstFire.reset(
        recovery: (snapshot['burstRecovery'] as num?)?.toDouble() ?? 0,
        maximumRecovery: gameNotifier.weaponPower.burstRecoveryCap,
      );
      if (snapshot['arsenal'] case final Map raw) {
        arsenal!.restore(Map<String, dynamic>.from(raw));
      }
      assisted = snapshot['assisted'] == true;
      combat.droneClock = (snapshot['droneClock'] as num?)?.toDouble() ?? 0;
      _ventClock = (snapshot['ventClock'] as num?)?.toDouble() ?? 0;
      final savedMachines = snapshot['arenaMachines'];
      if (savedMachines is List &&
          savedMachines.length == arenaMachines.length) {
        for (var i = 0; i < arenaMachines.length; i++) {
          arenaMachines[i].restore(savedMachines[i]);
        }
      }
      _restoreArenaHazard(snapshot['arenaHazards']);
      boostButtonComponent.restoreCheckpoint(
        Map<String, dynamic>.from(snapshot['dash'] as Map? ?? {}),
      );
      _upgradePulsePending = snapshot['upgradePulsePending'] == true;
      upgradePresentation.restoreStatic(
        AcceptedUpgrade.read(snapshot['upgradeConfirmation']),
      );
      if (snapshot['grenadeInventory'] case final Map raw) {
        grenades.restore(Map<String, dynamic>.from(raw));
        if (grenades.capacity != gameState.grenadeCapacity) {
          throw const FormatException('Grenade capacity disagrees with build');
        }
      }
      for (final raw in (snapshot['grenadeProjectiles'] as List? ?? []).take(
        4,
      )) {
        final data = Map<String, dynamic>.from(raw as Map);
        final damage = data['damage'], radius = data['radius'];
        if (damage is! num ||
            !damage.isFinite ||
            damage <= 0 ||
            damage > 30 ||
            radius is! num ||
            !radius.isFinite ||
            radius < 100 ||
            radius > 300) {
          throw const FormatException('Invalid grenade blast');
        }
        world.add(
          GrenadeComponent(
            GrenadeFlight.restore(data),
            damage: damage.toDouble(),
            blastRadius: radius.toDouble(),
          ),
        );
      }
      for (final raw in (snapshot['mines'] as List? ?? []).take(12)) {
        final m = raw as Map;
        final mine = MineComponent(
          position: point(m['x'] as num, m['y'] as num),
        );
        mine.age = (m['age'] as num).toDouble().clamp(0, 8);
        _mines.add(mine);
        world.add(mine);
      }
      for (final raw in (snapshot['fire'] as List? ?? []).take(12)) {
        final f = raw as Map;
        final fire = BurningGround(
          position: point(f['x'] as num, f['y'] as num),
          damage: (f['damage'] as num).toDouble().clamp(0, 10),
        );
        fire.age = (f['age'] as num).toDouble().clamp(0, 2.5);
        addFire(fire);
      }
      _breachCharged = snapshot['breachCharged'] == true;
      _bossWasHit = snapshot['bossWasHit'] == true;
      if (snapshot['supplyDrops'] case final Map supply) {
        supplyDrops.restore(Map<String, dynamic>.from(supply));
        final drop = supplyDrops.drop;
        if (drop != null &&
            (!map.bounds.floor
                    .deflate(SupplyDrop.radius)
                    .contains(drop.position) ||
                geometry.obstacles.any(
                  (r) => r.inflate(SupplyDrop.radius).contains(drop.position),
                ))) {
          throw const FormatException('Invalid supply placement');
        }
      }
      _syncSupplyArt(supplyDrops.drop != null && !bossRush);
      gameNotifier.restoreCheckpoint(
        snapshot,
        allowDead: recovery.stage != 'alive',
      );
      supportCombat.restore(snapshot['supportRuntime']);
      _updateCamera();
      revision.value++;
      // Restored attacks restart at anticipation; old flying shots/hazards are
      // discarded. No offline simulation or invisible active hitbox is restored.
      return true;
    } on Object {
      world = _CombatWorld(this);
      world.add(map);
      _startRun();
      saveIssue = 'Saved run could not be restored.';
      return false;
    }
  }

  bool registerEnemy(PositionComponent enemy) {
    if (isRetiredActor(enemy) ||
        (loadout.training && bossRush) ||
        (lodestarTrial && enemy is! LodestarBoss) ||
        (walkerTrial && enemy is! WalkerBoss) ||
        (arietTrial && enemy is! ArietBoss && enemy is! ArietEscort)) {
      return false;
    }
    if (!_enemies.contains(enemy) && _enemies.length >= maxEnemies) {
      return false;
    }
    if (enemy is CombatEnemy && enemy.combatId == 0) {
      enemy.combatId = _nextCombatId++;
    }
    _enemies.add(enemy);
    if (enemy is CombatEnemy) _navigationOwners[enemy.combatId] = enemy;
    encounteredEnemies.add(enemyId(enemy));
    return true;
  }

  void unregisterEnemy(PositionComponent enemy) {
    if (_started && enemy is CombatEnemy) {
      gameNotifier.survivor.forgetVictim(enemy.combatId);
    }
    _enemies.remove(enemy);
    crowdOccupancy.forget(enemy);
    if (enemy is CombatEnemy &&
        identical(_navigationOwners[enemy.combatId], enemy)) {
      _navigationOwners.remove(enemy.combatId);
      minionNavigation.forget(enemy.combatId);
      _navigationPositions.remove(enemy.combatId);
    }
    if (enemy is BossEncounter) {
      bossEncounter.remove(enemy);
      _bossDamageTaken.remove(enemy);
    }
  }

  void _spawnEnemy(PositionComponent enemy) {
    if (mechanicalTrialActive || (loadout.training && bossRush)) return;
    if (gameState.gameplayState != GameplayState.playing) return;
    _enemies.removeWhere((entity) => entity.isRemoving || entity.isRemoved);
    if (_enemies.length >= maxEnemies) return;
    if (!canReinforce) return;
    final floor = map.bounds.floor.deflate(60);
    final visible = camera.visibleWorldRect.inflate(
      loadout.training ? 140 : 100,
    );
    var spawn = Vector2.zero();
    // All pressure levels approach from the view edges like normal survival.
    for (var attempt = 0; attempt < 12; attempt++) {
      final roll = random.nextInt(4);
      final side = loadout.arena == ArenaType.relayGraveyard && attempt < 4
          ? (director.elapsed ~/ 18 + roll ~/ 2 * 2) % 4
          : roll;
      spawn = switch (side) {
        0 => Vector2(
          visible.left,
          visible.top + random.nextDouble() * visible.height,
        ),
        1 => Vector2(
          visible.right,
          visible.top + random.nextDouble() * visible.height,
        ),
        2 => Vector2(
          visible.left + random.nextDouble() * visible.width,
          visible.top,
        ),
        _ => Vector2(
          visible.left + random.nextDouble() * visible.width,
          visible.bottom,
        ),
      };
      spawn.setValues(
        spawn.x.clamp(floor.left, floor.right),
        spawn.y.clamp(floor.top, floor.bottom),
      );
      if (spawn.distanceToSquared(myPlayer.position) >= 300 * 300) break;
    }
    if (spawn.distanceToSquared(myPlayer.position) < 300 * 300) return;
    constrainActor(spawn, 50);
    enemy.position.setFrom(spawn);
    if (!reserveEnemySpace(
      enemy,
      minPlayerDistance: 300,
      // Clamp/occupancy searches near an arena edge must never move a Training
      // arrival into view. Skip a blocked arrival rather than show it spawning.
      excludedArea: loadout.training
          ? camera.visibleWorldRect.inflate(100)
          : null,
    )) {
      return;
    }
    encounteredEnemies.add(enemyId(enemy));
    _enemies.add(
      enemy,
    ); // Includes pending loads, so spawning cannot exceed the cap.
    if (camera.visibleWorldRect
        .inflate(50)
        .contains(enemy.position.toOffset())) {
      world.add(SpawnWarning(game: this, enemy: enemy));
    } else {
      world.add(enemy);
    }
  }

  void enemyDefeated(
    PositionComponent enemy, {
    required int xp,
    required int score,
    bool boss = false,
    bool mechanicalComplete = false,
  }) {
    if (enemy.parent != world) return;
    if (enemy is ArietEscort) {
      _enemies.remove(enemy);
      crowdOccupancy.forget(enemy);
      return;
    }
    if ((enemy is WalkerBoss || enemy is ArietBoss || enemy is LodestarBoss) &&
        !mechanicalComplete) {
      // Keep the encounter registered until its warned mechanical destruction ends.
      _enemies.remove(enemy);
      crowdOccupancy.forget(enemy);
      return;
    }
    if ((enemy is WalkerBoss || enemy is ArietBoss || enemy is LodestarBoss) &&
        loadout.training) {
      unregisterEnemy(enemy);
      bossEncounter.remove(enemy);
      if (bosses.isEmpty && bossRush) bossRushWait = 2.8;
      return;
    }
    if (enemyId(enemy) == 'scorpion') scorpionKills++;
    if (enemy is ArenaEnemy && enemy.elite) eliteKills++;
    gameNotifier.recordKill(score: score, boss: boss);
    combat.onKill(enemy);
    if (!bossRush) dropXP(enemy.position, loadout.training ? 7 : xp);
    if (boss) {
      final bossKind = (enemy as BossEncounter).kind;
      gameNotifier.awardBossHealth();
      bossVictory.show(bossKind);
      if (enemy is! WalkerBoss &&
          enemy is! ArietBoss &&
          enemy is! LodestarBoss) {
        world.add(
          BossDeparture(
            position: enemy.position + Vector2(0, enemy.size.y * .35),
            kind: bossKind,
          ),
        );
      }
      final kind = bossKind.name;
      defeatedBosses.add(kind);
      bossWinCounts[kind] = (bossWinCounts[kind] ?? 0) + 1;
      if (!(_bossDamageTaken.remove(enemy) ?? _bossWasHit)) {
        noHitBosses.add(kind);
      }
      if (kind == 'queen') gameNotifier.addCycleBonus();
      bossEncounter.remove(enemy);
      if (bosses.isEmpty) {
        director.defeatBoss();
        unawaited(audio.playMusic(loadout.arena.name));
        if (bossRush) bossRushWait = 2.8;
      }
      if (!bossRush) gameNotifier.awardBossCore();
      revision.value++;
    }
  }

  void dropXP(Vector2 position, int value) {
    _coins.removeWhere(
      (coin) => coin.isCollected || coin.isRemoving || coin.isRemoved,
    );
    if (_coins.length >= maxCoins) {
      // Preserve every earned point even when the component budget is full.
      final closest = _coins.reduce(
        (a, b) =>
            a.position.distanceToSquared(position) <
                b.position.distanceToSquared(position)
            ? a
            : b,
      );
      closest.value += value;
      return;
    }
    final coin = CoinComponent(position: position.clone(), value: value);
    _coins.add(coin);
    world.add(coin);
  }

  String enemyId(PositionComponent enemy) => switch (enemy) {
    LodestarBoss() => 'lodestar',
    ArietBoss() => 'ariet',
    ArietEscort() => 'arietEscort',
    WalkerBoss() => 'walker',
    EnemyComponent() => 'scorpion',
    Enemy2Component() => 'mummy',
    Enemy3Component() => 'ranged',
    ArenaEnemy() => enemy.kind.name,
    BossEncounter() => (enemy as BossEncounter).kind.name,
    _ => 'unknown',
  };

  void _retireMechanical() {
    if (mechanicalArrival.active) confirmationHolding.value = false;
    mechanicalArrival.reset();
    final ariet = arietCandidate;
    arietCandidate = null;
    ariet?.retire();
    ariet?.removeFromParent();
    _retireWalker();
    final lodestar = lodestarCandidate;
    lodestarCandidate = null;
    lodestar?.retire();
    lodestar?.removeFromParent();
    mechanicalTrial = null;
  }

  double _bossFootprint(BossKind kind) => kind == BossKind.lodestar
      ? 120
      : kind == BossKind.ariet
      ? 230
      : kind == BossKind.walker || kind == BossKind.saint
      ? 220
      : max(kind.bodyRadius, kind.spriteSize * .28);

  bool _bossSiteLegal(Vector2 at, double radius) =>
      map.bounds.interior.deflate(radius).contains(at.toOffset()) &&
      !geometry.solids.any((r) => r.inflate(radius).contains(at.toOffset())) &&
      at.distanceTo(myPlayer.position) >= BossSpawn.minimumDistance &&
      !bosses.any(
        (b) =>
            b.position.distanceTo(at) < max(450, radius + crowdRadius(b) + 80),
      ) &&
      !liveEnemies
          .where((e) => e is! BossEncounter)
          .any((e) => e.position.distanceTo(at) < radius + crowdRadius(e) + 30);

  Vector2? _bossSite(BossKind kind, {bool companion = false}) {
    final point = BossSpawn.choose(
      player: myPlayer.position.toOffset(),
      bounds: map.bounds.interior,
      footprint: _bossFootprint(kind),
      companion: companion,
      legal: (p, r) => _bossSiteLegal(Vector2(p.dx, p.dy), r),
    );
    return point == null ? null : Vector2(point.dx, point.dy);
  }

  void _beginMechanicalArrival(PositionComponent actor) {
    mechanicalArrival.begin(
      actor,
      camera.viewfinder.position,
      camera.viewfinder.zoom,
      targetZoom: actor is ArietBoss
          ? .74
          : actor is LodestarBoss
          ? 1
          : .80,
      arrivalDuration: actor is ArietBoss
          ? 2.60
          : actor is LodestarBoss
          ? 3.2
          : 3.05,
      reducedMotion: preferences.reducedMotion,
    );
    resetInput();
    confirmationHolding.value = true;
  }

  void _placeAriet() {
    final at = _bossSite(BossKind.ariet);
    if (at == null) {
      mechanicalTrial = null;
      return;
    }
    final actor = ArietBoss(
      position: at,
      practiceTrial: true,
      seed: random.nextInt(0x40000000),
    );
    arietCandidate = actor;
    world.add(actor);
    _beginMechanicalArrival(actor);
  }

  ({Vector2 position, double heading})? _lodestarSite() {
    // Validate the complete incoming spine and forward arrival corridor.
    for (var n = 0; n < 32; n++) {
      final yaw = n * 2.399963229728653;
      final at =
          myPlayer.position.toOffset() + Offset(cos(yaw), sin(yaw)) * 1520;
      final heading = yaw + pi;
      final rig = LodestarRig(head: at, heading: heading);
      bool legal = true;
      for (final p in rig.poses) {
        final to = p.position + Offset(cos(heading), sin(heading)) * 830;
        if (!map.bounds.interior.deflate(120).contains(p.position) ||
            !map.bounds.interior.deflate(120).contains(to) ||
            geometry.solids.any(
              (r) => ArenaGeometry.crosses(
                Vector2(p.position.dx, p.position.dy),
                Vector2(to.dx, to.dy),
                r.inflate(120),
              ),
            ) ||
            (p.position - myPlayer.position.toOffset()).distance < 700 ||
            liveEnemies.any(
              (e) =>
                  !e.isRemoving &&
                  TargetCapsule(
                        p.position,
                        to,
                        120,
                      ).distance(e.position.toOffset()) <
                      crowdRadius(e) + 3,
            )) {
          legal = false;
          break;
        }
      }
      if (!legal) continue;
      return (position: Vector2(at.dx, at.dy), heading: heading);
    }
    return null;
  }

  void _placeLodestar() {
    final site = _lodestarSite();
    if (site == null) {
      mechanicalTrial = null;
      return;
    }
    final actor = LodestarBoss(
      position: site.position,
      heading: site.heading,
      practiceTrial: true,
    );
    lodestarCandidate = actor;
    world.add(actor);
    _beginMechanicalArrival(actor);
  }

  void practiceLodestar() {
    if (!loadout.training) return;
    startBossRush();
    bossRush = false;
    bossRushWait = 0;
    mechanicalTrial = MechanicalTrial.lodestar;
    _placeLodestar();
    revision.value++;
  }

  void practiceLodestarMove(LodestarMove? move) {
    final actor = lodestarCandidate;
    if (!loadout.training ||
        actor == null ||
        !actor.prepared ||
        actor.fight.defeated) {
      return;
    }
    actor.fight.forcedMove = move;
    resumeGame();
    resetInput();
    revision.value++;
  }

  void practiceAriet() {
    if (!loadout.training) return;
    startBossRush();
    bossRush = false;
    bossRushWait = 0;
    mechanicalTrial = MechanicalTrial.ariet;
    _placeAriet();
    revision.value++;
  }

  void _placeWalker() {
    final at = _bossSite(BossKind.walker);
    if (at == null) {
      walkerTrial = false;
      return;
    }
    final robot = WalkerBoss(position: at, practiceTrial: true);
    if (reserveEnemySpace(
          robot,
          minPlayerDistance: BossSpawn.minimumDistance,
        ) &&
        _bossSiteLegal(robot.position, 220)) {
      walkerCandidate = robot;
      world.add(robot);
      _beginMechanicalArrival(robot);
    } else {
      crowdOccupancy.forget(robot);
      walkerTrial = false;
    }
  }

  void _retireWalker() {
    final robot = walkerCandidate;
    walkerCandidate = null;
    walkerTrial = false;
    if (robot != null) {
      unregisterEnemy(robot);
      robot.removeFromParent();
      robot.assets.dispose();
    }
  }

  void practiceWalker() {
    if (!loadout.training) return;
    // Reuse the existing boss-only field cleanup without ever advancing a rush.
    // The current build, magazine, health and visit's Take damage choice stay.
    startBossRush();
    bossRush = false;
    bossRushWait = 0;
    walkerTrial = true;
    _placeWalker();
    revision.value++;
  }

  void practiceBoss(BossKind kind) {
    if (!loadout.training) return;
    _retireMechanical();
    bossRush = false;
    _retirePracticeBosses();
    resumeGame();
    spawnBoss(kind);
  }

  void _retirePracticeBosses() {
    for (final old in bosses.toList()) {
      // Retire practice targets without kill rewards or a core; owned attacks
      // see the dead health object and clean themselves up on their next tick.
      _retirePracticeActor(old);
    }
    for (final departure
        in world.children.whereType<BossDeparture>().toList()) {
      departure.releaseArt();
      departure.removeFromParent();
    }
    bossEncounter.clear();
    bossReveal.reset();
    mechanicalArrival.reset();
    confirmationHolding.value = false;
    _bossDamageTaken.clear();
    director.bossActive = false;
  }

  void spawnShadowBoss() => spawnBoss(BossKind.shadow);

  ArietBoss _createAriet(Vector2 position, double health) {
    final actor = ArietBoss(
      position: position,
      maximumHealth: health,
      seed: random.nextInt(0x40000000),
    );
    arietCandidate = actor;
    return actor;
  }

  LodestarBoss _createLodestar(
    Vector2 position,
    double health, {
    double? heading,
  }) {
    final actor = LodestarBoss(
      position: position,
      heading:
          heading ??
          atan2(
            myPlayer.position.y - position.y,
            myPlayer.position.x - position.x,
          ),
      maximumHealth: health,
    );
    lodestarCandidate = actor;
    return actor;
  }

  PositionComponent _createBoss(
    BossKind kind,
    Vector2 position,
    double health,
  ) => switch (kind) {
    BossKind.lodestar => _createLodestar(position, health),
    BossKind.ariet => _createAriet(position, health),
    BossKind.walker ||
    BossKind.saint => WalkerBoss(position: position, maximumHealth: health),
    BossKind.shadow => ShadowBossComponent(
      position: position,
      maximumHealth: health,
    ),
    BossKind.demon => DemonBossComponent(
      position: position,
      maximumHealth: health,
    ),
    BossKind.queen => PatternBoss(
      BossKind.queen,
      position: position,
      maximumHealth: health,
    ),
    _ => createExpansionBoss(kind, position, health),
  };

  void spawnBoss(BossKind kind, {bool companion = false}) {
    if (kind == BossKind.saint) kind = BossKind.walker;
    if ((kind.mechanical) && bosses.isNotEmpty ||
        bosses.any(
          (boss) =>
              boss is WalkerBoss || boss is ArietBoss || boss is LodestarBoss,
        )) {
      return;
    }
    if ((!companion && bosses.isNotEmpty) ||
        bosses.length >= 2 ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final lodestarSite = kind == BossKind.lodestar ? _lodestarSite() : null;
    final position = kind == BossKind.lodestar
        ? lodestarSite?.position
        : _bossSite(kind, companion: companion);
    if (position == null) return;
    _bossWasHit = false;
    final scaling = bossRush ? 0.0 : 180 * pow(director.cycle - 1, 1.3);
    final actor = kind == BossKind.lodestar
        ? _createLodestar(
            position,
            kind.baseHealth + scaling,
            heading: lodestarSite!.heading,
          )
        : _createBoss(kind, position, kind.baseHealth + scaling);
    if (!reserveEnemySpace(
          actor,
          minPlayerDistance: BossSpawn.minimumDistance,
        ) ||
        !_bossSiteLegal(actor.position, _bossFootprint(kind))) {
      crowdOccupancy.forget(actor);
      if (actor is LodestarBoss) {
        actor.retire();
        lodestarCandidate = null;
      }
      if (actor is ArietBoss) {
        actor.retire();
        arietCandidate = null;
      }
      return;
    }
    if (actor is CombatEnemy && actor.combatId == 0) {
      actor.combatId = _nextCombatId++;
    }
    bossEncounter.add(actor);
    _bossDamageTaken[actor] = false;
    encounteredEnemies.add(kind.name);
    unawaited(audio.warmBoss(kind));
    audio.play('boss.wav');
    unawaited(audio.playMusic('boss'));
    if (!director.bossActive) director.beginBoss();
    world.add(actor);
    if (actor is WalkerBoss || actor is ArietBoss || actor is LodestarBoss) {
      _beginMechanicalArrival(actor);
    } else {
      bossReveal.begin(
        actor,
        camera.viewfinder.position,
        reducedMotion: preferences.reducedMotion,
      );
      resetInput();
      confirmationHolding.value = true;
    }
    final distant =
        liveEnemies
            .where(
              (e) =>
                  e is! BossEncounter &&
                  e.position.distanceToSquared(myPlayer.position) > 600 * 600,
            )
            .toList()
          ..sort(
            (a, b) => b.position
                .distanceToSquared(myPlayer.position)
                .compareTo(a.position.distanceToSquared(myPlayer.position)),
          );
    for (final enemy in distant.take(max(0, _enemies.length - 60))) {
      enemy.removeFromParent();
    }
    revision.value++;
  }

  void startBossRush() {
    if (!loadout.training) return;
    _retireMechanical();
    _retirePracticeBosses();
    for (final warning in _spawnWarnings.toList()) {
      warning.cancel();
    }
    for (final enemy in _enemies.toList()) {
      _retirePracticeActor(enemy);
    }
    for (final component in <Component>[
      ..._hazards,
      ..._bossAttacks,
      ..._hostileProjectiles,
      ..._projectiles,
      ..._coins,
      ..._mines,
      ..._fires,
      ..._effects,
      ..._bursts,
      ...world.children.whereType<GrenadeComponent>(),
    ]) {
      component.removeFromParent();
    }
    _hazards.clear();
    _bossAttacks.clear();
    _hostileProjectiles.clear();
    _projectiles.clear();
    _coins.clear();
    _mines.clear();
    _fires.clear();
    _effects.clear();
    _bursts.clear();
    arsenal?.clearField();
    _upgradePulsePending = false;
    _trainingPressureClock.reset();
    supportCombat.clear();
    bossRush = true;
    supplyDrops.reset(random.state ^ 0x51a7);
    _syncSupplyArt(false);
    bossRushRound = 0;
    bossRushWait = .5;
    _rushBag.clear();
    resumeGame();
    resetInput();
    revision.value++;
  }

  void nextBossRushRound() {
    if (!loadout.training || !bossRush) return;
    _retirePracticeBosses();
    bossRushWait = .5;
    resumeGame();
    revision.value++;
  }

  BossKind _nextRushBoss({BossKind? excluding}) {
    if (_rushBag.isEmpty) _rushBag.addAll(BossKind.rushActive);
    if (_rushBag.length == BossKind.rushActive.length) _rushBag.shuffle(random);
    var index = _rushBag.indexWhere((kind) => kind != excluding);
    if (index < 0) {
      _rushBag.addAll(BossKind.rushActive.where((kind) => kind != excluding));
      _rushBag.shuffle(random);
      index = _rushBag.indexWhere((kind) => kind != excluding);
    }
    return _rushBag.removeAt(index);
  }

  void _advanceRush(double dt) {
    if (!bossRush || bosses.isNotEmpty) return;
    bossRushWait -= dt;
    if (bossRushWait > 0) return;
    bossRushRound++;
    gameNotifier.refillPractice();
    final first = _nextRushBoss();
    spawnBoss(first);
    if (!first.mechanical && random.nextDouble() < .4) {
      final second = _nextRushBoss(excluding: first);
      if (!second.mechanical) {
        spawnBoss(second, companion: true);
      } else {
        _rushBag.insert(0, second);
      }
    }
    if (bosses.isEmpty) {
      _rushBag.insert(0, first);
      bossRushRound--;
      bossRushWait = 1;
    }
    revision.value++;
  }

  bool consumeBreachCharge() {
    final charged = _breachCharged;
    if (charged &&
        gameState.rank(PowerUp.breachLoader) > 0 &&
        loadout.weapon.hasLastRound) {
      myPlayer.mechanicFeedback.release(2);
    }
    _breachCharged = false;
    return charged;
  }

  Future<bool> changeTrainingWeapon(WeaponType next) async {
    if (disposed ||
        !loadout.training ||
        !preferences.profile.weaponUnlocked(next) ||
        gameState.gameplayState != GameplayState.paused) {
      return false;
    }
    upgradePresentation.cancel();
    bossReveal.reset();
    mechanicalArrival.reset();
    confirmationHolding.value = false;
    if (next == loadout.weapon) return true;
    final epoch = ++_trainingWeaponEpoch;
    final names = [
      if (next.hasLeasedArt) next.atlasName,
      if (next == WeaponType.cinderHose) 'effects/cinder_flame',
      if (next == WeaponType.ringCaster) 'effects/cutter_ring',
    ];
    final acquired = <String>[];
    try {
      for (final name in names) {
        await RegunArt.shared.acquire(name);
        acquired.add(name);
      }
    } catch (_) {
      for (final name in acquired) {
        RegunArt.shared.release(name);
      }
      rethrow;
    }
    if (disposed ||
        epoch != _trainingWeaponEpoch ||
        !preferences.profile.weaponUnlocked(next) ||
        gameState.gameplayState != GameplayState.paused) {
      for (final name in names) {
        RegunArt.shared.release(name);
      }
      return false;
    }
    resetInput();
    arsenal?.dispose();
    for (final shot in _projectiles.toList()) {
      shot.removeFromParent();
    }
    _projectiles.clear();
    if (_weaponArtHeld) RegunArt.shared.release(loadout.weapon.atlasName);
    if (_cinderArtHeld) RegunArt.shared.release('effects/cinder_flame');
    if (_ringArtHeld) RegunArt.shared.release('effects/cutter_ring');
    loadout = Loadout(
      weapon: next,
      character: loadout.character,
      arena: loadout.arena,
      training: true,
    );
    _weaponArtHeld = next.hasLeasedArt;
    _cinderArtHeld = next == WeaponType.cinderHose;
    _ringArtHeld = next == WeaponType.ringCaster;
    gameNotifier.changeTrainingWeapon(next);
    arsenal = ArsenalSystem(this);
    burstFire.reset();
    _fireCooldown = 0;
    _breachCharged = false;
    myPlayer.recoil = 0;
    unawaited(audio.warmCombat(next));
    revision.value++;
    return true;
  }

  void requestReload() {
    if (inputBlocked) return;
    if (playerEntrance.active ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    arsenal?.cancelAim();
    final fullRivets =
        loadout.weapon == WeaponType.rivetDriver &&
        (arsenal?.hasRivets ?? false);
    if (!gameState.reloading &&
        (gameState.noOfBullets < gameState.maxBullets || fullRivets)) {
      manualReloads++;
    }
    gameNotifier.reloadBullets(manual: true, allowFull: fullRivets);
  }

  Vector2 assistedWeaponDirection(Vector2 raw, {required double range}) {
    if (raw.isZero()) return Vector2.zero();
    final direction = raw.normalized();
    if (!preferences.aimAssist) return direction;
    assisted = true;
    PositionComponent? target;
    var best = .94;
    for (final enemy in liveEnemies) {
      final delta = enemy.position - myPlayer.position;
      if (delta.isZero() ||
          delta.length > range ||
          segmentBlocked(myPlayer.position, enemy.position)) {
        continue;
      }
      final alignment = delta.normalized().dot(direction);
      if (alignment > best) {
        best = alignment;
        target = enemy;
      }
    }
    return target == null
        ? direction
        : (direction * .8 +
                  (target.position - myPlayer.position).normalized() * .2)
              .normalized();
  }

  bool spawnShotgunBullets({double releaseOffset = 0}) {
    if (loadout.weapon.usesArsenalRuntime) return false;
    if (inputBlocked) return false;
    final state = gameState;
    if (state.gameplayState != GameplayState.playing || state.reloading) {
      return false;
    }
    if (state.noOfBullets <= 0) {
      gameNotifier.reloadBullets();
      return false;
    }
    final baseDirection = assistedWeaponDirection(
      weaponJoystick.relativeDelta,
      range: state.bulletRange.toDouble(),
    );
    if (baseDirection.isZero()) return false;
    if (loadout.weapon == WeaponType.burstRifle) {
      final socket = WeaponArtSpec.of(loadout.weapon)
          .releaseOffset(baseDirection.toOffset());
      if (segmentBlocked(
        myPlayer.position + Vector2(0, 6),
        myPlayer.position + Vector2(socket.dx, socket.dy),
      )) {
        return false;
      }
    }
    final count = loadout.weapon == WeaponType.shotgun
        ? state.bulletNumberRange * 2 +
              1 +
              gameNotifier.weaponPower
                  .behavior(WeaponType.shotgun, 'pellets')
                  .toInt() -
              3
        : 1 + min(3, state.countRank(PowerUp.numberOfBulletsPerShotIncrease));
    if (projectileCount + count > maxProjectiles) return false;
    audio.play('shot_${loadout.weapon.name}_${shotsFired % 3}.wav');
    shotsFired++;
    myPlayer.recoil =
        1 + releaseOffset / WeaponFeel.of(loadout.weapon).recovery;
    myPlayer.markMuzzleFlash(baseDirection);
    showFireKick(baseDirection);
    var damage =
        state.shotDamage *
        gameNotifier.weaponPower.damage(loadout.weapon) *
        gameNotifier.weaponPower.survivorDamage(loadout.character);
    breachEngine = state.fused('breachEngine');
    if (state.noOfBullets == 1) {
      damage *=
          1 +
          GameState.scaledRank(state.lastShellRank) *
              state.strength(PowerUp.lastShell) *
              (breachEngine ? 0.9 : 0.6);
    }
    if (_breachCharged) {
      damage *=
          1 +
          GameState.scaledRank(state.breachRank) *
              state.strength(PowerUp.breachLoader) *
              (breachEngine ? 0.8 : 0.5);
    }
    myPlayer.mechanicFeedback.release(readyPerkFlags & 3);
    _breachCharged = false;

    if (loadout.weapon != WeaponType.burstRifle || burstFire.pending == 0) {
      damage = primaryRelease(damage);
    } else {
      damage *= 1 + gameNotifier.survivor.releaseBonus;
    }
    final releaseId = gameNotifier.survivor.lastRelease;
    final releaseBonus = gameNotifier.survivor.releaseBonus;
    final spread =
        (loadout.weapon == WeaponType.shotgun
            ? gameNotifier.weaponPower.behavior(
                    WeaponType.shotgun,
                    'spreadDegrees',
                  ) *
                  pi /
                  180
            : pi / 32) *
        (1 -
            max(0, state.rank(PowerUp.numberOfBulletsPerShotIncrease) - 3) *
                .04);
    for (var i = 0; i < count; i++) {
      if (projectileCount >= maxProjectiles) break;
      final direction = baseDirection.clone()
        ..rotate((i - (count - 1) / 2) * spread);
      if (loadout.weapon == WeaponType.carbine) {
        // Spread changes trajectory, while every round shares the barrel tip.
        direction.rotate(
          (random.nextDouble() * 2 - 1) *
              gameNotifier.weaponPower.behavior(
                WeaponType.carbine,
                'spreadDegrees',
              ) *
              pi /
              180,
        );
      }
      final socket = WeaponArtSpec.of(loadout.weapon)
          .releaseOffset(baseDirection.toOffset());
      addProjectile(
        BulletComponent(
          position: myPlayer.position + Vector2(socket.dx, socket.dy),
          weapon: loadout.weapon,
          initialDelay: releaseOffset,
          damage:
              damage /
              (loadout.weapon != WeaponType.shotgun && count > 1 ? 1.3 : 1),
          direction: direction,
          speed: state.bulletSpeed,
          maxTravelDistance: state.bulletRange.toDouble(),
          releaseId: releaseId,
          releaseBonus: releaseBonus,
          pierce:
              state.countRank(PowerUp.bulletsPhaseThrough) +
              (state.bulletsPhaseThrough ? 1 : 0),
          bounces:
              gameNotifier.weaponPower.ricochets(loadout.weapon) +
              state.countRank(PowerUp.ricochet) +
              (state.fused('pinball') ? 3 : 0),
          angle: atan2(direction.y, direction.x),
        ),
      );
    }
    gameNotifier.decreaseBullets();
    if (gameState.noOfBullets == 0) gameNotifier.reloadBullets();
    return true;
  }

  @override
  void update(double dt) {
    _steppedMinions.clear();
    if (!_started) return;
    if (!applicationActive) return;
    if (gameState.gameplayState == GameplayState.gameOver) {
      upgradePresentation.cancel();
    }
    if (presentationHeld) {
      if (gameState.gameplayState == GameplayState.paused) return;
      resetInput();
      upgradePresentation.advanceHold(dt);
      confirmationHolding.value = presentationHeld;
      if (!presentationHeld &&
          _upgradePulsePending &&
          gameState.gameplayState == GameplayState.playing) {
        _upgradePulsePending = false;
        upgradePresentation.releaseImpact();
        combat.upgradePulse();
      }
      // Do not call super.update here: even zero-dt updates can release a
      // queued collision/attack. Rendering reads this independent clock.
      return;
    }
    if (gameState.gameplayState == GameplayState.playing) {
      upgradePresentation.advanceActive(dt);
    }
    if (playerEntrance.active) {
      _navigationPlayerPosition = null;
      _navigationLastDt = 0;
      if (gameState.gameplayState == GameplayState.paused) return;
      resetInput();
      final before = playerEntrance.elapsed;
      playerEntrance.advance(dt);
      final impact = playerEntrance.landingStart + playerEntrance.dropDuration;
      if (before < impact && playerEntrance.elapsed >= impact) {
        audio.play('impact_guard.wav');
      }
      final centerCamera = map.bounds.cameraPosition(
        playerEntrance.landingPosition,
        camera.viewport.virtualSize / camera.viewfinder.zoom,
      );
      camera.viewfinder.position =
          playerEntrance.cameraFrom +
          (centerCamera - playerEntrance.cameraFrom) *
              playerEntrance.cameraProgress;
      if (playerEntrance.atCenter) {
        myPlayer.position.setFrom(playerEntrance.landingPosition);
      }
      if (playerEntrance.elapsed >= playerEntrance.fall) damageFeedback.reset();
      // Mount pending components without advancing attacks or contact damage.
      super.update(0);
      if (playerEntrance.elapsed >= playerEntrance.duration) {
        final respawn = playerEntrance.respawning;
        playerEntrance.cancel();
        if (respawn && loadout.training) {
          grenades.setCapacity(gameState.grenadeCapacity);
          grenades.reset();
          for (final shot
              in world.children.whereType<GrenadeComponent>().toList()) {
            shot.removeFromParent();
          }
          gameNotifier.recoverTrainingPlayer();
        }
        resetInput();
        _updateCamera();
      }
      return;
    }
    if (gameState.gameplayState == GameplayState.playing) {
      _groundKickTime = max(0.0, _groundKickTime - dt);
    }
    if (mechanicalArrival.active &&
        gameState.gameplayState == GameplayState.playing) {
      resetInput();
      processLifecycleEvents();
      final actor = mechanicalArrival.actor!;
      final ready =
          actor.isMounted &&
          actor.isLoaded &&
          (actor is ArietBoss
              ? actor.prepared
              : actor is LodestarBoss
              ? actor.prepared
              : actor is WalkerBoss && actor.prepared);
      if (actor.isRemoving ||
          actor.isRemoved ||
          (actor is CombatEnemy && ready && actor.combatHealth.isDead)) {
        mechanicalArrival.reset();
        confirmationHolding.value = false;
        _updateCamera();
        return;
      }
      if (ready) {
        if (actor is ArietBoss) actor.advanceArrival(dt);
        if (actor is WalkerBoss) actor.advanceArrival(dt);
        if (actor is LodestarBoss) actor.advanceArrival(dt);
      }
      final done = mechanicalArrival.advance(dt, ready: ready);
      camera.viewfinder.zoom = mechanicalArrival.zoom;
      final extent = camera.viewport.virtualSize / camera.viewfinder.zoom;
      final player = map.bounds.cameraPosition(myPlayer.position, extent);
      final root = actor is ArietBoss && actor.prepared
          ? Vector2(actor.rig.position.dx, actor.rig.position.dy)
          : actor.position;
      final focus = map.bounds.cameraPosition(root, extent);
      camera.viewfinder.position = mechanicalArrival.camera(player, focus);
      if (done) {
        mechanicalArrival.reset();
        confirmationHolding.value = false;
        _updateCamera();
      }
      layoutControls();
      return;
    }
    if (bossReveal.active && gameState.gameplayState == GameplayState.playing) {
      resetInput();
      // Mount/load actors without invoking a zero-dt simulation or collisions.
      processLifecycleEvents();
      final before = bossReveal.elapsed;
      final done = bossReveal.advance(dt);
      final target = Vector2.zero();
      for (final actor in bossReveal.actors) {
        target.add(actor.position);
      }
      if (bossReveal.actors.isNotEmpty) {
        target.scale(1 / bossReveal.actors.length);
      }
      final player = map.bounds.cameraPosition(
        myPlayer.position,
        camera.viewport.virtualSize / camera.viewfinder.zoom,
      );
      if (before < 1.48 && bossReveal.elapsed >= 1.48) {
        showGroundImpact(target.toOffset(), strength: 9);
      }
      final focus = map.bounds.cameraPosition(
        target,
        camera.viewport.virtualSize / camera.viewfinder.zoom,
      );
      camera.viewfinder.position = bossReveal.camera(player, focus);
      if (bossReveal.elapsed >= 2.05 || bossReveal.reduced) {
        camera.viewfinder.zoom = bossReveal.reduced
            ? .88
            : 1 - .12 * ((bossReveal.elapsed - 2.05) / .6).clamp(0, 1);
      }
      if (done) {
        bossReveal.reset();
        mechanicalArrival.reset();
        confirmationHolding.value = false;
        camera.viewfinder.zoom = .88;
        _updateCamera();
        layoutControls();
      }
      return;
    }
    bossEncounter.advance(_lingeringBossAttack);
    _weaponImpacts = 0;
    final phase = gameState.gameplayState;
    if (phase == GameplayState.paused || phase == GameplayState.gameOver) {
      return;
    }
    if (phase == GameplayState.playing) {
      if (!boostButtonComponent.tapped || preferences.reducedMotion) {
        _escapeDashStart = null;
      }
      if (preferences.reducedMotion) _escapeSlowRemaining = 0;
      // Keep the duration in real time. All combat below receives the same dt.
      final slowed = min(dt, _escapeSlowRemaining);
      _escapeSlowRemaining -= slowed;
      _escapeCooldown = max(0, _escapeCooldown - dt);
      dt -= slowed * .30;
    }
    _fireKickTime = max(0.0, _fireKickTime - dt);
    // Gameplay timers use simulation time; pause and restart cannot leak work.
    _reloadWasActive = gameState.reloading;
    final finishFlourish = _reloadWasActive && !gameNotifier.reloadTactical;
    final reloadWait = gameNotifier.reloadRemainingSeconds;
    gameNotifier.advanceTime(dt * timeScale);
    if (_reloadWasActive && !gameState.reloading) {
      _breachCharged = true;
      if (finishFlourish &&
          phase == GameplayState.playing &&
          !preferences.reducedMotion) {
        myPlayer.gunplay.reload(loadout.weapon);
      }
    }
    if (gameState.gameplayState == GameplayState.playing) {
      final firing = !weaponJoystick.relativeDelta.isZero();
      if (loadout.weapon.usesArsenalRuntime) {
        arsenal!.advance(dt, blockedFor: min(dt, reloadWait));
      } else if (loadout.weapon == WeaponType.burstRifle) {
        final wait = min(dt, reloadWait);
        if (wait > 0) {
          burstFire.advance(
            rounds: gameNotifier.weaponPower
                .behavior(WeaponType.burstRifle, 'burstRounds')
                .toInt(),
            spacingSeconds: gameNotifier.weaponPower.behavior(
              WeaponType.burstRifle,
              'burstSpacing',
            ),
            maximumInterval: gameNotifier.weaponPower.burstRecoveryCap,
            wait,
            held: false,
            interval: .6,
            ready: () => false,
            release: (_) => false,
          );
        }
        burstFire.advance(
          rounds: gameNotifier.weaponPower
              .behavior(WeaponType.burstRifle, 'burstRounds')
              .toInt(),
          spacingSeconds: gameNotifier.weaponPower.behavior(
            WeaponType.burstRifle,
            'burstSpacing',
          ),
          maximumInterval: gameNotifier.weaponPower.burstRecoveryCap,
          max(0, dt - wait),
          held: firing,
          interval:
              gameNotifier.weaponPower.cadence(loadout.weapon) *
              pow(.85, gameState.effectRank(PowerUp.quickTrigger)),
          ready: () =>
              !gameState.reloading &&
              gameState.noOfBullets > 0 &&
              gameState.gameplayState == GameplayState.playing,
          release: (offset) =>
              spawnShotgunBullets(releaseOffset: wait + offset),
        );
        if (firing && gameState.noOfBullets == 0 && !gameState.reloading) {
          gameNotifier.reloadBullets();
        }
      } else {
        _fireCooldown = max(0, _fireCooldown - dt);
        if (_fireCooldown <= 0 && firing && spawnShotgunBullets()) {
          _fireCooldown =
              gameNotifier.weaponPower.cadence(loadout.weapon) *
              pow(0.85, gameState.effectRank(PowerUp.quickTrigger));
        }
      }
      if (_upgradePulsePending) {
        _upgradePulsePending = false;
        upgradePresentation.releaseImpact();
        combat.upgradePulse();
      }
      syncGrenadeCapacity();
      grenades.advance(dt, grenadeRecharge);
      combat.update(dt);
      if (!bossRush) supportCombat.advance(dt);
    }
    _crowdCueActor = null;
    if (gameState.gameplayState == GameplayState.playing) {
      _crowdCueCooldown = max(0, _crowdCueCooldown - dt);
    }
    enemyTactics.rebuild(liveEnemies.where((e) => !isAirborneActor(e)));
    crowdOccupancy.rebuild(
      [..._enemies, ...bosses].where((e) => !isAirborneActor(e)),
      crowdRadius,
    );
    var railSweeps = const <(Rect, Rect)>[];
    if (foundryRails.isNotEmpty &&
        foundryRailActive &&
        gameState.gameplayState == GameplayState.playing) {
      railSweeps = [];
      for (final rail in foundryRails) {
        final before = rail.bodyAt(director.elapsed);
        final after = rail.bodyAt(director.elapsed + dt);
        if (before != after) railSweeps.add((before, after));
      }
    }
    final railPlayerBefore = railSweeps.isEmpty
        ? null
        : myPlayer.position.clone();
    var railTargets = const <CombatEnemy, Vector2>{};
    if (railSweeps.isNotEmpty) {
      railTargets = {};
      final nearby = [
        for (final (before, after) in railSweeps)
          before.expandToInclude(after).inflate(180),
      ];
      for (final enemy in _enemies) {
        if (enemy is CombatEnemy &&
            enemy.isLoaded &&
            !enemy.combatHealth.isDead &&
            !enemy.isBoss &&
            nearby.any((rect) => rect.contains(enemy.position.toOffset()))) {
          railTargets[enemy] = enemy.position.clone();
        }
      }
    }
    final escapePlayerBefore = _escapeDashStart == null
        ? null
        : myPlayer.position.toOffset();
    final escapeHealthBefore = gameState.health;
    _advanceOrdinaryMinions(dt);
    try {
      super.update(dt);
      if (escapePlayerBefore != null) {
        _resolveDashEscape(escapePlayerBefore, escapeHealthBefore);
      }
    } finally {
      _escapeSegments.clear();
      _steppedMinions.clear();
    }
    final state = gameState;
    if (state.gameplayState == GameplayState.playing) {
      final nearby = _crowdCueActor;
      if (nearby != null && !(nearby as CombatEnemy).combatHealth.isDead) {
        playEnemyMovement('enemy_scuttle.wav', nearby.position, 360);
        _crowdCueCooldown = 1.1;
      }
      _checkpointElapsed += dt;
      if (_checkpointElapsed >= 15) {
        _checkpointElapsed = 0;
        unawaited(saveCheckpoint());
      }
      _advanceRush(dt);
      final reinforce = director.advance(dt);
      if (foundryRails.isNotEmpty) {
        final rolling = !foundryRailActive
            ? null
            : foundryRails
                  .where((rail) => rail.moving(director.elapsed))
                  .firstOrNull;
        (_arenaAudio ??= audio).syncFoundryRail(
          rolling == null
              ? null
              : rolling.bodyAt(director.elapsed).center -
                    myPlayer.position.toOffset(),
        );
      }
      for (final (railBefore, railAfter) in railSweeps) {
        var impacted = false;
        for (final entry in railTargets.entries) {
          final enemy = entry.key;
          if (FoundryRail.strikes(
            railBefore,
            railAfter,
            entry.value,
            enemy.position,
            enemyRadius(enemy),
          )) {
            impacted = enemy.crushByArena() || impacted;
          }
        }
        if (FoundryRail.strikes(
          railBefore,
          railAfter,
          railPlayerBefore!,
          myPlayer.position,
          PlayerComponent.collisionRadius,
        )) {
          impacted =
              damagePlayer(amount: 2, cause: 'Foundry rail cart') || impacted;
        }
        if (impacted) {
          showGroundImpact(railAfter.center, strength: 8, attenuate: true);
        }
      }
      if (loadout.training) {
        if (!bossRush && !reviewControlledSpawns && !mechanicalTrialActive) {
          _advanceTrainingCrowd(dt);
        }
      } else if (reinforce && !bossRush) {
        _spawnEnemy(_directorEnemy());
      }
      if (director.bossDue && !loadout.training) {
        spawnBoss(director.chooseBoss(random));
      }
      _advanceArenaMachines(dt);
      _advanceArenaHazard(dt);
    }
    if (loadout.training) {
      final done = switch (trainingStep) {
        0 => myPlayer.position.distanceToSquared(_trainingOrigin) > 100 * 100,
        1 => shotsFired > 0,
        2 => dashCount > 0,
        3 => manualReloads > 0,
        4 =>
          gameState.currentLevel >= 2 &&
              gameState.gameplayState == GameplayState.playing,
        _ => false,
      };
      if (done) {
        trainingStep++;
        revision.value++;
      }
    }
    if (gameState.gameplayState == GameplayState.playing &&
        loadout.arena == ArenaType.breach &&
        !bossRush &&
        !mechanicalTrialActive &&
        !_supplyArtLoading) {
      supplyDrops.advance(
        dt,
        player: myPlayer.position.toOffset(),
        pickPosition: _pickSupplyPosition,
        onLand: landSupplyDrop,
        onReward: () {
          final granted = gameNotifier.offerSupplyUpgrade();
          if (granted) audio.play('supply_claim.wav');
          return granted;
        },
        onCharge: (step) => audio.play('supply_charge_$step.wav'),
        onWarning: () => audio.play('supply_incoming.wav'),
        onBreak: () {
          audio.play('supply_break.wav');
          final position = supplyDrops.drop?.position;
          if (position != null) _impactSupplyDrop(position);
        },
      );
    }
    _syncSupplyArt(supplyDrops.drop != null && !bossRush);
    final targetZoom = encounterCameraZoom;
    camera.viewfinder.zoom = preferences.reducedMotion
        ? targetZoom
        : camera.viewfinder.zoom +
              (targetZoom - camera.viewfinder.zoom) * (dt * 2.5).clamp(0, 1);
    _updateCamera();
    layoutControls();
  }

  void practiceSupport(SupportFamily family) {
    if (!loadout.training || loadout.arena != ArenaType.breach || bossRush) {
      return;
    }
    gameNotifier.offerSupportPractice(family);
  }

  void _advanceArenaMachines(double dt) {
    if (bossRush ||
        arenaMachines.isEmpty ||
        inputBlocked ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final player = myPlayer.position.toOffset();
    for (final machine in arenaMachines) {
      final area = machine.area;
      final trigger = machine.trigger;
      final wasWarning = machine.warning;
      final occupied =
          activeBoss == null &&
          (machine.kind == ArenaMachineKind.sluice
              ? director.elapsed >= 7 && area.inflate(350).contains(player)
              : trigger.contains(player) ||
                    _enemies.any(
                      (actor) =>
                          actor is CombatEnemy &&
                          !actor.isBoss &&
                          actor.isLoaded &&
                          !actor.isRemoving &&
                          !actor.combatHealth.isDead &&
                          !isAirborneActor(actor) &&
                          trigger.contains(actor.position.toOffset()),
                    ));
      final struck = machine.advance(dt, occupied: occupied);
      if (!wasWarning && machine.warning) {
        unawaited(
          (_arenaAudio ??= audio).playMachine(
            'machine_${machine.kind.name}_charge.wav',
            machine.body.center - player,
          ),
        );
      }
      if (struck) {
        unawaited(
          (_arenaAudio ??= audio).playMachine(
            switch (machine.kind) {
              ArenaMachineKind.press => 'machine_press_hit.wav',
              ArenaMachineKind.sluice => 'machine_sluice_flow.wav',
              ArenaMachineKind.relay => 'machine_relay_pulse.wav',
            },
            (machine.kind == ArenaMachineKind.sluice
                    ? Offset(
                        area.center.dx,
                        player.dy.clamp(area.top, area.bottom),
                      )
                    : area.center) -
                player,
          ),
        );
        if (machine.kind == ArenaMachineKind.press) {
          showGroundImpact(area.center, strength: 10, attenuate: true);
        }
        if (machine.kind != ArenaMachineKind.sluice) {
          for (final actor in _enemies.toList()) {
            if (actor is! CombatEnemy ||
                actor.isBoss ||
                !actor.isLoaded ||
                actor.isRemoving ||
                actor.combatHealth.isDead ||
                !area.contains(actor.position.toOffset())) {
              continue;
            }
            if (machine.kind == ArenaMachineKind.press) {
              actor.crushByArena(source: 'Foundry press');
            } else {
              actor.staggerByArena(.27);
            }
          }
          if (area.contains(player)) {
            damagePlayer(
              amount: machine.kind == ArenaMachineKind.press ? 2 : 1,
              cause: machine.kind == ArenaMachineKind.press
                  ? 'Foundry press'
                  : 'Relay discharge',
            );
          }
        }
      }
      if (machine.kind == ArenaMachineKind.sluice && machine.active) {
        final downstream = Vector2(0, 1);
        if (area.contains(player)) {
          moveActor(
            myPlayer,
            downstream,
            155,
            dt,
            radius: PlayerComponent.collisionRadius,
          );
        }
        for (final actor in _enemies.toList()) {
          if (actor is CombatEnemy &&
              !actor.isBoss &&
              actor.isLoaded &&
              !actor.isRemoving &&
              !actor.combatHealth.isDead &&
              !isAirborneActor(actor) &&
              area.contains(actor.position.toOffset())) {
            moveTo(
              actor,
              actor.position + downstream * (155 * dt),
              enemyRadius(actor),
              slide: true,
            );
          }
        }
      }
    }
  }

  void _advanceArenaHazard(double dt) {
    final flood = loadout.arena == ArenaType.floodworks;
    if ((flood && !_legacyArena) ||
        (!flood && loadout.arena != ArenaType.foundry) ||
        bossRush ||
        activeBoss != null ||
        (_legacyArena && director.bossesDefeated == 0)) {
      return;
    }
    final interval = flood ? 11.0 : 6.0;
    _ventClock += dt;
    if (_ventClock < interval) return;
    _ventClock = 0;
    final anchors = _arenaHazardAnchors()
      ..sort(
        (a, b) => a
            .distanceToSquared(myPlayer.position)
            .compareTo(b.distanceToSquared(myPlayer.position)),
      );
    if (anchors.isEmpty ||
        (!_legacyArena &&
            anchors.first.distanceToSquared(myPlayer.position) > 720 * 720)) {
      return;
    }
    _stageArenaHazard(anchors.first);
  }

  List<Vector2> _arenaHazardAnchors() => map.anchors(
    loadout.arena == ArenaType.floodworks
        ? 'floodworks_vents'
        : _legacyArena
        ? 'foundry_legacy_vents'
        : 'foundry_vents',
  );

  void _restoreArenaHazard(Object? raw) {
    if ((loadout.arena == ArenaType.floodworks && !_legacyArena) ||
        (loadout.arena != ArenaType.foundry &&
            loadout.arena != ArenaType.floodworks) ||
        raw is! List ||
        raw.length != 1) {
      return;
    }
    final row = raw.first;
    if (row is! List ||
        row.length != 3 ||
        row.any((v) => v is! num || !v.isFinite)) {
      return;
    }
    final age = (row[2] as num).toDouble();
    if (age < 0 ||
        age >= (loadout.arena == ArenaType.floodworks ? 5.95 : 2.7)) {
      return;
    }
    for (final anchor in _arenaHazardAnchors()) {
      if (anchor.x == row[0] && anchor.y == row[1]) {
        _stageArenaHazard(anchor, initialAge: age);
        return;
      }
    }
  }

  void _stageArenaHazard(Vector2 at, {double initialAge = 0}) {
    final flood = loadout.arena == ArenaType.floodworks;
    addHostileArea(
      at,
      radius: flood ? 330 : 115,
      warning: flood ? 2 : 1.2,
      active: flood ? 3 : 1.5,
      cause: flood ? 'Sluice surge' : 'Foundry vent',
      initialAge: initialAge,
    );
  }

  void practiceSupplyDrop() {
    if (!loadout.training || loadout.arena != ArenaType.breach) return;
    _retirePracticeBosses();
    bossRush = false;
    supplyDrops.reset(random.state ^ 0x51a7);
    supplyDrops.nextIn = 0;
    resumeGame();
    resetInput();
    revision.value++;
  }

  Offset? _pickSupplyPosition() {
    final area = camera.visibleWorldRect
        .intersect(map.bounds.floor)
        .deflate(SupplyDrop.radius + 35);
    if (area.width <= 0 || area.height <= 0) return null;
    bool eligible(Offset spot) =>
        area.contains(spot) &&
        (spot - myPlayer.position.toOffset()).distance >= 260 &&
        (supplyDrops.previous == null ||
            (spot - supplyDrops.previous!).distance >= 350) &&
        ![
          ...geometry.solids,
          ...supportCombat.reservations,
        ].any((r) => r.inflate(SupplyDrop.radius + 20).contains(spot));

    if (!_legacyArena) {
      final sites = map
          .anchors('breach_supply')
          .map((point) => point.toOffset())
          .where(eligible)
          .toList();
      if (sites.isNotEmpty) return sites[random.nextInt(sites.length)];
    }
    for (var i = 0; i < 30; i++) {
      final spot = Offset(
        area.left + random.nextDouble() * area.width,
        area.top + random.nextDouble() * area.height,
      );
      if (eligible(spot)) return spot;
    }
    return null;
  }

  void landSupplyDrop(Offset position) {
    showGroundImpact(position, strength: 11, attenuate: true);
    audio.play('supply_land.wav');
    _impactSupplyDrop(position);
  }

  /// Landing and the one transition into breakdown share the same friendly
  /// crush, grenade blast and pressure wave. Saved breaking phases do not repeat.
  void _impactSupplyDrop(Offset position) {
    _landingSupply = true;
    try {
      final center = Vector2(position.dx, position.dy);
      for (final target in liveEnemies.toList()) {
        final enemy = target as CombatEnemy;
        final radius = SupplyDrop.impactRadius + enemyRadius(target);
        if (target.position.distanceToSquared(center) > radius * radius ||
            segmentBlocked(center, target.position)) {
          continue;
        }
        hitEnemy(
          target,
          FriendlyImpact.crushDamage(
            boss: enemy.isBoss,
            maximum: enemy.combatHealth.maximum,
            current: enemy.combatHealth.current,
          ),
          primary: false,
        );
      }
      combat.explode(
        center,
        radius: FriendlyImpact.blastRadius,
        damage: FriendlyImpact.blastDamage,
        grenade: true,
        allowFragments: false,
      );
    } finally {
      _landingSupply = false;
    }
    // A player caught beneath a friendly pod is displaced, never damaged.
    constrainActor(
      myPlayer.position,
      30,
      bottomExtent: myPlayer.boundaryFootExtent,
    );
    for (final target in liveEnemies.toList()) {
      moveTo(target, target.position.clone(), crowdRadius(target));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_started) {
      resetInput();
      _updateCamera();
      layoutControls();
    }
  }

  /// World framing only: viewport HUD/control geometry remains unchanged.
  double get encounterCameraZoom {
    bool alive(PositionComponent? a) =>
        a != null &&
        !a.isRemoving &&
        (!a.isLoaded || a is! CombatEnemy || !a.combatHealth.isDead);
    if (alive(lodestarCandidate)) return 1;
    if (arietTrial) return alive(arietCandidate) ? .74 : 1;
    if (walkerTrial) return alive(walkerCandidate) ? .80 : 1;
    if (bosses.whereType<ArietBoss>().any(alive)) return .74;
    if (walkerActors.any(alive)) return .80;
    return bosses.any(alive) ? .88 : 1;
  }

  void _updateCamera() {
    if (bossReveal.active || mechanicalArrival.active) return;
    camera.viewfinder.position = map.bounds.cameraPosition(
      myPlayer.position,
      camera.viewport.virtualSize / camera.viewfinder.zoom,
    );
  }

  void setControls(ControlLayout layout) {
    controls = layout;
    resetInput();
    layoutControls();
    unawaited(preferences.saveControls(layout));
    revision.value++;
  }

  double get controlButtonSize =>
      controls.displayButtonSize(controlCanvasRect.size);

  Rect get controlCanvasRect {
    final virtual = camera.viewport.virtualSize;
    final factor = min(canvasSize.x / virtual.x, canvasSize.y / virtual.y);
    final letterbox = (canvasSize - virtual * factor) / 2;
    final safe = MediaQuery.maybeOf(context)?.padding ?? EdgeInsets.zero;
    final left = max(safe.left, letterbox.x),
        right = max(safe.right, letterbox.x);
    final bottom = max(safe.bottom, letterbox.y);
    return Rect.fromLTRB(
      left,
      letterbox.y,
      canvasSize.x - right,
      canvasSize.y - bottom,
    );
  }

  void layoutControls() {
    if (!_controlsLoaded || canvasSize.x <= 0 || canvasSize.y <= 0) return;
    final virtual = camera.viewport.virtualSize;
    final factor = min(canvasSize.x / virtual.x, canvasSize.y / virtual.y);
    final letterbox = (canvasSize - virtual * factor) / 2;
    final safe = MediaQuery.maybeOf(context)?.padding ?? EdgeInsets.zero;
    final left = max(0.0, safe.left - letterbox.x);
    final right = max(0.0, safe.right - letterbox.x);
    final bottom = max(0.0, safe.bottom - letterbox.y);
    final available = Size(
      virtual.x * factor - left - right,
      virtual.y * factor - bottom,
    );
    final geometry = controls.geometry(available);
    final stickSize = controls.displaySize(available),
        buttonSize = controls.displayButtonSize(available);
    Vector2 point(Offset value) =>
        Vector2((value.dx + left) / factor, value.dy / factor);
    if (!controls.floating || !movementJoystick.hasActivePointer) {
      movementJoystick.position.setFrom(point(geometry.movement));
    }
    if (!controls.floating || !weaponJoystick.hasActivePointer) {
      weaponJoystick.position.setFrom(point(geometry.aim));
    }
    movementJoystick.scale.setAll(stickSize / (180 * factor));
    weaponJoystick.scale.setAll(stickSize / (180 * factor));
    boostButtonComponent.position.setFrom(point(geometry.dash));
    reloadButtonComponent.position.setFrom(point(geometry.reload));
    grenadeButtonComponent.position.setFrom(point(geometry.grenade));
    boostButtonComponent.scale.setAll(buttonSize / (112 * factor));
    reloadButtonComponent.scale.setAll(buttonSize / (112 * factor));
    grenadeButtonComponent.scale.setAll(buttonSize / (112 * factor));
  }

  bool damagePlayer({int amount = 1, String cause = 'The horde'}) {
    if (inputBlocked ||
        boostButtonComponent.tapped ||
        (loadout.training && !trainingDamage)) {
      return false;
    }
    final health = gameState.health;
    final guarded = gameState.guard;
    if (!gameNotifier.reduceHealth(
      amount: amount,
      cause: cause,
      trainingRespawn: loadout.training && trainingDamage,
    )) {
      return false;
    }
    if (guarded && !gameState.guard) {
      upgradePresentation.observe('scrapArmour', 'Guard absorbed one hit');
    }
    if (loadout.training && gameState.health == 0) {
      upgradePresentation.cancel();
      confirmationHolding.value = false;
      resetInput();
      boostButtonComponent.reset();
      playerEntrance.begin(
        respawn: true,
        reducedMotion: preferences.reducedMotion,
        camera: camera.viewfinder.position,
      );
    }
    if (gameState.health < health) {
      myPlayer.hurtFlash = 0.48;
      damageFeedback.trigger(amount: health - gameState.health);
      if (activeBoss != null) {
        _bossWasHit = true;
        for (final boss in bosses) {
          _bossDamageTaken[boss] = true;
        }
      }
      if (preferences.haptics) {
        unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
      }
    }
    audio.play(
      gameState.health == 0
          ? 'gameov.wav'
          : gameState.health < health
          ? 'hurt_player.wav'
          : 'impact_guard.wav',
    );
    return true;
  }

  void gameOver() => gameNotifier.gameOver();

  void resetInput() {
    _escapeDashStart = null;
    _escapeSlowRemaining = 0;
    _arenaAudio?.syncFoundryRail(null);
    _arenaAudio?.stopMachines();
    if (_started) myPlayer.resetMovementAudio();
    burstFire.cancelIntent();
    arsenal?.cancelIntent();
    grenadeButtonComponent.cancelAim();
    movementJoystick.onDragStop();
    movementJoystick.delta.setZero();
    weaponJoystick.onDragStop();
    weaponJoystick.delta.setZero();
    boostButtonComponent.cancelDash();
    layoutControls();
  }

  void restartGame() {
    if (recovery.pending) return;
    // Normal settled results restart immediately. Only failed/in-flight saves
    // need an asynchronous retry before replacing the run world.
    if (gameState.gameplayState == GameplayState.gameOver &&
        !_settlementSaved) {
      if (!_waitingToRestart) unawaited(_restartAfterSettlement());
      return;
    }
    final restartRush = bossRush;
    for (final departure in world.children.whereType<BossDeparture>()) {
      departure.releaseArt();
    }
    for (final boss in world.children.whereType<ExpansionBoss>()) {
      boss.releaseArt();
    }
    for (final robot in world.children.whereType<WalkerBoss>()) {
      robot.assets.dispose();
    }
    arietCandidate?.retire();
    lodestarCandidate?.retire();
    // Replace the run world, including components that are still loading and
    // are not yet visible in world.children. They must never enter a new run.
    world = _CombatWorld(this);
    _configureArenaGeometry();
    world.add(map);
    _startRun();
    if (restartRush) startBossRush();
  }

  Future<void> _restartAfterSettlement() async {
    _waitingToRestart = true;
    try {
      await leaveRun();
      if (_settlementSaved && isMounted) restartGame();
    } finally {
      _waitingToRestart = false;
    }
  }

  void pauseGame() => gameNotifier.pauseGame();
  void resumeGame() => gameNotifier.playGame();

  void addMine() => addMineAt(myPlayer.position.clone());

  void addEnemy2Component() {
    if (_enemy2Unlocked) return;
    _enemy2Unlocked = true;
    world.add(
      RepeatingAction(
        period: 1.5,
        onTick: () => _spawnEnemy(Enemy2Component()),
      ),
    );
  }

  void addEnemy3Component() {
    if (_enemy3Unlocked) return;
    _enemy3Unlocked = true;
    world.add(
      RepeatingAction(period: 3, onTick: () => _spawnEnemy(Enemy3Component())),
    );
  }

  @override
  void onRemove() {
    _arenaAudio?.syncFoundryRail(null);
    _arenaAudio?.stopMachines();
    disposed = true;
    minionNavigation.clear();
    _navigationPositions.clear();
    _navigationOwners.clear();
    _steppedMinions.clear();
    _temporaryCoverRouter.clear();
    statusArt.clear();
    upgradePresentation.cancel();
    bossReveal.reset();
    mechanicalArrival.reset();
    confirmationHolding.value = false;
    upgradeArt.clear();
    if (_started) supportCombat.clear();
    if (_survivorArtHeld) {
      _survivorArtHeld = false;
      RegunArt.shared.releaseSurvivor(loadout.character.name);
    }
    _trainingWeaponEpoch++;
    if (_cinderArtHeld) {
      _cinderArtHeld = false;
      RegunArt.shared.release('effects/cinder_flame');
    }
    if (_ringArtHeld) {
      _ringArtHeld = false;
      RegunArt.shared.release('effects/cutter_ring');
    }
    arsenal?.dispose();
    if (_weaponArtHeld) {
      _weaponArtHeld = false;
      RegunArt.shared.release(loadout.weapon.atlasName);
    }
    _syncSupplyArt(false);
    for (final departure in world.children.whereType<BossDeparture>()) {
      departure.releaseArt();
    }
    for (final boss in world.children.whereType<ExpansionBoss>()) {
      boss.releaseArt();
    }
    for (final robot in world.children.whereType<WalkerBoss>()) {
      robot.assets.dispose();
    }
    arietCandidate?.retire();
    lodestarCandidate?.retire();
    _phaseSubscription?.close();
    confirmationHolding.dispose();
    damageFeedback.healthLost.dispose();
    bossVictory.current.dispose();
    if (_started) {
      gameNotifier.acceptedUpgrade.removeListener(_acceptedUpgrade);
      gameNotifier.cancelPendingActions();
    }
    super.onRemove();
  }
}

/// One exclusive development encounter owner in a Training visit.
enum MechanicalTrial { walker, ariet, lodestar }

/// A view-only recoil offset. Camera geometry and touch coordinates stay fixed.
class _CombatWorld extends World {
  _CombatWorld(this.game);
  final RegunGame game;

  @override
  void renderFromCamera(Canvas canvas) {
    final offset = game._fireWorldOffset();
    if (offset == null || offset.isZero()) {
      super.renderFromCamera(canvas);
      return;
    }
    canvas.save();
    canvas.translate(offset.x, offset.y);
    super.renderFromCamera(canvas);
    canvas.restore();
  }
}
