import 'dart:async';

import 'package:regun/components/weapons/shootable_ordnance.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/boss_encounter.dart';

import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/expedition_walker.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/presentation/walker_battle_art.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

/// Trial-only mechanical boss. Intentionally outside BossKind/occult portals,
/// normal rewards, checkpoints and hosted admission until creator acceptance.
class WalkerBoss extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements BossEncounter {
  WalkerBoss({
    required super.position,
    this.practiceTrial = false,
    this.maximumHealth = 190,
  }) : super(size: Vector2.all(200), anchor: Anchor.center);
  final bool practiceTrial;
  @override
  final double maximumHealth;
  @override
  BossKind get kind => BossKind.walker;
  @override
  bool get enraged => prepared && combatHealth.fraction <= .5;
  Map<String, dynamic>? _savedFight;
  void restoreFight(Map<String, dynamic> state) {
    _savedFight = state;
  }

  /// Autosave can run while the atlases are still loading.
  Map<String, dynamic> get checkpointState => prepared
      ? fight.toJson()
      : _savedFight ??
            WalkerCombat(
              rig: WalkerRig(position: position.toOffset()),
              clear: (_, _, _) => true,
              hurt: (_, _) {},
              signal: (_) {},
            ).toJson();

  final assets = WalkerAssets();
  final _router = ObstacleRouter();
  static const stanceRadius = 220.0;
  late WalkerRig rig;
  late WalkerCombat fight;
  bool prepared = false;
  bool _completionAwarded = false;
  final _rocketTargets = <WalkerRound, WalkerRocketTarget>{};
  Iterable<WalkerRocketTarget> get rocketTargets sync* {
    if (!prepared || isRemoving || isRemoved || fight.defeated) return;
    _rocketTargets.removeWhere(
      (round, _) => round.removed || !fight.rounds.contains(round),
    );
    for (final round in fight.rounds.toList()) {
      if (round.kind != WalkerRoundKind.rocket || round.removed) continue;
      final target = _rocketTargets.putIfAbsent(
        round,
        () => WalkerRocketTarget(this, round),
      );
      target.position.setValues(round.position.dx, round.position.dy);
      yield target;
    }
  }

  final List<_WalkerLayer> _layers = [];
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
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    final owningWorld = game.world;
    unawaited(game.audio.warmWalker());
    if (!await game.prepareBossAssets(this, () => assets.load(combat: true))) {
      assets.dispose();
      return;
    }
    if (assets.disposed ||
        game.disposed ||
        game.world != owningWorld ||
        isRemoving ||
        isRemoved) {
      assets.dispose();
      removeFromParent();
      return;
    }
    Offset move(Offset current, Offset proposed) {
      position.setValues(current.dx, current.dy);
      game.moveTo(
        this,
        Vector2(proposed.dx, proposed.dy),
        WalkerCombat.bodyRadius,
        slide: true,
        clipStep: (from, to) {
          final end = _clipStancePath(from.toOffset(), to.toOffset());
          return Vector2(end.dx, end.dy);
        },
      );
      return position.toOffset();
    }

