import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/weapons/shootable_ordnance.dart';
import 'package:regun/game.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/presentation/lodestar_battle_art.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';

/// Complete native Training owner. Deliberately no BossKind/reward/save/online ID.
class LodestarBoss extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements
        ShapedTarget,
        LocalDamageTarget,
        CompoundGroundActor,
        BossEncounter {
  LodestarBoss({
    required super.position,
    required this.heading,
    this.maximumHealth = 240,
    this.practiceTrial = false,
  }) : super(size: Vector2.all(200), anchor: Anchor.center);
  final double heading;
  @override
  final double maximumHealth;
  final bool practiceTrial;
  bool _completionAwarded = false;
  Map<String, dynamic>? _saved;
  @override
  BossKind get kind => BossKind.lodestar;
  @override
  bool get enraged => prepared && fight.enraged;
  void restoreFight(Map<String, dynamic> state) => _saved = state;
  Map<String, dynamic> get checkpointState => prepared
      ? fight.checkpoint()
      : _saved ??
            LodestarCombat(
              rig: LodestarRig(head: position.toOffset(), heading: heading),
              bounds: const Rect.fromLTRB(-100000, -100000, 100000, 100000),
              clear: (_, __, ___) => true,
              hurt: (_, __) => false,
              signal: (_) {},
              poseLegal: (_) => true,
            ).checkpoint();
  final assets = LodestarAssets();
  late LodestarCombat fight;
  bool prepared = false, retired = false;
  final layers = <Component>[];
  final _mineTargets = <LodestarMine, LodestarMineTarget>{};
  Offset? _queryPoint, _observedPlayer;
  LodestarSection? lastSection;
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
  bool get readyForFight => prepared && !retired;
  @override
  Iterable<TargetCapsule> get targetShape => prepared && fight.vulnerable
      ? fight.shapes(fight.rig.poses, targets: true)
      : const [];
  @override
  Iterable<TargetCapsule> get groundShape =>
      prepared && !retired && !fight.finished
      ? fight.shapes(fight.rig.poses)
      : const [];
  Iterable<LodestarMineTarget> get mineTargets sync* {
    if (!readyForFight || fight.defeated) return;
    _mineTargets.removeWhere((m, _) => m.removed || !fight.mines.contains(m));
    for (final m in fight.mines) {
      if (m.removed) continue;
      final target = _mineTargets.putIfAbsent(
        m,
        () => LodestarMineTarget(this, m),
      );
      target.position.setValues(m.position.dx, m.position.dy);
      yield target;
    }
  }

  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    final owningWorld = game.world;
    unawaited(game.audio.warmWalker());
    if (!await game.prepareBossAssets(this, () => assets.load(combat: true))) {
      assets.dispose();
      return;
    }
    if (retired ||
        assets.disposed ||
        game.disposed ||
        game.world != owningWorld ||
        isRemoving ||
        isRemoved) {
      retire();
      removeFromParent();
      return;
    }
    final rig = LodestarRig(
      head: position.toOffset(),
      heading: heading,
      acceptPose: _legalSweep,
    );
    fight =
        LodestarCombat(
            rig: rig,
            bounds: game.map.bounds.interior,
            clear: clear,
            poseLegal: _legal,
            hurt: (damage, cause) =>
                game.damagePlayer(amount: damage, cause: cause),
            signal: (cue) {
              game.audio.play(cue);
              if (cue == 'supply_land.wav' && prepared) {
                game.showGroundImpact(fight.exit, strength: 15);
              }
            },
            visible: (at) =>
                game.camera.visibleWorldRect.deflate(50).contains(at),
          )
          ..course = heading
          ..player = game.myPlayer.position.toOffset();
    if (_saved != null) {
      fight.restore(_saved!, continueRun: true);
      _saved = null;
      combatHealth.current = maximumHealth * fight.sections.fraction;
      _sync();
    }
    prepared = true;
    layers.addAll([
      _LodestarLayer(this, -10),
      for (var i = 0; i < 6; i++) _LodestarLayer(this, 10000, section: i),
      _LodestarLayer(this, 20010),
    ]);
    owningWorld.addAll(layers);
    game.audio.playMusic('boss');
    game.audio.play('supply_incoming.wav');
    game.revision.value++;
  }

  bool clear(Offset a, Offset b, double radius) {
    final bounds = game.map.bounds.interior.deflate(radius);
    return bounds.contains(a) &&
        bounds.contains(b) &&
        !game.geometry.solids.any(
          (r) => ArenaGeometry.crosses(
            Vector2(a.dx, a.dy),
            Vector2(b.dx, b.dy),
            r.inflate(radius),
          ),
        );
  }

  bool _legalSweep(List<LodestarPose> from, List<LodestarPose> to) {
    if (!prepared) return true;
    var reach = 0.0;
    for (var i = 0; i < 6; i++) {
      reach = math.max(
        reach,
        (from[i].position - to[i].position).distance +
            LodestarRig.difference(from[i].yaw, to[i].yaw).abs() * 120,
      );
    }
    final steps = math.max(1, (reach / .8).ceil());
    if (steps > 256) return false;
    for (var n = 0; n <= steps; n++) {
      final t = n / steps;
      if (!_legal([
        for (var i = 0; i < 6; i++)
          LodestarPose(
            to[i].section,
            Offset.lerp(from[i].position, to[i].position, t)!,
            from[i].yaw + LodestarRig.difference(to[i].yaw, from[i].yaw) * t,
          ),
      ])) {
        return false;
      }
    }
    return true;
  }

  bool _legal(List<LodestarPose> poses) {
    // Called only after preparation except initial straight pose construction.
    if (!prepared) return true;
    final shapes = fight.shapes(poses);
    for (final shape in shapes) {
      if (!clear(shape.a, shape.b, shape.radius + .4)) return false;
    }
    // One owner reserves the whole ground shape. Other living bodies and
    // pending reservations stay separate; initial Training has no adds.
    for (final e in game.liveEnemies) {
      if (identical(e, this) || e is! CombatEnemy || e.combatHealth.isDead) {
        continue;
      }
      final at = e.position.toOffset();
      final clearance = game.crowdRadius(e) + 4;
      for (final shape in shapes) {
        if (shape.distance(at) < clearance) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void onMount() {
    if (retired || assets.disposed || game.disposed) {
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
  void noteDamageContact(Offset point) {
    _queryPoint = point;
  }

  @override
  bool takeDamage(double amount) => receiveLocalDamage(amount);
  @override
  bool receiveLocalDamage(
    double amount, {
    Offset? point,
    Offset? blastCenter,
    double? blastRadius,
  }) {
    if (!readyForFight ||
        !fight.vulnerable ||
        isRemoving ||
        game.presentationHeld ||
        game.gameState.gameplayState != GameplayState.playing) {
      return false;
    }
    final sections = fight.sections;
    List<LodestarDamage> result;
    if (blastCenter != null && blastRadius != null) {
      final selected = <LodestarSection>[];
      for (final p in fight.rig.poses) {
        if (!fight.exposed(p.section)) continue;
        if (fight
            .partShapes(p)
            .any(
              (s) =>
                  s.distance(blastCenter) <= blastRadius &&
                  clear(blastCenter, (s.a + s.b) / 2, 0),
            )) {
          selected.add(p.section);
        }
      }
      result = sections.blast(
        selected,
        amount * 240 / maximumHealth,
        LodestarHitLedger(),
      );
    } else {
      final at = point ?? _queryPoint ?? game.myPlayer.position.toOffset();
      final candidates =
          fight.rig.poses.where((p) => fight.exposed(p.section)).toList()..sort(
            (a, b) => fight
                .partShapes(a)
                .map((s) => s.distance(at))
                .reduce(math.min)
                .compareTo(
                  fight
                      .partShapes(b)
                      .map((s) => s.distance(at))
                      .reduce(math.min),
                ),
          );
      _queryPoint = null;
      if (candidates.isEmpty) return false;
      // Persistent burn belongs to its originally hit section; breaking it
      // cannot silently transfer a paid damage-over-time stream elsewhere.
      final section = lastDamageSource == 'burn' || lastDamageSource == 'cinder'
          ? lastSection ?? candidates.first.section
          : candidates.first.section;
      if (!fight.exposed(section)) return false;
      result = sections.primary(
        section,
        amount * 240 / maximumHealth,
        LodestarHitLedger(),
      );
    }
    if (result.isEmpty) return false;
    lastSection = result.first.section;
    final wasDefeated = fight.defeated;
    fight.localDamage(result);
    if (!wasDefeated && fight.defeated) {
      game.showGroundImpact(position.toOffset(), strength: 16);
    }
    combatHealth.current = maximumHealth * sections.fraction;
    game.revision.value++;
    return true;
  }

  @override
  void onCombatDeath() {
    if (prepared) fight.destroy();
  }

  void advanceArrival(double dt) {
    if (!readyForFight || fight.phase != LodestarPhase.arrival) return;
    final before = fight.depths.first;
    var left = math.min(dt, 3.2);
    while (left > 0 && fight.phase == LodestarPhase.arrival) {
      final step = math.min(left, 1 / 120);
      fight.advance(step);
      left -= step;
    }
    if (before > .65 && fight.depths.first <= .65) {
      game.showGroundImpact(fight.entry, strength: 14);
    }
    _sync();
  }

  void _sync() {
    final p =
        fight.rig.poses.map((p) => p.position).reduce((a, b) => a + b) / 6;
    position.setValues(p.dx, p.dy);
  }

  @override
  void update(double dt) {
    if (!prepared ||
        retired ||
        game.gameState.gameplayState != GameplayState.playing ||
        game.inputBlocked) {
      return;
    }
    super.update(dt);
    if (!fight.defeated) {
      fight.player = game.myPlayer.position.toOffset();
      final previous = _observedPlayer;
      final observed = previous == null || dt <= 0
          ? Offset.zero
          : (fight.player - previous) / dt;
      fight.playerVelocity = observed.distance <= game.playerWalkSpeed * 1.6
          ? observed
          : Offset.zero;
      _observedPlayer = fight.player;
    }
    final previous = fight.phase;
    fight.advance(dt);
    _sync();
    if (previous != fight.phase) game.revision.value++;
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
      game.audio.playMusic(game.loadout.arena.name);
      game.revision.value++;
    }
  }

  void retire() {
    retired = true;
    _mineTargets.clear();
    if (prepared) {
      fight.shots.clear();
      fight.mines.clear();
      fight.warnedSweep.clear();
    }
    for (final layer in layers) {
      layer.removeFromParent();
    }
    layers.clear();
    assets.dispose();
  }

  @override
  void onRemove() {
    retire();
    if (!practiceTrial && identical(game.lodestarCandidate, this)) {
      game.lodestarCandidate = null;
    }
    super.onRemove();
  }
}

class _LodestarLayer extends Component {
  _LodestarLayer(this.owner, this.layer, {this.section})
    : super(priority: layer);
  final LodestarBoss owner;
  final int layer;
  final int? section;
  @override
  void update(double dt) {
    if (section != null && owner.readyForFight) {
      priority = 10000 + owner.fight.rig.poses[section!].position.dy.round();
    }
  }

  @override
  void render(Canvas c) {
    if (!owner.readyForFight || owner.isRemoving || owner.isRemoved) return;
    final art = LodestarBattleArt(owner.assets),
        reduced = owner.game.preferences.reducedMotion;
    if (layer == -10) {
      art.floor(c, owner.fight, owner.game.loadout.arena, reduced);
    } else if (layer == 10000) {
      art.body(c, owner.fight, reduced, section: section);
    } else {
      art.ordnance(c, owner.fight, owner.game.loadout.arena, reduced);
    }
  }
}

class LodestarMineTarget extends ShootableOrdnance {
  LodestarMineTarget(this.owner, this.mine) : super(size: Vector2.all(30));
  final LodestarBoss owner;
  final LodestarMine mine;
  @override
  double get hitRadius => 16;
  @override
  bool hit(double amount) =>
      amount.isFinite &&
      amount > 0 &&
      owner.readyForFight &&
      owner.fight.disarm(mine);
}
