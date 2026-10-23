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

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale, RiverpodGameMixin {
  RegunGame(
    this.context, {
    this.loadout = const Loadout(),
    this.resumeSnapshot,
    this.startPaused = false,
    RunStore? runStore,
  }) : runStore = runStore ?? RunStore.shared,
       super(camera: CameraComponent(viewport: ArenaViewport()));

  final BuildContext context;
  Loadout loadout;
  final bool startPaused;
  final RunStore runStore;
  final Map<String, dynamic>? resumeSnapshot;
  late String runId;
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
  int _trainingWeaponEpoch = 0;
  static const maxProjectiles = 256;
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

  Iterable<PositionComponent> get projectileTargets sync* {
    yield* liveEnemies;
    yield* weakPoints.where((p) => !p.isRemoving && !p.combatHealth.isDead);
  }

  PositionComponent projectileOwner(PositionComponent target) =>
      target is BossWeakPoint ? target.owner : target;

  bool canStageBossMove(int count) =>
      _bossAttacks.length + _hazards.length + count <= 8;

  bool registerBossAttack(BossAttack attack) {
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

  double primaryRelease(double amount) =>
      amount *
      gameNotifier.survivor.release(
        loadout.character,
        gameState.effectRank(PowerUp.measuredShot),
        continuous: loadout.weapon.isContinuous,
      );
  double burnMultiplier(PositionComponent enemy) =>
      (loadout.character == CharacterType.moth ? 1.25 : 1) *
      ((enemy is CombatEnemy &&
              (enemy.isBoss || (enemy is ArenaEnemy && enemy.elite)))
          ? 1 + .10 * gameState.effectRank(PowerUp.scouringHeat)
          : 1);
  int get projectileCount =>
      _projectiles.length + (arsenal?.projectileReservations ?? 0);
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
    'populationLimit': director.populationLimit,
    'xp': _coins.length,
    'playerProjectiles': projectileCount,
    'hostileProjectiles': _hostileProjectiles.length,
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

  double enemyRadius(PositionComponent enemy) => enemy is BossWeakPoint
      ? 26
      : enemy is BossEncounter
      ? (enemy as BossEncounter).kind.bodyRadius
      : min(enemy.size.x, enemy.size.y) * 0.3;
  bool segmentBlocked(Vector2 start, Vector2 end) =>
      geometry.blocked(start, end);
  void constrainActor(Vector2 position, double radius) =>
      geometry.constrain(position, radius);
  final enemyTactics = EnemyTactics();
  final crowdOccupancy = CrowdOccupancy();
  double crowdRadius(PositionComponent actor) => actor is BossEncounter
      ? (actor as BossEncounter).kind.bodyRadius
      : (min(actor.size.x, actor.size.y) * .45).clamp(30.0, 52.0);

  bool reserveEnemySpace(
    PositionComponent actor, {
    double minPlayerDistance = 0,
  }) => crowdOccupancy.place(
    actor,
    crowdRadius(actor),
    (point) => geometry.constrain(point, crowdRadius(actor)),
    allowed: (point) =>
        minPlayerDistance == 0 ||
        point.distanceToSquared(myPlayer.position) >=
            minPlayerDistance * minPlayerDistance,
  );
  Vector2 enemyIntent(PositionComponent actor, EnemyKind kind) =>
      EnemyTactics.intent(
        kind,
        actor.position,
        myPlayer.position,
        movementJoystick.relativeDelta * gameState.movementSpeed,
        enemyTactics.side(actor),
      );

  void moveActor(
    PositionComponent actor,
    Vector2 direction,
    double speed,
    double dt, {
    double radius = 30,
    bool avoidCrowd = true,
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
      final boss = activeBoss;
      final yielding = boss == null || !boss.isLoaded || boss.isRemoving
          ? null
          : EnemyTactics.yieldToBoss(
              actor.position,
              boss.position,
              myPlayer.position,
              enemyTactics.side(actor),
            );
      direction = enemyTactics.spaced(actor, yielding ?? direction);
    }
    if (actor is CombatEnemy) {
      crowdOccupancy.move(
        actor,
        direction * (speed * dt),
        radius: crowdRadius(actor),
        constrain: (point) =>
            geometry.constrain(point, max(radius, crowdRadius(actor))),
        slide: avoidCrowd,
        side: enemyTactics.side(actor),
      );
      return;
    }
    final previous = actor.position.clone();
    geometry.move(actor.position, direction * (speed * dt), radius);
    if (actor is! PlayerComponent &&
        actor.position.distanceToSquared(previous) <
            speed * speed * dt * dt * 0.2 &&
        !direction.isZero()) {
      final tangent = Vector2(-direction.y, direction.x);
      actor.position.addScaled(tangent, speed * dt);
      constrainActor(actor.position, radius);
    }
  }

  void moveTo(PositionComponent actor, Vector2 target, double radius) =>
      crowdOccupancy.move(
        actor,
        target - actor.position,
        radius: crowdRadius(actor),
        constrain: (point) =>
            geometry.constrain(point, max(radius, crowdRadius(actor))),
        slide: false,
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
  }) => combat.hit(
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
  );
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
  void _queueUpgradePulse() => _upgradePulsePending = true;
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
        playerEntrance.active ||
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
  final defeatedBosses = <String>{},
      noHitBosses = <String>{},
      encounteredEnemies = <String>{};
  bool _bossWasHit = false;
  int scorpionKills = 0, eliteKills = 0;
  double _ventClock = 0;
  late ArenaGeometry geometry;
  bool _reloadWasActive = false;
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
    controls = preferences.controls;

    map = await MapComponent.loadMap();
    geometry = ArenaGeometry(
      map.bounds,
      obstacles: map.obstacles(loadout.arena),
      dynamicObstacles: () sync* {
        final drop = supplyDrops.drop;
        if (!_landingSupply && drop != null && drop.solid) yield drop.footprint;
      },
    );
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
          _settlement = settleRun();
        }
        if (_started && phase != GameplayState.gameOver) {
          scheduleMicrotask(() {
            if (isMounted && !_settled) unawaited(saveCheckpoint());
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
          if (phase == GameplayState.powerup) resetInput();
          resumeEngine();
        } else {
          resetInput();
          pauseEngine();
        }
      },
    );
    gameNotifier.upgradeConfirmed.addListener(_queueUpgradePulse);
    _startRun(clearSave: resumeSnapshot == null);
    if (resumeSnapshot != null) restoreRun(resumeSnapshot!);
    if (startPaused) gameNotifier.pauseGame();
  }

  void _startRun({bool clearSave = true}) {
    runId = DateTime.now().microsecondsSinceEpoch.toString();
    _settled = false;
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
    saveIssue = null;
    if (clearSave && !loadout.training) unawaited(runStore.clear());
    timeScale = 1;
    director = EncounterDirector();
    activeBoss = null;
    _bossDamageTaken.clear();
    _bossAttacks.clear();
    weakPoints.clear();
    bossRush = false;
    bossRushRound = 0;
    bossRushWait = 0;
    _rushBag.clear();
    _reloadWasActive = false;
    _breachCharged = false;
    breachEngine = false;
    _enemy2Unlocked = false;
    _enemy3Unlocked = false;
    _enemies.clear();
    enemyTactics.clear();
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
    combat = CombatSystem(this);
    arsenal?.dispose();
    arsenal = ArsenalSystem(this);
    _nextCombatId = 1;
    _fireCooldown = 0;
    burstFire.reset();
    _ventClock = 0;
    supplyDrops.reset(random.state ^ 0x51a7);
    _syncSupplyArt(false);
    defeatedBosses.clear();
    noHitBosses.clear();
    encounteredEnemies.clear();
    scorpionKills = 0;
    eliteKills = 0;
    boostButtonComponent.reset();
    world.add(myPlayer = PlayerComponent(position: Vector2.zero()));
    world.addAll([
      ArsenalOverlay(floor: true),
      ArsenalOverlay(),
      GrenadeAimPreview(),
      DroneVisual(),
      ArenaScenery(),
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
    );
    layoutControls();
    revision.value++;
    resumeEngine();
  }

  Map<String, dynamic> checkpoint() {
    syncGrenadeCapacity();
    Map<String, dynamic> actor(PositionComponent entity) {
      final enemy = entity as CombatEnemy;
      return {
        'kind': enemyId(entity),
        'combatId': enemy.combatId,
        'freeze': enemy.freezeState.toJson(),
        if (entity is BossEncounter) 'actor': bossEncounter.idOf(entity),
        if (entity is BossEncounter)
          'bossHit': _bossDamageTaken[entity] ?? _bossWasHit,
        'x': entity.position.x,
        'y': entity.position.y,
        'health': enemy.combatHealth.current,
        'maximum': enemy.combatHealth.maximum,
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
      'id': runId,
      'loadout': loadout.toJson(),
      ...gameNotifier.checkpoint(),
      'random': random.state,
      'assisted': assisted,
      'dash': boostButtonComponent.checkpoint(),
      'droneClock': combat.droneClock,
      'ventClock': _ventClock,
      'supplyDrops': supplyDrops.toJson(),
      'upgradePulsePending': _upgradePulsePending,
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
      'enemies': [for (final e in liveEnemies) actor(e)],
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
      'noHitBosses': noHitBosses.toList(),
      'encountered': encounteredEnemies.toList(),
      'scorpions': scorpionKills,
      'elites': eliteKills,
    };
  }

  Future<bool> saveCheckpoint() async {
    if (!_started || _settled || loadout.training || gameState.health <= 0) {
      return false;
    }
    final saved = await runStore.write(checkpoint());
    if (isMounted) {
      final issue = saved ? null : 'Run could not be saved.';
      if (saveIssue != issue) {
        saveIssue = issue;
        revision.value++;
      }
    }
    return saved;
  }

  int get earnedScrap => loadout.training
      ? 0
      : gameState.scrap +
            gameState.kills ~/ 10 +
            gameState.bosses * 15 +
            gameState.survivalSeconds ~/ 60;

  Future<void> settleRun() async {
    if (_settled || loadout.training) return;
    _settled = true;
    final settledId = runId;
    final state = gameState;
    final earned =
        state.scrap +
        state.kills ~/ 10 +
        state.bosses * 15 +
        state.survivalSeconds ~/ 60;
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
      noHitBosses: noHitBosses,
      foundFusions: state.evolutions,
      enemies: encounteredEnemies,
      assisted: assisted,
      survivorProgress: gameNotifier.survivor.toJson(),
      dashes: dashCount,
    );
    if (!assisted) {
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
    if (gameState.gameplayState == GameplayState.gameOver) {
      await _settlement;
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
      if (stateSnapshot.health <= 0) {
        throw const FormatException('Finished run');
      }
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
          entity = _createBoss(BossKind.values.byName(kind), position, maximum);
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
        if (record['freeze'] case final Map raw) {
          enemy.freezeState.restore(Map<String, dynamic>.from(raw));
        }
        enemy.restoreHealth(
          (record['health'] as num).toDouble(),
          maximum: maximum,
        );
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
      );
      if (snapshot['arsenal'] case final Map raw) {
        arsenal!.restore(Map<String, dynamic>.from(raw));
      }
      assisted = snapshot['assisted'] == true;
      combat.droneClock = (snapshot['droneClock'] as num?)?.toDouble() ?? 0;
      _ventClock = (snapshot['ventClock'] as num?)?.toDouble() ?? 0;
      boostButtonComponent.restoreCheckpoint(
        Map<String, dynamic>.from(snapshot['dash'] as Map? ?? {}),
      );
      _upgradePulsePending = snapshot['upgradePulsePending'] == true;
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
      gameNotifier.restoreCheckpoint(snapshot);
      _updateCamera();
      revision.value++;
      // Restored attacks restart at anticipation; old flying shots/hazards are
      // discarded. No offline simulation or invisible active hitbox is restored.
      return true;
    } on Object {
      world = World();
      world.add(map);
      _startRun();
      saveIssue = 'Saved run could not be restored.';
      return false;
    }
  }

  bool registerEnemy(PositionComponent enemy) {
    if (!_enemies.contains(enemy) && _enemies.length >= maxEnemies) {
      return false;
    }
    if (enemy is CombatEnemy && enemy.combatId == 0) {
      enemy.combatId = _nextCombatId++;
    }
    _enemies.add(enemy);
    encounteredEnemies.add(enemyId(enemy));
    return true;
  }

  void unregisterEnemy(PositionComponent enemy) {
    if (_started && enemy is CombatEnemy) {
      gameNotifier.survivor.forgetVictim(enemy.combatId);
    }
    _enemies.remove(enemy);
    crowdOccupancy.forget(enemy);
    if (enemy is BossEncounter) {
      bossEncounter.remove(enemy);
      _bossDamageTaken.remove(enemy);
    }
  }

  void _spawnEnemy(PositionComponent enemy) {
    if (gameState.gameplayState != GameplayState.playing) return;
    _enemies.removeWhere((entity) => entity.isRemoving || entity.isRemoved);
    if (_enemies.length >= maxEnemies) return;
    if (!canReinforce) return;
    final floor = map.bounds.floor.deflate(60);
    final visible = camera.visibleWorldRect.inflate(100);
    var spawn = Vector2.zero();
    // Spawn near the view, inside the map, without appearing on the player.
    for (var attempt = 0; attempt < 12; attempt++) {
      final side = random.nextInt(4);
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
    if (!reserveEnemySpace(enemy, minPlayerDistance: 300)) return;
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
  }) {
    if (enemy.parent != world) return;
    if (enemyId(enemy) == 'scorpion') scorpionKills++;
    if (enemy is ArenaEnemy && enemy.elite) eliteKills++;
    gameNotifier.recordKill(score: score, boss: boss);
    combat.onKill(enemy);
    if (!bossRush) dropXP(enemy.position, loadout.training ? 7 : xp);
    if (boss) {
      final bossKind = (enemy as BossEncounter).kind;
      gameNotifier.awardBossHealth();
      bossVictory.show(bossKind);
      final kind = bossKind.name;
      defeatedBosses.add(kind);
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
    EnemyComponent() => 'scorpion',
    Enemy2Component() => 'mummy',
    Enemy3Component() => 'ranged',
    ArenaEnemy() => enemy.kind.name,
    BossEncounter() => (enemy as BossEncounter).kind.name,
    _ => 'unknown',
  };

  void practiceBoss(BossKind kind) {
    if (!loadout.training) return;
    bossRush = false;
    _retirePracticeBosses();
    resumeGame();
    spawnBoss(kind);
  }

  void _retirePracticeBosses() {
    for (final old in bosses.toList()) {
      final health = (old as CombatEnemy).combatHealth;
      // Retire practice targets without kill rewards or a core; owned attacks
      // see the dead health object and clean themselves up on their next tick.
      health.damage(health.maximum);
      old.removeFromParent();
    }
    bossEncounter.clear();
    _bossDamageTaken.clear();
    director.bossActive = false;
  }

  void spawnShadowBoss() => spawnBoss(BossKind.shadow);

  PositionComponent _createBoss(
    BossKind kind,
    Vector2 position,
    double health,
  ) => switch (kind) {
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
    if ((!companion && bosses.isNotEmpty) ||
        bosses.length >= 2 ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final position = myPlayer.position + Vector2(companion ? -450 : 450, 10);
    constrainActor(position, 110);
    _bossWasHit = false;
    final scaling = bossRush ? 0.0 : 180 * pow(director.cycle - 1, 1.3);
    final actor = _createBoss(kind, position, kind.baseHealth + scaling);
    if (!reserveEnemySpace(actor, minPlayerDistance: 220)) {
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
    _retirePracticeBosses();
    for (final enemy in _enemies.toList()) {
      enemy.removeFromParent();
    }
    for (final area in _hazards.toList()) {
      area.removeFromParent();
    }
    for (final shot in _hostileProjectiles.toList()) {
      shot.removeFromParent();
    }
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
    if (_rushBag.isEmpty) _rushBag.addAll(BossKind.values);
    if (_rushBag.length == BossKind.values.length) _rushBag.shuffle(random);
    var index = _rushBag.indexWhere((kind) => kind != excluding);
    if (index < 0) {
      _rushBag.addAll(BossKind.values.where((kind) => kind != excluding));
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
    if (random.nextDouble() < .4) {
      spawnBoss(_nextRushBoss(excluding: first), companion: true);
    }
    if (bosses.isEmpty) bossRushWait = 1;
    revision.value++;
  }

  bool consumeBreachCharge() {
    final charged = _breachCharged;
    _breachCharged = false;
    return charged;
  }

  Future<bool> changeTrainingWeapon(WeaponType next) async {
    if (disposed ||
        !loadout.training ||
        gameState.gameplayState != GameplayState.paused) {
      return false;
    }
    if (next == loadout.weapon) return true;
    final epoch = ++_trainingWeaponEpoch;
    final names = [
      if (next.hasLeasedArt) next.atlasName,
      if (next == WeaponType.cinderHose) 'effects/cinder_flame',
    ];
    for (final name in names) {
      await RegunArt.shared.acquire(name);
    }
    if (disposed ||
        epoch != _trainingWeaponEpoch ||
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
    loadout = Loadout(
      weapon: next,
      character: loadout.character,
      arena: loadout.arena,
      training: true,
    );
    _weaponArtHeld = next.hasLeasedArt;
    _cinderArtHeld = next == WeaponType.cinderHose;
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
    if (playerEntrance.active) return false;
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
        ? state.bulletNumberRange * 2 + 1
        : 1 + min(3, state.countRank(PowerUp.numberOfBulletsPerShotIncrease));
    if (projectileCount + count > maxProjectiles) return false;
    audio.play('shot_${loadout.weapon.name}_${shotsFired % 3}.wav');
    shotsFired++;
    myPlayer.recoil =
        1 + releaseOffset / WeaponFeel.of(loadout.weapon).recovery;
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
    _breachCharged = false;

    if (loadout.weapon != WeaponType.burstRifle || burstFire.pending == 0) {
      damage = primaryRelease(damage);
    } else {
      damage *= 1 + gameNotifier.survivor.releaseBonus;
    }
    final releaseId = gameNotifier.survivor.lastRelease;
    final releaseBonus = gameNotifier.survivor.releaseBonus;
    final spread =
        (loadout.weapon == WeaponType.shotgun ? pi / 20 : pi / 32) *
        (1 -
            max(0, state.rank(PowerUp.numberOfBulletsPerShotIncrease) - 3) *
                .04);
    for (var i = 0; i < count; i++) {
      if (projectileCount >= maxProjectiles) break;
      final direction = baseDirection.clone()
        ..rotate((i - (count - 1) / 2) * spread);
      var muzzleOffset = Vector2.zero();
      if (loadout.weapon == WeaponType.carbine) {
        // A tight per-round grouping, not a shotgun fan or a wandering bullet.
        direction.rotate((random.nextDouble() * 2 - 1) * pi / 90);
        final side = Vector2(-baseDirection.y, baseDirection.x);
        muzzleOffset =
            side * ((random.nextDouble() * 2 - 1) * 2) +
            baseDirection * ((random.nextDouble() * 2 - 1) * 1.25);
      }
      final socket = WeaponArtSpec.of(loadout.weapon).releaseOffset(
        (loadout.weapon == WeaponType.burstRifle ? baseDirection : direction)
            .toOffset(),
      );
      addProjectile(
        BulletComponent(
          position:
              myPlayer.position + muzzleOffset + Vector2(socket.dx, socket.dy),
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
    if (!_started) return;
    if (playerEntrance.active) {
      if (gameState.gameplayState == GameplayState.paused) return;
      resetInput();
      final before = playerEntrance.elapsed;
      playerEntrance.advance(dt);
      final impact = playerEntrance.landingStart + playerEntrance.dropDuration;
      if (before < impact && playerEntrance.elapsed >= impact) {
        audio.play('impact_guard.wav');
      }
      final centerCamera = map.bounds.cameraPosition(
        Vector2.zero(),
        camera.viewport.virtualSize / camera.viewfinder.zoom,
      );
      camera.viewfinder.position =
          playerEntrance.cameraFrom +
          (centerCamera - playerEntrance.cameraFrom) *
              playerEntrance.cameraProgress;
      if (playerEntrance.atCenter) myPlayer.position.setZero();
      if (playerEntrance.elapsed >= playerEntrance.fall) damageFeedback.reset();
      // Mount pending components without advancing attacks or contact damage.
      super.update(0);
      if (playerEntrance.elapsed >= playerEntrance.duration) {
        final respawn = playerEntrance.respawning;
        playerEntrance.cancel();
        if (respawn) {
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
    bossEncounter.advance(_lingeringBossAttack);
    _weaponImpacts = 0;
    final phase = gameState.gameplayState;
    if (phase == GameplayState.paused || phase == GameplayState.gameOver) {
      return;
    }
    // Gameplay timers use simulation time; pause and restart cannot leak work.
    _reloadWasActive = gameState.reloading;
    final reloadWait = gameNotifier.reloadRemainingSeconds;
    gameNotifier.advanceTime(dt * timeScale);
    if (_reloadWasActive && !gameState.reloading) _breachCharged = true;
    if (gameState.gameplayState == GameplayState.playing) {
      final firing = !weaponJoystick.relativeDelta.isZero();
      if (loadout.weapon.usesArsenalRuntime) {
        arsenal!.advance(dt, blockedFor: min(dt, reloadWait));
      } else if (loadout.weapon == WeaponType.burstRifle) {
        final wait = min(dt, reloadWait);
        if (wait > 0) {
          burstFire.advance(
            wait,
            held: false,
            interval: .6,
            ready: () => false,
            release: (_) => false,
          );
        }
        burstFire.advance(
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
        combat.upgradePulse();
      }
      syncGrenadeCapacity();
      grenades.advance(dt, grenadeRecharge);
      combat.update(dt);
    }
    enemyTactics.rebuild(liveEnemies);
    crowdOccupancy.rebuild([..._enemies, ...bosses], crowdRadius);
    super.update(dt);
    final state = gameState;
    if (state.gameplayState == GameplayState.playing) {
      _checkpointElapsed += dt;
      if (_checkpointElapsed >= 15) {
        _checkpointElapsed = 0;
        unawaited(saveCheckpoint());
      }
      _advanceRush(dt);
      if (director.advance(dt) &&
          !bossRush &&
          (!loadout.training || _enemies.length < 4)) {
        final kind = director.chooseEnemy(random);
        final enemy = switch (kind) {
          EnemyKind.scorpion => EnemyComponent(),
          EnemyKind.mummy => Enemy2Component(),
          EnemyKind.ranged => Enemy3Component(),
          _ => ArenaEnemy(
            kind,
            elite:
                director.elapsed > 150 &&
                random.nextDouble() <
                    min(0.35, 0.12 + (director.cycle - 1) * 0.03),
          ),
        };
        _spawnEnemy(enemy);
      }
      if (director.bossDue && !loadout.training) {
        spawnBoss(director.chooseBoss(random));
      }
      if (loadout.arena == ArenaType.foundry &&
          director.bossesDefeated > 0 &&
          activeBoss == null) {
        _ventClock += dt;
        if (_ventClock >= 6) {
          _ventClock = 0;
          final vents = map.vents
            ..sort(
              (a, b) => a
                  .distanceToSquared(myPlayer.position)
                  .compareTo(b.distanceToSquared(myPlayer.position)),
            );
          addHostileArea(
            vents.first,
            radius: 115,
            warning: 1.2,
            active: 1.5,
            cause: 'Foundry vent',
          );
        }
      }
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
        onBreak: () => audio.play('supply_break.wav'),
      );
    }
    _syncSupplyArt(supplyDrops.drop != null && !bossRush);
    _updateCamera();
    layoutControls();
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
    for (var i = 0; i < 30; i++) {
      final spot = Offset(
        area.left + random.nextDouble() * area.width,
        area.top + random.nextDouble() * area.height,
      );
      if ((spot - myPlayer.position.toOffset()).distance < 260 ||
          (supplyDrops.previous != null &&
              (spot - supplyDrops.previous!).distance < 350) ||
          geometry.solids.any(
            (r) => r.inflate(SupplyDrop.radius + 20).contains(spot),
          )) {
        continue;
      }
      return spot;
    }
    return null;
  }

  /// Only the landing transition calls this. The crush footprint remains lethal
  /// to ordinary enemies, with a grenade-strength blast and outer pressure wave.
  void landSupplyDrop(Offset position) {
    _landingSupply = true;
    try {
      audio.play('supply_land.wav');
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
          enemy.isBoss
              ? enemy.combatHealth.maximum * .03
              : enemy.combatHealth.current,
          primary: false,
        );
      }
      combat.explode(
        center,
        radius: 205,
        damage: 8,
        grenade: true,
        allowFragments: false,
      );
    } finally {
      _landingSupply = false;
    }
    // A player caught beneath a friendly pod is displaced, never damaged.
    constrainActor(myPlayer.position, 30);
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

  void _updateCamera() {
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
    if (playerEntrance.active ||
        boostButtonComponent.tapped ||
        (loadout.training && !trainingDamage)) {
      return false;
    }
    final health = gameState.health;
    if (!gameNotifier.reduceHealth(
      amount: amount,
      cause: cause,
      trainingRespawn: loadout.training && trainingDamage,
    )) {
      return false;
    }
    if (loadout.training && gameState.health == 0) {
      resetInput();
      boostButtonComponent.reset();
      playerEntrance.begin(
        respawn: true,
        reducedMotion: preferences.reducedMotion,
        camera: camera.viewfinder.position,
      );
    }
    if (gameState.health < health) {
      myPlayer.hurtFlash = 0.32;
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
    // Normal settled results restart immediately. Only failed/in-flight saves
    // need an asynchronous retry before replacing the run world.
    if (gameState.gameplayState == GameplayState.gameOver &&
        !_settlementSaved) {
      if (!_waitingToRestart) unawaited(_restartAfterSettlement());
      return;
    }
    final restartRush = bossRush;
    for (final boss in world.children.whereType<ExpansionBoss>()) {
      boss.releaseArt();
    }
    // Replace the run world, including components that are still loading and
    // are not yet visible in world.children. They must never enter a new run.
    world = World();
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
    disposed = true;
    if (_survivorArtHeld) {
      _survivorArtHeld = false;
      RegunArt.shared.releaseSurvivor(loadout.character.name);
    }
    _trainingWeaponEpoch++;
    if (_cinderArtHeld) {
      _cinderArtHeld = false;
      RegunArt.shared.release('effects/cinder_flame');
    }
    arsenal?.dispose();
    if (_weaponArtHeld) {
      _weaponArtHeld = false;
      RegunArt.shared.release(loadout.weapon.atlasName);
    }
    _syncSupplyArt(false);
    for (final boss in world.children.whereType<ExpansionBoss>()) {
      boss.releaseArt();
    }
    _phaseSubscription?.close();
    damageFeedback.healthLost.dispose();
    bossVictory.current.dispose();
    if (_started) {
      gameNotifier.upgradeConfirmed.removeListener(_queueUpgradePulse);
      gameNotifier.cancelPendingActions();
    }
    super.onRemove();
  }
}
