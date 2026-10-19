import 'dart:math';
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
  AttackCue(this.shape,
      {this.warning = 1.1, this.active = .35, this.delay = 0, this.damage = 1});
  final BossAttackShape shape;
  final double warning, active, delay;
  final int damage;
  double get end => delay + warning + active;
}

class BossMove {
  BossMove(this.name, this.pose, this.cues,
      {this.recovery = 1.5,
      this.brace = false,
      this.prop,
      this.propPositions = const []});
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
  final recentRoute = <Vector2>[];
  Vector2? projectionPosition;
  final _owned = <BossAttack>[];
  final _props = <BossWeakPoint>[];
  late SpriteAnimationComponent body;
  late SpriteAnimation _idle, _walk, _enragedIdle, _impact;
  final facing = Vector2(1, 0);
  double get targetDistance => position.distanceTo(game.myPlayer.position);
  Vector2 get target {
    final point = game.myPlayer.position +
        game.movementJoystick.relativeDelta * game.gameState.movementSpeed * .3;
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

  SpriteAnimation clip(List<int> frames, double duration,
          {bool loop = false}) =>
      SpriteAnimation.spriteList([
        for (final frame in frames)
          RegunArt.shared.sprite('bosses/${kind.name}', frame)
      ], stepTime: duration / frames.length, loop: loop);

  @override
  Future<void> onLoad() async {
    initializeHealth(maximumHealth);
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
    body = SpriteAnimationComponent(
        size: Vector2.all(kind == BossKind.sovereign ? 340 : 280),
        position:
            Vector2(100, 170 - .38 * (kind == BossKind.sovereign ? 340 : 280)),
        anchor: Anchor.center,
        animation: _idle);
    add(body);
    add(CircleHitbox(
        radius: 65,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive));
  }

  @override
  void onMount() {
    super.onMount();
    game.revision.value++;
  }

  @override
  void onRemove() {
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
        move.windup);
    final impact = move.pose == 2
        ? [27, 28, 29]
        : [start + 4, start + 5, start + 6, start + 7];
    _impact = clip(
        kind == BossKind.marshal && move.pose == 0 ? [11, 12, 13, 14] : impact,
        .48);
    phase = ExpansionPhase.warning;
    clock = 0;
    game.audio.play('boss_${kind.name}_warn.wav');
    for (final cue in move.cues) {
      final attack = BossAttack(
          shape: cue.shape,
          owner: combatHealth,
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
          });
      if (game.addBossAttack(attack)) _owned.add(attack);
    }
    if (move.prop != null) {
      for (final point in move.propPositions) {
        final prop = BossWeakPoint(
            owner: this,
            position: safePoint(point),
            kind: move.prop!,
            onBroken: interrupt,
            health: 5);
        _props.add(prop);
        game.world.add(prop);
      }
    }
    return true;
  }

  @override
  bool takeDamage(double amount) {
    final bracing = kind == BossKind.marshal &&
        currentMove?.brace == true &&
        [ExpansionPhase.warning, ExpansionPhase.active].contains(phase) &&
        incomingDirection != null &&
        !lastHitWasSecondary &&
        incomingDirection!.dot(facing) < -.55;
    if (bracing) {
      amount *= .25;
      if (!_countered) {
        _countered = true;
        final counter = BossAttack(
            owner: combatHealth,
            shape: BossAttackShape.line(path([position, target]), width: 12),
            warning: 1.05,
            active: .15,
            cause: 'Marshal counter',
            sound: 'boss_marshal_hit.wav');
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
          game.moveActor(this, (game.myPlayer.position - position).normalized(),
              kind == BossKind.sovereign ? 100 : 170, dt,
              radius: 75);
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
        if (clock >= .85 && beginMove()) clock = 0;
      case ExpansionPhase.warning:
        if (clock >= currentMove!.windup) {
          phase = ExpansionPhase.active;
          body.animation = _impact.clone();
          _impactUntil = clock + .5;
        }
      case ExpansionPhase.active:
        if (clock >= _impactUntil && body.animation?.loop == false) {
          body.animation = enraged ? _enragedIdle : _idle;
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = (size / 2).toOffset();
    canvas.drawOval(
        Rect.fromCenter(
            center: center + const Offset(0, 65), width: 150, height: 25),
        Paint()..color = const Color(0x660B090E));
    if (phase == ExpansionPhase.arrival ||
        (phase == ExpansionPhase.recovery && _interrupted)) {
      canvas.drawCircle(
          center,
          85,
          Paint()
            ..color = const Color(0xffE0C07C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    if (kind == BossKind.marshal &&
        currentMove?.brace == true &&
        [ExpansionPhase.warning, ExpansionPhase.active].contains(phase)) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: 80),
          atan2(facing.y, facing.x) - 1.1,
          2.2,
          false,
          Paint()
            ..color = const Color(0xffCAD5D5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6);
    }
    if (kind == BossKind.saint &&
        phase == ExpansionPhase.active &&
        currentMove?.pose == 2 &&
        projectionPosition != null) {
      final sprite = RegunArt.shared.sprite('bosses/saint', 0);
      final offset = projectionPosition! - position;
      sprite.render(canvas,
          position: size / 2 + offset,
          size: Vector2.all(220),
          anchor: Anchor.center,
          overridePaint: Paint()..color = const Color(0x66FFFFFF));
    }
  }
}

class BellkeeperBoss extends ExpansionBoss {
  BellkeeperBoss({super.position, required super.maximumHealth})
      : super(BossKind.bellkeeper);
  @override
  BossMove plan() {
    final delta = target - position, heading = atan2(delta.y, delta.x);
    if (targetDistance < 360 && sequence % 3 == 1) {
      return BossMove(
          'Clapper sentence',
          0,
          [
            AttackCue(
                BossAttackShape.sweep(position, 300,
                    angle: heading - 1.2, arc: 2.4),
                warning: 1.15,
                active: .8,
                damage: 2)
          ],
          recovery: 1.8,
          prop: BossPropKind.bell,
          propPositions: [position + Vector2(105, 35)]);
    }
    final reach = (delta.length + 260).clamp(500.0, 1150.0);
    return BossMove(
        'Broken toll',
        1,
        [
          AttackCue(BossAttackShape.ring(position, reach, angle: heading + .7),
              warning: 1.15, active: 2.0),
          if (enraged || sequence > 0)
            AttackCue(
                BossAttackShape.ring(position, reach, angle: heading - .7),
                delay: 2.25,
                warning: 1.1,
                active: 1.8),
        ],
        recovery: 2.0,
        prop: BossPropKind.bell,
        propPositions: [position + Vector2(105, 35)]);
  }
}

class MagistrateBoss extends ExpansionBoss {
  MagistrateBoss({super.position, required super.maximumHealth})
      : super(BossKind.magistrate);
  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    final a = safePoint(aim + side * 210), b = safePoint(aim - side * 210);
    if (sequence % 3 == 1) {
      return BossMove(
          'Draw the line',
          1,
          [
            AttackCue(
                BossAttackShape.sweep(
                    position, (targetDistance + 140).clamp(350.0, 900.0),
                    angle: atan2(forward.y, forward.x) - .9, arc: 1.8),
                warning: 1.2,
                active: 1.25,
                damage: 2)
          ],
          prop: BossPropKind.clasp,
          propPositions: [a, b],
          recovery: 1.8);
    }
    final crossed = sequence % 3 == 2;
    return BossMove(
        crossed ? 'Cross examination' : 'Writ of iron',
        crossed ? 2 : 0,
        [
          AttackCue(
              BossAttackShape.line(
                  path([crossed ? a - forward * 180 : position, b]),
                  width: 18),
              warning: 1.2,
              active: .45),
          AttackCue(
              BossAttackShape.line(
                  path([crossed ? b - forward * 180 : position, a]),
                  width: 18),
              delay: .85,
              warning: 1.1,
              active: .45),
          if (enraged)
            AttackCue(
                BossAttackShape.circle(safePoint(aim + forward * 160), 100),
                delay: 1.7,
                warning: 1.0,
                active: .3),
        ],
        prop: BossPropKind.clasp,
        propPositions: [a, b],
        recovery: 1.6);
  }
}

class MirrorSaintBoss extends ExpansionBoss {
  MirrorSaintBoss({super.position, required super.maximumHealth})
      : super(BossKind.saint);
  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    final route = recentRoute.length >= 2
        ? recentRoute.map((p) => p.clone()).toList()
        : [aim - side * 160, aim, aim + side * 160];
    if (sequence % 3 == 0) {
      return BossMove(
          'Recorded escape',
          0,
          [
            AttackCue(BossAttackShape.trace(path(route)),
                warning: 1.15, active: 1.25)
          ],
          recovery: 1.6);
    }
    final mirror = safePoint(position + side * 250);
    if (sequence % 3 == 2) {
      projectionPosition = safePoint(position + side * 300);
      return BossMove(
          'False benediction',
          2,
          [
            AttackCue(
                BossAttackShape.line(
                    path([projectionPosition!, aim + forward * 200]),
                    width: 16),
                warning: 1.2,
                active: .35),
            if (enraged)
              AttackCue(BossAttackShape.trace(path(route)),
                  delay: 1.4, warning: 1.1, active: 1.1),
          ],
          prop: BossPropKind.mirror,
          propPositions: [mirror],
          recovery: 1.8);
    }
    return BossMove(
        'Split light',
        1,
        [
          AttackCue(
              BossAttackShape.line(
                  path([position, mirror, aim + forward * 240]),
                  width: 16),
              warning: 1.2,
              active: .6),
          if (enraged)
            AttackCue(BossAttackShape.trace(path(route)),
                delay: 1.6, warning: 1.1, active: 1.1),
        ],
        prop: BossPropKind.mirror,
        propPositions: [mirror],
        recovery: 1.8);
  }
}

class KilnSovereignBoss extends ExpansionBoss {
  KilnSovereignBoss({super.position, required super.maximumHealth})
      : super(BossKind.sovereign);
  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    final props = [position + side * 175, position - side * 175];
    if (sequence % 3 == 2) {
      return BossMove(
          'Furnace breath',
          1,
          [
            AttackCue(
                BossAttackShape.sweep(
                    position, (targetDistance + 220).clamp(450.0, 950.0),
                    angle: atan2(forward.y, forward.x) - .8,
                    arc: 1.6,
                    width: 28),
                warning: 1.25,
                active: 1.8)
          ],
          prop: BossPropKind.valve,
          propPositions: props,
          recovery: 2.0);
    }
    if (sequence % 3 == 1) {
      return BossMove(
          'Foundry foot',
          0,
          [
            AttackCue(BossAttackShape.circle(aim, 130),
                warning: 1.1, active: .35, damage: 2),
            if (enraged)
              AttackCue(
                  BossAttackShape.circle(safePoint(aim + side * 190), 110),
                  delay: .8,
                  warning: 1.1,
                  active: .35,
                  damage: 2)
          ],
          prop: BossPropKind.valve,
          propPositions: props,
          recovery: 1.7);
    }
    return BossMove(
        'Pressure grid',
        2,
        [
          for (var i = 0; i < (enraged ? 3 : 2); i++)
            AttackCue(
                BossAttackShape.circle(
                    safePoint(aim +
                        side * ((i - 1) * 200) +
                        forward * (i == 1 ? 140 : 0)),
                    105),
                delay: i * .5,
                warning: 1.2,
                active: 1.2),
        ],
        prop: BossPropKind.valve,
        propPositions: props,
        recovery: 1.8);
  }
}

