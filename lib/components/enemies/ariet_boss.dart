import 'package:regun/systems/ariet_escort_tactics.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/ariet_escort_study.dart';
import 'package:regun/components/weapons/shootable_ordnance.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/ariet_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/ariet_battle_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_hull.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/target_shape.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

/// Native solo gunship encounter; explicit practice trials skip normal rewards.
class ArietBoss extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements ShapedTarget, BossEncounter {
  ArietBoss({
    required super.position,
    this.maximumHealth = 160,
    this.practiceTrial = false,
    this.seed = 427,
  }) : super(size: Vector2.all(200), anchor: Anchor.center);
  @override
  final double maximumHealth;
  final bool practiceTrial;
  final int seed;
  @override
  BossKind get kind => BossKind.ariet;
  @override
  bool get enraged => prepared && combatHealth.fraction <= .5;
  bool _completionAwarded = false;
  Map<String, dynamic>? _saved;
  void restoreFight(Map<String, dynamic> state) {
    _saved = state;
  }

  Map<String, dynamic> get checkpointState => {
    'fight': prepared
        ? fight.checkpoint()
        : _saved?['fight'] ??
              ArietCombat(
                rig: ArietRig(position: position.toOffset()),
                seed: seed,
                clear: (_, __, ___) => true,
                hurt: (_, __) => false,
                signal: (_) {},
                landingLegal: (_, __) => true,
                deploy: (_) {},
              ).checkpoint(),
    'escorts': prepared
        ? [
            for (final e in escorts)
              if (!e.isRemoving && (!e.prepared || !e.combatHealth.isDead))
                {
                  'id': e.escortId,
                  'x': e.position.x,
                  'y': e.position.y,
                  'health': e.prepared ? e.combatHealth.current : 50,
                },
          ]
        : _saved?['escorts'] ?? [],
  };

  final assets = ArietAssets();
  final _router = ObstacleRouter();
  final _navigationBody = PositionComponent();
  final _rocketTargets = <ArietRound, ArietRocketTarget>{};
  Iterable<ArietRocketTarget> get rocketTargets sync* {
    if (!prepared || retired || fight.defeated) return;
    _rocketTargets.removeWhere(
      (r, _) => r.removed || !fight.rounds.contains(r),
    );
    for (final r in fight.rounds) {
      if (!r.seeker || r.removed) continue;
      final t = _rocketTargets.putIfAbsent(r, () => ArietRocketTarget(this, r));
      t.position.setValues(r.position.dx, r.position.dy);
      yield t;
    }
  }

  (Offset, Offset, double, double, double, double, double, double)? _shapeKey;
  List<TargetCapsule> _shapeCache = const [];
  late ArietRig rig;
  late ArietCombat fight;
  bool prepared = false, retired = false;
  final escorts = <ArietEscort>[];
  final escortTactics = ArietEscortTactics();
  bool escortGoalLegal(Offset p, double radius) => clear(p, p, radius);
  Iterable<ArietEscortBody> get escortBodies sync* {
    for (final e in escorts) {
      if (e.prepared && !e.isRemoving && !e.combatHealth.isDead) {
        yield ArietEscortBody(
          e.escortId,
          e.position.toOffset(),
          radius: 88 * ArietEscort.rigScale,
          velocity: e.rig.velocity * ArietEscort.rigScale,
        );
      }
    }
  }

  bool claimEscortFire(ArietEscort actor) {
    final ready = escorts.where((e) => e.canBeginVolley).map((e) => e.escortId);
    if (escortTactics.preferredShooter(ready) != actor.escortId ||
        !fight.claimEscortVolley(actor.escortId)) {
      return false;
    }
    escortTactics.noteVolley(actor.escortId);
    return true;
  }

  final layers = <Component>[];
  static const airBodyPriority = 18000;
  int get bodyPriority => prepared && rig.height > 1
      ? airBodyPriority
      : 10000 + rig.position.dy.round();
  @override
  bool get isBoss => true;
  @override
  bool get canFreeze => false;
  @override
  double get impactResponse => 0;
  @override
  int get xpReward => 0;
  @override
  int get scoreReward => 0;
  @override
  Iterable<TargetCapsule> get targetShape {
    if (!prepared) return const [];
    final key = (
      rig.position,
      rig.hoverOffset,
      rig.yaw,
      rig.cannonYaw,
      rig.flakYaw,
      rig.rotaryYaw[0],
      rig.rotaryYaw[1],
      rig.height,
    );
    if (_shapeKey != key) {
      _shapeKey = key;
      _shapeCache = ArietHull.regions(rig).toList(growable: false);
    }
    return _shapeCache;
  }

  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    final world = game.world;
    await game.audio.warmWalker();
    await assets.load(combat: true);