    rig = WalkerRig(
      position: position.toOffset(),
      maxSpeed: 260,
      acceleration: 600,
      turnSpeed: 1.5,
      agileGait: true,
      barrelLength: 158,
      bodyBounds: game.map.bounds.interior.deflate(WalkerCombat.bodyRadius),
      footBounds: game.map.bounds.interior,
      moveResolver: move,
      footResolver: (hip, foot) {
        final points = game.clipBossPath([
          Vector2(hip.dx, hip.dy),
          Vector2(foot.dx, foot.dy),
        ]);
        return points.last.toOffset();
      },
    )..reducedMotion = game.preferences.reducedMotion;
    fight = WalkerCombat(
      rig: rig,
      seed: game.random.nextInt(0x40000000),
      clear: _clear,
      hurt: (damage, cause) {
        game.damagePlayer(amount: damage, cause: cause);
      },
      signal: _signal,
      clipRushPath: _clipStancePath,
      onRushLanding: rig.plantAfterRush,
      moveCharge: (from, to) {
        // A thruster rush is airborne over minions; only solids and bosses block it.
        final end = _clipStancePath(from, to);
        for (final boss in game.bosses.where(
          (b) => b != this && !b.isRemoving,
        )) {
          if (WalkerCombat.segmentDistance(
                boss.position.toOffset(),
                from,
                end,
              ) <
              WalkerCombat.bodyRadius + game.crowdRadius(boss)) {
            return from;
          }
        }
        game.crowdOccupancy.forget(this);
        return end;
      },
      minions: () => [
        for (final e in game.liveEnemies)
          if (e is CombatEnemy &&
              !e.isBoss &&
              e is! ExpeditionWalker &&
              e.isLoaded &&
              !e.isRemoving)
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
              e is! ExpeditionWalker &&
              e.combatId.toString() == id) {
            e.crushByBoss();
          }
        }
      },
      steer: (desired, dt) {
        final safe = game.map.bounds.interior.deflate(stanceRadius + 12);
        final at = position.toOffset();
        if (!safe.inflate(6).contains(at)) {
          final inward =
              Offset(
                at.dx.clamp(safe.left, safe.right),
                at.dy.clamp(safe.top, safe.bottom),
              ) -
              at;
          return inward / inward.distance * math.max(115, desired.distance);
        }
        if (desired == Offset.zero) return desired;
        final d = Vector2(desired.dx, desired.dy);
        final routed = _router.steer(
          this,
          d.normalized(),
          game.myPlayer.position,
          game.geometry,
          radius: stanceRadius,
          side: 1,
          dt: dt,
        );
        return (routed * desired.distance).toOffset();
      },
    );
    final restored = _savedFight != null;
    if (_savedFight != null) {
      fight.restore(_savedFight!);
      if (fight.defeated) combatHealth.current = 0;
      position.setValues(rig.position.dx, rig.position.dy);
      _savedFight = null;
    }
    prepared = true;
    _layers.addAll([
      _WalkerLayer(this, -10),
      _WalkerLayer(this, 10000),
      _WalkerLayer(this, 20010),
    ]);
    owningWorld.addAll(_layers);
    game.revision.value++;
    if (!restored) game.audio.play('supply_incoming.wav');
    game.audio.playMusic('boss');
  }

  Offset _clipStancePath(Offset from, Offset to) {
    final safe = game.map.bounds.interior.deflate(stanceRadius);
    // Legacy checkpoints may already be closer to a wall. Allow inward or
    // parallel travel from there without snapping the chassis to the new inset.
    final allowed = safe.expandToInclude(from & Size.zero);
    final delta = to - from;
    var fraction = 1.0;
    if (delta.dx > 0) {
      fraction = math.min(fraction, (allowed.right - from.dx) / delta.dx);
    } else if (delta.dx < 0) {
      fraction = math.min(fraction, (allowed.left - from.dx) / delta.dx);
    }
    if (delta.dy > 0) {
      fraction = math.min(fraction, (allowed.bottom - from.dy) / delta.dy);
    } else if (delta.dy < 0) {
      fraction = math.min(fraction, (allowed.top - from.dy) / delta.dy);
    }
    final start = Vector2(from.dx, from.dy);
    for (final solid in game.geometry.solids) {
      var padded = solid.inflate(stanceRadius);
      // An older saved stance may overlap this padding. Use its current
      // clearance so that it can leave without penetrating any deeper.
      if (padded.contains(from)) {
        final gap = math.max(
          WalkerCombat.bodyRadius,
          math.max(
            math.max(solid.left - from.dx, from.dx - solid.right),
            math.max(solid.top - from.dy, from.dy - solid.bottom),
          ),
        );
        padded = solid.inflate(gap - .01);
      }
      Vector2 point(double t) => start + Vector2(delta.dx, delta.dy) * t;
      if (!ArenaGeometry.crosses(start, point(fraction), padded)) continue;
      var low = 0.0, high = fraction;
      for (var i = 0; i < 14; i++) {
        final mid = (low + high) / 2;
        if (ArenaGeometry.crosses(start, point(mid), padded)) {
          high = mid;
        } else {
          low = mid;
        }
      }
      fraction = low;
    }
    return from + delta * fraction;
  }

  bool _clear(Offset from, Offset to, double radius) {
    final floor = game.map.bounds.floor.deflate(radius);
    if (!floor.contains(from) || !floor.contains(to)) return false;
    final a = Vector2(from.dx, from.dy), b = Vector2(to.dx, to.dy);
    return !game.geometry.solids.any(
      (r) => ArenaGeometry.crosses(a, b, r.inflate(radius)),
    );
  }

  void _signal(WalkerSignal event) {
    if (event == WalkerSignal.land) {
      game.showGroundImpact(rig.position, strength: 16);
    }
    game.audio.play(switch (event) {
      WalkerSignal.rotary => 'sentry_fire.wav',
      WalkerSignal.cannon => 'shot_revolver_0.wav',
      WalkerSignal.rocket => 'walker_rocket_launch.wav',
      WalkerSignal.spool => 'reload_carbine_1.wav',
      WalkerSignal.charge => 'supply_incoming.wav',
      WalkerSignal.land => 'supply_land.wav',
      WalkerSignal.blast => 'blast.wav',
      WalkerSignal.fatal => 'supply_break.wav',
      WalkerSignal.complete => 'supply_claim.wav',
    });
    if (event == WalkerSignal.complete) {
      game.audio.playMusic(game.currentArena.name);
    }
  }

  @override
  void onMount() {
    super.onMount();
    if (isRemoving || isRemoved) return;
    if (practiceTrial) game.registerEnemy(this);
    if (prepared &&
        _savedFight == null &&
        (rig.position - position.toOffset()).distance > .01) {
      rig.carryTo(position.toOffset());
    }
  }

  @override
  bool takeDamage(double amount) {
    if (!prepared || !fight.vulnerable) return false;
    return super.takeDamage(amount);
  }

  @override
  void onCombatDeath() {
    if (!prepared) return;
    fight.beginDestruction();
    game.revision.value++;
  }

  void advanceArrival(double dt) {
    if (!prepared || fight.vulnerable || fight.defeated) return;
    final before = fight.phase;
    rig.reducedMotion = game.preferences.reducedMotion;
    // Step only deployment, including rounding at phase boundaries. Never run
    // attacks while the arrival camera is returning to the survivor.
    var remaining = dt.isFinite ? math.min(dt, 3.2) : 0.0;
    while (remaining > 0 && !fight.vulnerable) {
      final step = math.min(remaining, 1 / 120);
      fight.advance(step);
      remaining -= step;
    }
    position.setValues(rig.position.dx, rig.position.dy);
    if (before != fight.phase) game.revision.value++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!prepared ||
        game.gameState.gameplayState != GameplayState.playing ||
        game.inputBlocked) {
      return;
    }
    final before = fight.phase;
    rig.reducedMotion = game.preferences.reducedMotion;
    fight.player = game.myPlayer.position.toOffset();
    fight.playerVelocity = (game.movementIntent * game.playerWalkSpeed)
        .toOffset();
    fight.enraged = combatHealth.fraction <= .5;
    fight.advance(dt);
    position.setValues(rig.position.dx, rig.position.dy);
    if (fight.phase != before) game.revision.value++;
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
        game.unregisterEnemy(this);
        game.bossEncounter.remove(this);
      }
      removeFromParent();
      return;
    }
    // The body paints in a world sibling so the wreck/destruction sequence
    // remains visible after CombatEnemy's single fatal health transition.
    for (final layer in _layers) {
      if (layer.layer == 10000) layer.priority = 10000 + position.y.round();
    }
  }

  @override
  void onRemove() {
    _rocketTargets.clear();
    if (prepared) fight.rounds.clear();
    for (final layer in _layers) {
      layer.removeFromParent();
    }
    assets.dispose();
    super.onRemove();
  }
}