class LastMarshalBoss extends ExpansionBoss {
  LastMarshalBoss({super.position, required super.maximumHealth})
      : super(BossKind.marshal);
  @override
  BossMove plan() {
    final aim = target, forward = (aim - position).normalized();
    final side = Vector2(-forward.y, forward.x);
    if (sequence % 3 == 1) {
      return BossMove('Iron courtesy', 1, [], brace: true, recovery: 1.5);
    }
    if (sequence % 3 == 2) {
      final blade = safePoint(aim + side * 150);
      return BossMove(
          'Return to sender',
          2,
          [
            AttackCue(BossAttackShape.line(path([position, blade]), width: 18),
                warning: 1.1, active: .2),
            AttackCue(
                BossAttackShape.sweep(position, 230,
                    angle: atan2(forward.y, forward.x) - 1.0, arc: 2.0),
                delay: .8,
                warning: 1.0,
                active: .5),
            if (enraged)
              AttackCue(
                  BossAttackShape.sweep(position, 230,
                      angle: atan2(forward.y, forward.x) + 1.0, arc: -2.0),
                  delay: 1.6,
                  warning: 1.0,
                  active: .5),
            AttackCue(BossAttackShape.line(path([blade, position]), width: 20),
                delay: 2.4, warning: 1.05, active: .3, damage: 2),
          ],
          prop: BossPropKind.blade,
          propPositions: [blade],
          recovery: 1.8);
    }
    return BossMove(
        'Measured fire',
        0,
        [
          AttackCue(
              BossAttackShape.line(path([position, aim + forward * 260]),
                  width: 10),
              warning: 1.0,
              active: .16),
          AttackCue(
              BossAttackShape.line(
                  path([position, aim + forward * 260 + side * 80]),
                  width: 10),
              delay: .65,
              warning: 1.0,
              active: .16),
        ],
        recovery: 2.2);
  }
}

ExpansionBoss createExpansionBoss(
        BossKind kind, Vector2 position, double health) =>
    switch (kind) {
      BossKind.bellkeeper =>
        BellkeeperBoss(position: position, maximumHealth: health),
      BossKind.magistrate =>
        MagistrateBoss(position: position, maximumHealth: health),
      BossKind.saint =>
        MirrorSaintBoss(position: position, maximumHealth: health),
      BossKind.sovereign =>
        KilnSovereignBoss(position: position, maximumHealth: health),
      BossKind.marshal =>
        LastMarshalBoss(position: position, maximumHealth: health),
      _ => throw ArgumentError.value(kind),
    };
