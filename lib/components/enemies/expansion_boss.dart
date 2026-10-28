import 'package:regun/components/enemies/ground_projection.dart';
import 'package:regun/presentation/boss_vfx.dart';

import 'dart:math';

import 'package:regun/presentation/marshal_aim.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/boss_attack.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/enemies/boss_weak_point.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/boss_attack_shape.dart';

enum ExpansionPhase { arrival, approach, warning, active, recovery, defeated }

class AttackCue {
  AttackCue(
    this.shape, {
    this.warning = 1.1,
    this.active = .35,
    this.delay = 0,
    this.damage = 1,
  });
  final BossAttackShape shape;
  final double warning, active, delay;
  final int damage;
  double get end => delay + warning + active;
}

class BossMove {
  BossMove(
    this.name,
    this.pose,
    this.cues, {
    this.recovery = 1.5,
    this.brace = false,
    this.prop,
    this.propPositions = const [],
  });
  final String name;
  final int pose;
  final List<AttackCue> cues;
  final double recovery;
  final bool brace;
  final BossPropKind? prop;
  final List<Vector2> propPositions;
  double get windup => cues.isEmpty ? 1.0 : cues.first.warning;
  double get duration => cues.fold(2.2, (value, cue) => max(value, cue.end));
}

/// Shared lifecycle, not shared movesets: each controller below authors its own
/// committed geometry, weak points and phase combinations.
abstract class ExpansionBoss extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy
    implements BossEncounter {
  ExpansionBoss(this.kind, {super.position, required this.maximumHealth})
    : super(size: Vector2.all(200), anchor: Anchor.center);
  @override
  final BossKind kind;
  @override
  final double maximumHealth;
  @override
  bool get isBoss => true;
  @override
  bool get enraged => combatHealth.fraction <= .5;
  @override
  int get xpReward => 25;
  @override
  int get scoreReward => 1200;
  ExpansionPhase phase = ExpansionPhase.arrival;
  double clock = 0, _traceClock = 0, _recovery = 1.5, _impactUntil = 0;
  int sequence = 0;
  bool _interrupted = false, _countered = false, _acquired = false;
  BossMove? currentMove;
  BossAttack? get laserAttack {
    if (kind != BossKind.marshal || phase == ExpansionPhase.defeated) {
      return null;
    }
    final beams =
        _owned
            .where(
              (a) =>
                  a.material == AttackMaterial.laser &&
                  !a.isRemoving &&
                  a.remaining > 0,
            )
            .toList()
          ..sort((a, b) => (a.delay - a.age).compareTo(b.delay - b.age));
    return beams.isEmpty ? null : beams.first;
  }

  final recentRoute = <Vector2>[];
  Vector2? projectionPosition;
  final _owned = <BossAttack>[];
  final _props = <BossWeakPoint>[];
  late SpriteAnimationComponent body;
  late SpriteAnimation _idle, _walk, _enragedIdle, _impact, _aimHold;
  final facing = Vector2(1, 0);
  double get targetDistance => position.distanceTo(game.myPlayer.position);
  Vector2 get target {
    final point =
        game.myPlayer.position +
        game.movementJoystick.relativeDelta * game.playerWalkSpeed * .7;
    game.constrainActor(point, 35);
    return point;
  }

  Vector2 safePoint(Vector2 point) {
    final result = point.clone();
    game.constrainActor(result, 35);
    return result;
  }

  List<Vector2> path(List<Vector2> points) => game.clipBossPath(points);
  BossMove plan();
  Vector2 shotOrigin(Vector2 aim) => position.clone();

  SpriteAnimation clip(
    List<int> frames,
    double duration, {
    bool loop = false,
  }) => SpriteAnimation.spriteList(
    [
      for (final frame in frames)
        RegunArt.shared.sprite('bosses/${kind.name}', frame),
    ],
    stepTime: duration / frames.length,
    loop: loop,
  );

  late final GroundProjection _ground;
  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
    _ground = GroundProjection(this, renderGround);
    game.world.add(_ground);
    final encounterWorld = game.world;
    await RegunArt.shared.acquire('bosses/${kind.name}');
    _acquired = true;
    if (game.disposed || game.world != encounterWorld) {
      releaseArt();
      return;
    }
    _idle = clip([0, 1, 2, 3], 1.2, loop: true);
    _walk = clip([4, 5, 6, 7], .64, loop: true);
    _enragedIdle = clip([32, 33, 34, 35], 1.0, loop: true);
    _aimHold = clip([10], 1.0, loop: true);
    body = SpriteAnimationComponent(
      size: Vector2.all(kind.spriteSize),
      position: Vector2(100, 170 - .38 * kind.spriteSize),
      anchor: Anchor.center,
      animation: _idle,
    );
    add(body);
    body.paint.colorFilter = BossArt.ambient(game.loadout.arena);
    add(
      CircleHitbox(
        radius: kind.bodyRadius,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void onMount() {
    super.onMount();
    game.revision.value++;
  }

  @override
  void onRemove() {
    _ground.removeFromParent();
    cancelAttacks();
    game.releaseBossAttack(this);
    super.onRemove();
    releaseArt();
  }

  void releaseArt() {
    if (!_acquired) return;
    _acquired = false;
    RegunArt.shared.release('bosses/${kind.name}');
  }

  void cancelAttacks() {
    for (final attack in _owned) {
      attack.removeFromParent();
    }
    for (final prop in _props) {
      prop.removeFromParent();
    }
    _owned.clear();
    _props.clear();
  }

  void interrupt() {
    if (_interrupted || combatHealth.isDead) return;
    _interrupted = true;
    cancelAttacks();
    game.audio.play('boss_${kind.name}_break.wav');
    _enterRecovery(4.1);
  }

  void _enterRecovery(double duration) {
    phase = ExpansionPhase.recovery;
    clock = 0;
    _recovery = duration;
    body.animation = clip([28, 29, 30, 31], min(duration, .65));
    game.releaseBossAttack(this);
  }

  bool beginMove() {
    if (!game.claimBossAttack(this)) return false;
    final move = plan();
    if (kind == BossKind.magistrate &&
        !game.canStageBossMove(move.cues.length)) {
      // Stage the complete volley atomically. Existing floor hazards must not
      // silently reduce a five/seven-chain attack to one or two chains.
      game.releaseBossAttack(this);
      clock = .45;
      return false;
    }
    if (!game.bossMoveHasEscape(move.cues)) {
      game.releaseBossAttack(this);
      // Try another authored pattern after a bounded rethink, not a costly
      // per-frame search or an endless retry of an impossible attack.
      sequence++;
      clock = .45;
      return false;
    }
    currentMove = move;
    sequence++;
    _interrupted = false;
    _countered = false;
    facing.setFrom((target - position).normalized());
    if (facing.isZero()) facing.setValues(1, 0);
    body.scale.x = facing.x < 0 ? -1 : 1;
    final start = 8 + move.pose * 8;
    body.animation = clip(
      kind == BossKind.marshal && move.pose == 0
          ? [8, 9, 10, 10]
          : [start, start + 1, start + 2, start + 3],
      move.windup,
    );
    final impact = move.pose == 2
        ? [27, 28, 29]
        : [start + 4, start + 5, start + 6, start + 7];
    _impact = clip(
      kind == BossKind.marshal && move.pose == 0 ? [10] : impact,
      .48,
    );
    phase = ExpansionPhase.warning;
    clock = 0;
    game.audio.play('boss_${kind.name}_warn.wav');
    for (final cue in move.cues) {
      final attack = BossAttack(
        bossKind: kind,
        shape: cue.shape,
        owner: combatHealth,
        material: kind == BossKind.marshal && move.pose == 0
            ? AttackMaterial.laser
            : switch (kind) {
                BossKind.saint => AttackMaterial.glass,
                BossKind.magistrate => AttackMaterial.chain,
                BossKind.sovereign => AttackMaterial.ember,
                _ => AttackMaterial.stone,
              },
        warning: cue.warning,
        active: cue.active,
        delay: cue.delay,
        damage: cue.damage,
        cause: '${kind.title}: ${move.name}',
        color: kind == BossKind.saint
            ? const Color(0xffBBCBD3)
            : kind == BossKind.sovereign
            ? const Color(0xffDC9860)
            : const Color(0xffD8B77B),
        sound: 'boss_${kind.name}_hit.wav',
        onImpact: () {
          if (phase == ExpansionPhase.warning ||
              phase == ExpansionPhase.active) {
            // Each delayed echo/strike gets a fresh release pose as well as
            // its own sound and floor mark; no idle body emitting a combo.
            body.animation = _impact.clone();
            _impactUntil = clock + .5;
          }
        },
      );
      if (game.addBossAttack(attack)) _owned.add(attack);
    }
    if (move.prop != null) {
      for (final point in move.propPositions) {
        final prop = BossWeakPoint(
          owner: this,
          position: safePoint(point),
          kind: move.prop!,
          onBroken: interrupt,
          health: 5,
        );
        _props.add(prop);
        game.world.add(prop);
      }
    }
    return true;
  }

  @override
  bool takeDamage(double amount) {
    final bracing =
        kind == BossKind.marshal &&
        currentMove?.brace == true &&
        [ExpansionPhase.warning, ExpansionPhase.active].contains(phase) &&
        incomingDirection != null &&
        (!lastHitWasSecondary || incomingSupportBallistic) &&
        incomingDirection!.dot(facing) < -.55;
    if (bracing) {
      amount *= .25;
      if (!_countered) {
        _countered = true;
        final counter = BossAttack(
          bossKind: kind,
          owner: combatHealth,
          shape: BossAttackShape.line(
            path([shotOrigin(target), target]),
            width: 12,
          ),
          material: AttackMaterial.laser,
          warning: 1.05,
          active: .24,
          onImpact: () {
            body.animation = clip([10], .3);
            _impactUntil = clock + .3;
          },
          cause: 'Marshal counter',
          sound: 'boss_marshal_hit.wav',
        );
        if (game.addBossAttack(counter)) _owned.add(counter);
      }
    } else if (phase == ExpansionPhase.recovery && _interrupted) {
      amount *= 1.5;
    }
    return super.takeDamage(amount);
  }

  @override
  void onCombatDeath() {
    cancelAttacks();
    game.releaseBossAttack(this);
    phase = ExpansionPhase.defeated;
    clock = 0;
    body.animation = clip([36, 37, 38, 39], .75);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (phase == ExpansionPhase.defeated) {
      clock += dt;
      if (clock >= .8) removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    clock += dt;
    _traceClock += dt;
    if (_traceClock >= .4) {
      _traceClock = 0;
      recentRoute.add(game.myPlayer.position.clone());
      if (recentRoute.length > 5) recentRoute.removeAt(0);
    }
    switch (phase) {
      case ExpansionPhase.arrival:
        if (clock >= 1.8) {
          phase = ExpansionPhase.approach;
          clock = 0;
        }
      case ExpansionPhase.approach:
        final before = position.clone();
        if (targetDistance > (kind == BossKind.sovereign ? 420 : 330)) {
          game.moveActor(
            this,
            (game.myPlayer.position - position).normalized(),
            kind == BossKind.sovereign
                ? 100
                : kind == BossKind.saint
                ? 260
                : 240,
            dt,
            radius: 75,
          );
        }
        final walking = position.distanceToSquared(before) > .01;
        final desired = walking
            ? _walk
            : enraged
            ? _enragedIdle
            : _idle;
        if (body.animation != desired) body.animation = desired;
        if ((game.myPlayer.position.x - position.x).abs() > 25) {
          body.scale.x = game.myPlayer.position.x < position.x ? -1 : 1;
        }
        if (clock >= (kind == BossKind.saint ? .5 : .85) && beginMove()) {
          clock = 0;
        }
      case ExpansionPhase.warning:
        if (clock >= currentMove!.windup) {
          phase = ExpansionPhase.active;
          body.animation = _impact.clone();
          _impactUntil = clock + .5;
        }
      case ExpansionPhase.active:
        if (clock >= _impactUntil && body.animation?.loop == false) {
          final aimingNextBeam =
              kind == BossKind.marshal &&
              currentMove?.pose == 0 &&
              currentMove!.cues.any((cue) => cue.delay + cue.warning > clock);
          body.animation = aimingNextBeam
              ? _aimHold
              : enraged
              ? _enragedIdle
              : _idle;
        }
        if (clock >= currentMove!.duration) {
          _enterRecovery(currentMove!.recovery);
        }
      case ExpansionPhase.recovery:
        if (clock >= .7 && body.animation?.loop == false) {
          body.animation = enraged ? _enragedIdle : _idle;
        }
        if (clock >= _recovery) {
          cancelAttacks();
          phase = ExpansionPhase.approach;
          clock = 0;
          currentMove = null;
        }
      case ExpansionPhase.defeated:
        break;
    }
  }

  void renderGround(Canvas canvas) {
    if (game.bossReveal.actors.contains(this) ||
        phase == ExpansionPhase.arrival) {
      return;
    }
    final center = (size / 2).toOffset();
    final vfx = BossVfx(
      kind: kind,
      ambient: BossArt.ambient(game.loadout.arena),
      reducedMotion: game.preferences.reducedMotion,
    );
    BossArt.contactShadow(
      canvas,
      center + const Offset(0, 65),
      kind.bodyRadius,
    );
    if (phase == ExpansionPhase.arrival ||
        (phase == ExpansionPhase.recovery && _interrupted)) {
      vfx.disk(
        canvas,
        center,
        85,
        ambient: BossArt.ambient(game.loadout.arena),
        warning: true,
        progress: (clock / 1.8).clamp(0, 1),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final vfx = BossVfx(
      kind: kind,
      ambient: BossArt.ambient(game.loadout.arena),
      reducedMotion: game.preferences.reducedMotion,
    );
    super.render(canvas);
    final center = (size / 2).toOffset();
    final beam = laserAttack;
    final beamAim = beam?.shape.points.last;
    body.paint.color = beamAim == null
        ? const Color(0xffffffff)
        : const Color(0x00ffffff);
    if (beamAim != null) {
      MarshalAim.paint(
        canvas,
        center,
        center + (beamAim - position).toOffset(),
        kind.spriteSize,
        left: MarshalAim.facingLeft(
          position.toOffset(),
          beam!.shape.points.first.toOffset(),
          beamAim.toOffset(),
          kind.spriteSize,
        ),
        ambient: BossArt.ambient(game.loadout.arena),
      );
    }

    if (kind == BossKind.marshal &&
        currentMove?.brace == true &&
        [ExpansionPhase.warning, ExpansionPhase.active].contains(phase)) {
      vfx.armour(
        canvas,
        center,
        80,
        facing: atan2(facing.y, facing.x),
        full: false,
      );
    }

    if (kind == BossKind.saint &&
        (phase == ExpansionPhase.warning || phase == ExpansionPhase.active) &&
        projectionPosition != null) {
      final sprite = RegunArt.shared.sprite('bosses/saint', 0);
      final offset = projectionPosition! - position;
      sprite.render(
        canvas,
        position: size / 2 + offset,
        size: Vector2.all(220),
        anchor: Anchor.center,
        overridePaint: Paint()..color = const Color(0x66FFFFFF),
      );
    }
  }
}

class BellkeeperBoss extends ExpansionBoss {
  BellkeeperBoss({super.position, required super.maximumHealth})
    : super(BossKind.bellkeeper);
  @override
  BossMove plan() {
    final delta = target - position, heading = atan2(delta.y, delta.x);
    if (targetDistance < 570 && sequence % 3 == 1) {
      return BossMove(
        'Clapper sentence',
        0,
        [
          AttackCue(
            BossAttackShape.sweep(
              position,
              540,
              angle: heading - 1.85,
              arc: 3.7,
              innerRadius: 180,
              width: 30,
            ),
            warning: 1.05,
            active: .7,
            damage: 2,
          ),
        ],
        recovery: 1.8,
        prop: BossPropKind.bell,
        propPositions: [position + Vector2(105, 35)],
      );
    }
    final reach = (delta.length * 1.5 + 550).clamp(1100.0, 3400.0);
    final travel = reach / (enraged ? 1450 : 1200);
    return BossMove(
      'Broken toll',
      1,
      [
        AttackCue(
          BossAttackShape.ring(
            position,
            reach,
            angle: heading + .55,
            arc: 1.0,
            width: 34,
          ),
          warning: 1.05,
          active: travel,
        ),
        if (enraged || sequence > 0)
          AttackCue(
            BossAttackShape.ring(
              position,
              reach,
              angle: heading - .55,
              arc: 1.0,
              width: 34,
            ),
            delay: 1.15 + travel,
            warning: 1.0,
            active: travel * .9,
          ),
      ],
      recovery: 1.4,
      prop: BossPropKind.bell,
      propPositions: [position + Vector2(105, 35)],
    );
  }
}

class MagistrateBoss extends ExpansionBoss {
  MagistrateBoss({super.position, required super.maximumHealth})
    : super(BossKind.magistrate);

  /// Clip the ray's length, never bend its angle at a wall or column.
  List<Vector2> _spoke(double angle, double reach) {
    final direction = Vector2(cos(angle), sin(angle));
    final floor = game.geometry.bounds.floor.deflate(35);
    var low = 0.0, high = reach;
    for (var i = 0; i < 14; i++) {
      final length = (low + high) / 2;
      final point = position + direction * length;
      if (!floor.contains(point.toOffset()) ||
          game.segmentBlocked(position, point)) {
        high = length;
      } else {
        low = length;
      }
    }
    return [position.clone(), position + direction * low];
  }

  @override
  BossMove plan() {
    final velocity = game.movementJoystick.relativeDelta * game.playerWalkSpeed;
    final aim = safePoint(game.myPlayer.position + velocity * .8);
    final forward = aim - position;
    final random = game.random;
    final count = enraged ? 7 : 5;
    final spread = (enraged ? 1.60 : 1.35) + random.nextDouble() * .08;
    final heading =
        atan2(forward.y, forward.x) + (random.nextDouble() * 2 - 1) * .02;
    final reach = (position.distanceTo(aim) + 620).clamp(1250.0, 1950.0);
    final reverse = random.nextBool();
    final staggered = random.nextBool();
    final cues = <AttackCue>[];
    final ends = <Vector2>[];
    for (var i = 0; i < count; i++) {
      final middle = (count - 1) ~/ 2;
      final offset = (i - middle) * spread / (count - 1);
      final jitter = i == middle ? 0.0 : (random.nextDouble() * 2 - 1) * .015;
      final points = _spoke(
        heading + offset + jitter,
        reach * (i == middle ? 1 : .88 + random.nextDouble() * .12),
      );
      if (points.first.distanceTo(points.last) < 90) continue;
      ends.add(points.last);
      final order = reverse ? count - 1 - i : i;
      cues.add(
        AttackCue(
          BossAttackShape.line(points, width: enraged ? 18 : 20),
          warning: enraged ? .95 : 1.0,
          delay: staggered ? (order % 3) * .16 : 0,
          active: .48,
          damage: 2,
        ),
      );
    }
    return BossMove(
      staggered ? 'Judgement volley' : 'Iron barrage',
      sequence % 3,
      cues,
      prop: BossPropKind.clasp,
      // Two readable break opportunities; no connecting or branching chains.
      propPositions: [for (final end in ends.take(2)) end],
      recovery: enraged ? 1.05 : 1.3,
    );
  }
}

class MirrorSaintBoss extends ExpansionBoss {
  MirrorSaintBoss({super.position, required super.maximumHealth})
    : super(BossKind.saint);
  @override
  BossMove plan() {
    final player = game.myPlayer.position.clone();
    var travel = game.movementJoystick.relativeDelta * game.playerWalkSpeed;
    if (travel.length < 30) travel = (player - position).normalized() * 160;
    final forward = travel.normalized(), side = Vector2(-forward.y, forward.x);
    final aim = safePoint(player + travel * .7);
    final near = recentRoute.isEmpty
        ? player - forward * 120
        : recentRoute.last;
    final mirror = safePoint(player - forward * 240 + side * 210);
    if (sequence % 3 == 0) {
      projectionPosition = safePoint(near - side * 110);
      return BossMove(
        'Shatterwake',
        0,
        [
          AttackCue(
            BossAttackShape.trace(
              path([near, player, safePoint(player + travel * 1.9)]),
              width: 50,
            ),
            warning: .85,
            active: 1.0,
            damage: 2,
          ),
          AttackCue(
            BossAttackShape.circle(aim, 125),
            delay: .45,
            warning: .85,
            active: .85,
          ),
          if (enraged)
            AttackCue(
              BossAttackShape.circle(safePoint(aim + side * 220), 120),
              delay: 1.05,
              warning: .85,
              active: .7,
            ),
        ],
        prop: BossPropKind.mirror,
        propPositions: [projectionPosition!],
        recovery: 1.05,
      );
    }
    final other = safePoint(player + forward * 210 - side * 260);
    projectionPosition = mirror;
    if (sequence % 3 == 1) {
      return BossMove(
        'Splinter crossfire',
        1,
        [
          AttackCue(
            BossAttackShape.line(path([mirror, aim + side * 480]), width: 42),
            warning: .9,
            active: .45,
            damage: 2,
          ),
          AttackCue(
            BossAttackShape.line(
              path([other, safePoint(player + travel * 1.15 - side * 80)]),
              width: 42,
            ),
            delay: .5,
            warning: .9,
            active: .45,
            damage: 2,
          ),
          if (enraged)
            AttackCue(
              BossAttackShape.circle(safePoint(player + travel * 1.5), 110),
              delay: 1.0,
              warning: .9,
              active: .8,
            ),
        ],
        prop: BossPropKind.mirror,
        propPositions: [mirror, other],
        recovery: 1.05,
      );
    }
    return BossMove(
      'False benediction',
      2,
      [
        AttackCue(
          BossAttackShape.line(
            path([position, aim + forward * 650]),
            width: 44,
          ),
          warning: .85,
          active: .5,
          damage: 2,
        ),
        AttackCue(
          BossAttackShape.line(
            path([mirror, safePoint(player + travel * 1.2)]),
            width: 44,
          ),
          delay: .45,
          warning: .85,
          active: .5,
          damage: 2,
        ),
        AttackCue(
          BossAttackShape.circle(
            safePoint(player + travel * 1.4),
            enraged ? 155 : 130,
          ),
          delay: .9,
          warning: .9,
          active: .8,
        ),
      ],
      prop: BossPropKind.mirror,
      propPositions: [mirror],
      recovery: 1.15,
    );
  }
}

class KilnSovereignBoss extends ExpansionBoss {
  KilnSovereignBoss({super.position, required super.maximumHealth})
    : super(BossKind.sovereign);
  @override
  Vector2 shotOrigin(Vector2 aim) =>
      position +
      Vector2(
        (aim.x < position.x ? -1 : 1) * kind.spriteSize * .41,
        -kind.spriteSize * .37,
      );

  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    final props = [position + side * 175, position - side * 175];
    if (sequence % 3 == 2 && targetDistance < 800) {
      return BossMove(
        'Furnace breath',
        1,
        [
          AttackCue(
            BossAttackShape.sweep(
              position,
              (targetDistance + 360).clamp(650.0, 1400.0),
              angle: atan2(forward.y, forward.x) - 1.25,
              arc: 2.5,
              innerRadius: 250,
              width: 40,
            ),
            warning: 1.2,
            active: 1.2,
          ),
        ],
        prop: BossPropKind.valve,
        propPositions: props,
        recovery: 2.0,
      );
    }
    if (sequence % 3 == 1) {
      return BossMove(
        'Foundry foot',
        0,
        [
          AttackCue(
            BossAttackShape.circle(aim, 180),
            warning: 1.05,
            active: .35,
            damage: 2,
          ),
          if (enraged)
            AttackCue(
              BossAttackShape.circle(safePoint(aim + side * 290), 155),
              delay: .8,
              warning: 1.05,
              active: .35,
              damage: 2,
            ),
        ],
        prop: BossPropKind.valve,
        propPositions: props,
        recovery: 1.7,
      );
    }
    return BossMove(
      'Pressure grid',
      2,
      [
        for (var i = 0; i < (enraged ? 3 : 2); i++)
          AttackCue(
            BossAttackShape.circle(
              safePoint(
                aim +
                    side *
                        (i == 0
                            ? 0
                            : i == 1
                            ? 300
                            : -300) +
                    forward * (i == 0 ? 0 : 220),
              ),
              150,
            ),
            delay: i * .45,
            warning: 1.05,
            active: 1.2,
          ),
      ],
      prop: BossPropKind.valve,
      propPositions: props,
      recovery: 1.8,
    );
  }
}

class LastMarshalBoss extends ExpansionBoss {
  LastMarshalBoss({super.position, required super.maximumHealth})
    : super(BossKind.marshal);
  @override
  Vector2 shotOrigin(Vector2 aim) {
    final point = MarshalAim.muzzle(
      position.toOffset(),
      aim.toOffset(),
      kind.spriteSize,
      target.x < position.x,
    );
    return Vector2(point.dx, point.dy);
  }

  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    if (sequence % 3 == 1) {
      return BossMove('Iron courtesy', 1, [], brace: true, recovery: 1.5);
    }
    if (sequence % 3 == 2) {
      final blade = safePoint(aim + forward * 350 + side * 170);
      return BossMove(
        'Return to sender',
        2,
        [
          AttackCue(
            BossAttackShape.line(path([position, blade]), width: 30),
            warning: 1.1,
            active: .2,
          ),
          AttackCue(
            BossAttackShape.sweep(
              position,
              430,
              angle: atan2(forward.y, forward.x) - 1.5,
              arc: 3.0,
              innerRadius: 180,
            ),
            delay: .8,
            warning: 1.0,
            active: .5,
          ),
          AttackCue(
            BossAttackShape.circle(blade, 140),
            delay: .8,
            warning: 1.0,
            active: .65,
          ),
          if (enraged)
            AttackCue(
              BossAttackShape.sweep(
                position,
                430,
                angle: atan2(forward.y, forward.x) + 1.5,
                arc: -3.0,
                innerRadius: 180,
              ),
              delay: 1.6,
              warning: 1.0,
              active: .5,
            ),
          AttackCue(
            BossAttackShape.line(path([blade, position]), width: 30),
            delay: 2.4,
            warning: 1.05,
            active: .3,
            damage: 2,
          ),
        ],
        prop: BossPropKind.blade,
        propPositions: [blade],
        recovery: 1.8,
      );
    }
    List<Vector2> shot(Vector2 point) {
      final source = shotOrigin(point);
      return path([source, point + (point - source).normalized() * 900]);
    }

    return BossMove('Measured fire', 0, [
      AttackCue(
        BossAttackShape.line(shot(aim), width: 24),
        warning: .9,
        active: .28,
      ),
      AttackCue(
        BossAttackShape.line(shot(aim + side * 140), width: 24),
        delay: .65,
        warning: .9,
        active: .28,
      ),
    ], recovery: 1.3);
  }
}

ExpansionBoss createExpansionBoss(
  BossKind kind,
  Vector2 position,
  double health,
) => switch (kind) {
  BossKind.bellkeeper => BellkeeperBoss(
    position: position,
    maximumHealth: health,
  ),
  BossKind.magistrate => MagistrateBoss(
    position: position,
    maximumHealth: health,
  ),
  BossKind.saint => throw ArgumentError('Retired boss'),
  BossKind.sovereign => KilnSovereignBoss(
    position: position,
    maximumHealth: health,
  ),
  BossKind.marshal => LastMarshalBoss(
    position: position,
    maximumHealth: health,
  ),
  _ => throw ArgumentError.value(kind),
};