    if (retired ||
        assets.disposed ||
        game.disposed ||
        game.world != world ||
        isRemoving ||
        isRemoved) {
      retire();
      removeFromParent();
      return;
    }
    rig = ArietRig(
      position: position.toOffset(),
      resolveMove: (from, to) {
        final p = Vector2(from.dx, from.dy);
        game.geometry.move(
          p,
          Vector2(to.dx - from.dx, to.dy - from.dy),
          ArietRig.navigationRadius,
        );
        game.crowdOccupancy.forget(this);
        return Offset(p.x, p.y);
      },
    );
    fight = ArietCombat(
      rig: rig,
      seed: seed,
      clear: clear,
      steer: (intent, dt) {
        if (intent.distance < .1) return intent;
        final direction = Vector2(intent.dx, intent.dy).normalized();
        _navigationBody.position.setValues(rig.position.dx, rig.position.dy);
        final routed = _router.steer(
          _navigationBody,
          direction,
          game.myPlayer.position,
          game.geometry,
          radius: ArietRig.navigationRadius,
          side: 1,
          dt: dt,
        );
        return Offset(routed.x, routed.y) * intent.distance;
      },
      hurt: (damage, cause) =>
          game.damagePlayer(amount: damage.toInt(), cause: cause),
      signal: _signal,
      landingLegal: _legalLanding,
      deploy: (drop) {
        if (retired || fight.defeated) return;
        final escort = ArietEscort(
          this,
          drop.id,
          position: Vector2(drop.landing.dx, drop.landing.dy),
        );
        escorts.add(escort);
        world.add(escort);
      },
      minions: () => [
        for (final e in game.liveEnemies)
          if (e is CombatEnemy && !e.isBoss && e is! ArietEscort)
            WalkerMinion(
              e.combatId.toString(),
              e.position.toOffset(),
              game.crowdRadius(e),
            ),
      ],
      crushMinion: (id) {
        for (final e in game.liveEnemies.toList()) {
          if (e is CombatEnemy &&
              !e.isBoss &&
              e is! ArietEscort &&
              e.combatId.toString() == id) {
            e.crushByBoss();
          }
        }
      },
    );
    if (_saved case final saved?) {
      fight.restore(Map<String, dynamic>.from(saved['fight'] as Map));
      if (fight.defeated) combatHealth.current = 0;
    }
    prepared = true;
    if (_saved case final saved?) {
      for (final raw in saved['escorts'] as List) {
        final e = raw as Map;
        final escort = ArietEscort(
          this,
          e['id'] as int,
          position: Vector2(
            (e['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
          ),
        );
        escort.restoreHealth((e['health'] as num).toDouble(), maximum: 50);
        escorts.add(escort);
        world.add(escort);
      }
    }

    layers.addAll([
      _ArietLayer(this, -10),
      _ArietLayer(this, 10000)..priority = airBodyPriority,
      _ArietLayer(this, 20010),
    ]);
    world.addAll(layers);

    game.revision.value++;
    game.audio.playMusic('boss');
  }

  bool clear(Offset from, Offset to, double radius) {
    final bounds = game.map.bounds.interior.deflate(radius);
    if (!bounds.contains(from) || !bounds.contains(to)) return false;
    return !game.geometry.solids.any(
      (r) => ArenaGeometry.crosses(
        Vector2(from.dx, from.dy),
        Vector2(to.dx, to.dy),
        r.inflate(radius),
      ),
    );
  }

  bool _legalLanding(Offset p, double radius) {
    final body = math.max(radius, 150.0);
    return clear(p, p, body) &&
        (p - game.myPlayer.position.toOffset()).distance > 110 &&
        !escorts.any(
          (e) =>
              !e.isRemoving &&
              (!e.prepared || !e.combatHealth.isDead) &&
              (p - e.position.toOffset()).distance < 340,
        );
  }

  void _signal(ArietCue cue) {
    game.audio.play(switch (cue) {
      ArietCue.nose => 'sentry_fire.wav',
      ArietCue.cannon => 'shot_revolver_0.wav',
      ArietCue.engine => 'blast.wav',
      ArietCue.seeker => 'walker_rocket_launch.wav',
      ArietCue.flak => 'shot_revolver_0.wav',
      ArietCue.intercept => 'blast.wav',
      ArietCue.release => 'walker_rocket_launch.wav',
      ArietCue.land => 'supply_land.wav',
      ArietCue.incoming => 'supply_incoming.wav',
      ArietCue.fatal => 'supply_break.wav',
      ArietCue.impact => 'blast.wav',
      ArietCue.complete => 'supply_claim.wav',
    });
    if (cue == ArietCue.complete) game.audio.playMusic(game.loadout.arena.name);
  }

  @override
  void onMount() {
    if (retired || isRemoving || isRemoved || game.disposed) {
      removeFromParent();
      return;
    }
    super.onMount();
    if (practiceTrial && !game.registerEnemy(this)) {
      retire();
      removeFromParent();
    }
    game.crowdOccupancy.forget(this);
  }

  @override
  bool takeDamage(double amount) => prepared && fight.vulnerable && !retired
      ? super.takeDamage(amount)
      : false;
  @override
  void onCombatDeath() {
    if (!prepared) return;
    fight.beginDestruction();
    for (final e in escorts.toList()) {
      e.shutdown();
    }
    game.revision.value++;
  }

  void advanceArrival(double dt) {
    if (!prepared || fight.vulnerable || fight.defeated) return;
    final before = fight.phase;
    rig.reducedMotion = game.preferences.reducedMotion;
    // Step only deployment, including rounding at phase boundaries. Never run
    // attacks while the arrival camera is returning to the survivor.
    var remaining = dt.isFinite ? math.min(dt, 2.7) : 0.0;
    while (remaining > 0 && !fight.vulnerable) {
      final step = math.min(remaining, 1 / 120);
      fight.advance(step);
      remaining -= step;
    }
    position.setValues(rig.bodyPosition.dx, rig.bodyPosition.dy);
    if (before != fight.phase) game.revision.value++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!prepared ||
        retired ||
        game.gameState.gameplayState != GameplayState.playing ||
        game.inputBlocked) {
      return;
    }
    fight.player = game.myPlayer.position.toOffset();
    fight.playerVelocity = (game.movementIntent * game.playerWalkSpeed)
        .toOffset();
    rig.reducedMotion = game.preferences.reducedMotion;
    fight.enraged = combatHealth.fraction <= .5;
    fight.healthFraction = combatHealth.fraction;
    escortTactics.advance(
      dt,
      target: fight.player,
      velocity: fight.playerVelocity,
      bodies: escortBodies,
      legal: escortGoalLegal,
      sight: clear,
      mayHoldFirePosition: fight.escortsMayFire,
    );
    final before = fight.phase;
    fight.advance(dt);
    position.setValues(rig.bodyPosition.dx, rig.bodyPosition.dy);
    for (final layer in layers) {
      if (layer is _ArietLayer && layer.layer == 10000) {
        layer.priority = bodyPriority;
      }
    }
    if (before != fight.phase) game.revision.value++;
    if (fight.finished && !_completionAwarded) {
      _completionAwarded = true;
      if (!practiceTrial) {
        game.enemyDefeated(
          this,
          xp: 25,
          score: 1200,
          boss: true,
          mechanicalComplete: true,
        );
      } else {
        game.bossEncounter.remove(this);
      }
      game.unregisterEnemy(this);
      removeFromParent();
      game.revision.value++;
    }
  }