class _WalkerLayer extends Component {
  _WalkerLayer(this.owner, this.layer) : super(priority: layer);
  final WalkerBoss owner;
  final int layer;
  @override
  void render(Canvas canvas) {
    if (!owner.prepared || owner.isRemoving || owner.isRemoved) return;
    final art = WalkerBattleArt(owner.assets), fight = owner.fight;
    final game = owner.game;
    if (layer == -10) {
      art.floor(
        canvas,
        fight,
        game.currentArena,
        game.preferences.reducedMotion,
      );
    } else if (layer == 10000) {
      art.body(
        canvas,
        fight,
        reduced: game.preferences.reducedMotion,
        flash: owner.damagePaint?.colorFilter,
      );
    } else {
      art.ordnance(
        canvas,
        fight,
        game.currentArena,
        game.preferences.reducedMotion,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (owner.isRemoving || owner.isRemoved) removeFromParent();
  }
}

/// Shootable ordnance is a weapon target, never an enemy/reward/occupancy body.
class WalkerRocketTarget extends ShootableOrdnance {
  WalkerRocketTarget(this.owner, this.round) : super(size: Vector2.all(40));
  final WalkerBoss owner;
  final WalkerRound round;
  @override
  double get hitRadius => round.radius;
  @override
  bool hit(double amount) =>
      amount.isFinite &&
      amount > 0 &&
      owner.prepared &&
      !owner.isRemoving &&
      !owner.isRemoved &&
      owner.fight.interceptRocket(round);
}