  void retire() {
    retired = true;
    _rocketTargets.clear();
    if (prepared) {
      fight.rounds.clear();
      fight.flakTargets.clear();
      fight.exhaust.clear();
      for (final d in fight.drops) {
        d.aborted = true;
      }
    }
    for (final e in escorts.toList()) {
      e.shutdown();
    }
    escorts.clear();
    escortTactics.reset();
    for (final layer in layers) {
      layer.removeFromParent();
    }
    layers.clear();
    assets.dispose();
  }

  @override
  void onRemove() {
    retire();
    if (!practiceTrial && identical(game.arietCandidate, this)) {
      game.arietCandidate = null;
    }
    super.onRemove();
  }
}

class _ArietLayer extends Component {
  _ArietLayer(this.owner, this.layer) : super(priority: layer);
  final ArietBoss owner;
  final int layer;
  @override
  void render(Canvas canvas) {
    final c = canvas;
    if (!owner.prepared ||
        owner.retired ||
        owner.isRemoving ||
        owner.isRemoved) {
      return;
    }
    final art = ArietBattleArt(owner.assets);
    if (layer == -10) {
      art.floor(
        c,
        owner.fight,
        owner.game.loadout.arena,
        owner.game.preferences.reducedMotion,
      );
    } else if (layer == 10000) {
      art.body(
        c,
        owner.fight,
        owner.game.preferences.reducedMotion,
        owner.damagePaint?.colorFilter,
        arena: owner.game.loadout.arena,
      );
    } else {
      art.rounds(
        c,
        owner.fight,
        owner.game.loadout.arena,
        owner.game.preferences.reducedMotion,
      );
    }
  }
}

/// A scaled current Walker rig with a deliberately restricted escort policy.
/// All world movement, feet, body and muzzle dimensions use the same mapping.
class ArietEscort extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  ArietEscort(this.owner, this.escortId, {required super.position})
    : super(size: Vector2.all(205 * rigScale), anchor: Anchor.center);
  static const rigScale = ArietEscortStudy.combatScale;
  final ArietBoss owner;
  final int escortId;
  final _router = ObstacleRouter();
  late WalkerRig rig;
  bool prepared = false;
  double _burst = -1, _next = 0, _cooldown = .35, _recoil = 0, _flash = 0;
  int _shots = 0;
  Offset _aimTarget = Offset.zero;
  @override
  int get xpReward => 0;
  @override
  int get scoreReward => 0;
  @override
  double get impactResponse => .7;
  @override
  Future<void> onLoad() async {
    initializeHealth(50);
    final floor = game.map.bounds.interior;
    rig = WalkerRig(
      position: Offset(position.x / rigScale, position.y / rigScale),
      maxSpeed: 385 / rigScale,
      acceleration: 1050 / rigScale,
      turnSpeed: 2.0,
      agileGait: true,
      standingHeight: 64,
      stanceWidth: 1.10,
      agileStepTime: .18,
      agileLift: 12,
      barrelLength: 158,
      bodyBounds: Rect.fromLTRB(
        floor.left / rigScale,
        floor.top / rigScale,
        floor.right / rigScale,
        floor.bottom / rigScale,
      ).deflate(88),
      footBounds: Rect.fromLTRB(
        floor.left / rigScale,
        floor.top / rigScale,
        floor.right / rigScale,
        floor.bottom / rigScale,
      ),
      moveResolver: (from, to) {
        position.setValues(from.dx * rigScale, from.dy * rigScale);
        game.moveTo(
          this,
          Vector2(to.dx * rigScale, to.dy * rigScale),
          88 * rigScale,
          slide: true,
        );
        return Offset(position.x / rigScale, position.y / rigScale);
      },
    );
    rig.trackTurret = false;
    prepared = true;
    if (owner.retired || owner.fight.defeated) {
      shutdown();
    }
  }

  @override
  void onMount() {
    if (owner.retired || owner.fight.defeated || isRemoving || isRemoved) {
      removeFromParent();
      return;
    }
    super.onMount();
  }

  @override
  void onCombatDeath() {
    shutdown();
  }

  void shutdown() {
    if (prepared) {
      game.unregisterEnemy(this);
    }
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!prepared || owner.retired || owner.fight.defeated) {
      shutdown();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing ||
        game.inputBlocked ||
        combatHealth.isDead) {
      return;
    }
    rig.reducedMotion = game.preferences.reducedMotion;
    if ((rig.position * rigScale - position.toOffset()).distance > .05) {
      rig.carryTo(Offset(position.x / rigScale, position.y / rigScale));
    }
    final player = game.myPlayer.position.toOffset();
    final goal = owner.escortTactics.waypoint(
      escortId,
      position.toOffset(),
      owner.escortGoalLegal,
    );
    final delta = goal - position.toOffset();
    final intent = ArietRig.limit(delta / rigScale * 1.8, 365 / rigScale);
    final desired = intent.distance < .01
        ? Vector2.zero()
        : Vector2(intent.dx, intent.dy).normalized();
    final routed = _router.steer(
      this,
      desired,
      Vector2(goal.dx, goal.dy),
      game.geometry,
      radius: 88 * rigScale,
      side: escortId == 1 ? -1 : 1,
      dt: dt,
    );
    // Shared right-hand traffic rule: opposite headings choose opposite world
    // tangents. Alternating by escort ID sends both into the same side and can
    // preserve a head-on deadlock even with collision-safe sliding.
    final traffic = routed.clone();
    for (final other in owner.escorts) {
      if (identical(other, this) ||
          !other.prepared ||
          other.isRemoving ||
          other.combatHealth.isDead ||
          routed.isZero()) {
        continue;
      }
      final relative = other.position - position;
      final ahead = relative.dot(routed);
      final lateral = relative.dot(Vector2(-routed.y, routed.x));
      if (ahead > 0 && ahead < 240 && lateral.abs() < 142) {
        traffic.add(Vector2(-routed.y, routed.x) * (1 - lateral.abs() / 142));
      }
    }
    final spaced = game.enemyTactics.spaced(this, traffic);
    rig.command = freezeHeld || impactHeld
        ? Offset.zero
        : spaced.toOffset() * intent.distance * impactStride;
    if (delta.distance > 90) rig.desiredYaw = ArietCombat.heading(delta);
    rig.target = player / rigScale;
    rig.paused = freezeHeld || impactHeld;
    rig.advance(dt);
    position.setValues(rig.position.dx * rigScale, rig.position.dy * rigScale);
    _aimTarget = ArietEscortTactics.intercept(
      _muzzle(),
      player,
      owner.fight.playerVelocity,
    );
    final pivot =
        (rig.turretPivot.projected + WalkerCombat.visualOffset) * rigScale;
    if (!rig.paused) {
      rig.turretYaw = ArietRig.turn(
        rig.turretYaw,
        ArietCombat.heading(_aimTarget - pivot),
        8 * dt,
      );
    }
    _recoil = math.max(0, _recoil - 100 * dt);
    _flash = math.max(0, _flash - dt);
    _cooldown -= dt;
    if (!owner.fight.escortsMayFire || freezeHeld || impactHeld) {
      _burst = -1;
      _cooldown = math.max(_cooldown, .12);
      return;
    }
    if (_burst < 0 && canBeginVolley && owner.claimEscortFire(this)) {
      _burst = 0;
      _next = .14;
      _shots = 0;
    }
    if (_burst >= 0) {
      if (!firingLaneClear) {
        _burst = -1;
        _cooldown = .25;
        return;
      }
      _burst += dt;
      if (_burst >= _next &&
          _shots < 3 &&
          owner.fight.escortRelease(
            escortId,
            _muzzle(recoil: 7),
            rig.turretYaw,
          )) {
        _shots++;
        _next += .16;
        _recoil = 7;
        _flash = .045;
      }
      if (_shots == 3 || _burst > .8) {
        _burst = -1;
        _cooldown = 1.1;
      }
    }
  }

  bool get firingLaneClear => owner.escortTactics.firingLaneClear(
    escortId,
    _muzzle(),
    _aimTarget,
    bodies: owner.escortBodies,
  );

  bool get canBeginVolley {
    if (!prepared ||
        owner.retired ||
        isRemoving ||
        combatHealth.isDead ||
        freezeHeld ||
        impactHeld ||
        _cooldown > 0 ||
        _burst >= 0 ||
        !owner.fight.escortsMayFire) {
      return false;
    }
    final muzzle = _muzzle(), player = _aimTarget, direction = player - muzzle;
    return direction.distance < 700 &&
        owner.clear(muzzle, player, 6) &&
        firingLaneClear &&
        ArietRig.difference(
              rig.turretYaw,
              ArietCombat.heading(direction),
            ).abs() <
            .24;
  }

  Offset _muzzle({double? recoil}) {
    final pivot =
        (rig.turretPivot.projected + WalkerCombat.visualOffset) * rigScale;
    final d = ArietCombat.unit(rig.turretYaw),
        rel = pivot - position.toOffset();
    final along = rel.dx * d.dx + rel.dy * d.dy;
    final cross = math.max(0, rel.distanceSquared - along * along);
    final minimum =
        -along + math.sqrt(math.max(0, math.pow(101 * rigScale, 2) - cross));
    return pivot +
        d * math.max((158 - (recoil ?? _recoil)) * rigScale, minimum);
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    if (!prepared || combatHealth.isDead) return;
    c.save();
    c.translate(
      size.x / 2 - position.x,
      size.y / 2 - position.y + WalkerCombat.visualOffset.dy * rigScale,
    );
    c.scale(rigScale);
    WalkerArt(owner.assets.walker, flashFilter: damagePaint?.colorFilter).paint(
      c,
      rig,
      muzzleOverride: _muzzle() / rigScale - WalkerCombat.visualOffset,
    );
    c.restore();
    if (_flash > 0) {
      c.save();
      c.translate(size.x / 2 - position.x, size.y / 2 - position.y);
      AttackVfx.stamp(
        c,
        18,
        _muzzle(),
        27,
        material: AttackMaterial.ember,
        anchor: Anchor.center,
      );
      c.restore();
    }
    super.render(c);
  }
}

class ArietRocketTarget extends ShootableOrdnance {
  ArietRocketTarget(this.owner, this.round) : super(size: Vector2.all(28));
  final ArietBoss owner;
  final ArietRound round;
  @override
  double get hitRadius => round.radius;
  @override
  bool hit(double amount) =>
      amount.isFinite &&
      amount > 0 &&
      owner.prepared &&
      !owner.retired &&
      !owner.isRemoving &&
      !owner.isRemoved &&
      owner.fight.intercept(round);
}
