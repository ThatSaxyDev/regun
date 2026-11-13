import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';

enum LodestarMove { bite, shards, mortars, mines, tail, burrow }

enum LodestarPhase {
  arrival,
  travel,
  warning,
  firing,
  recovery,
  entry,
  underground,
  exitWarning,
  emerging,
  destruction,
  finished,
}

class LodestarShot {
  LodestarShot(
    this.from,
    this.target,
    this.sequence, {
    this.shell = false,
    this.speed = 640,
  });
  final Offset from, target;
  final int sequence;
  final bool shell;
  final double speed;
  double age = 0;
  Offset position = Offset.zero;
  bool removed = false;
  double get duration => shell ? 1.15 : 760 / speed;
  Offset get direction => (target - from) / (target - from).distance;
}

class LodestarMine {
  LodestarMine(this.from, this.landing, this.sequence);
  final Offset from;
  Offset landing;
  final int sequence;
  double age = 0, trigger = -1;
  bool removed = false;
  bool get flying => age < .8;
  bool get armed => age >= 1.5 && trigger < 0;
  Offset get position =>
      flying ? Offset.lerp(from, landing, age / .8)! : landing;
}

class LodestarBurst {
  LodestarBurst(
    this.position,
    this.radius, {
    this.blast = true,
    this.excavation = false,
  });
  final Offset position;
  final double radius;
  final bool blast, excavation;
  double age = 0;
}

/// One active-clock encounter; warning geometry, flights and section ownership
/// are shared by the native renderer, damage adapter and deterministic tests.
class LodestarCombat {
  LodestarCombat({
    required this.rig,
    required this.bounds,
    required this.clear,
    this.recoveryClear,
    required this.hurt,
    required this.signal,
    required this.poseLegal,
    bool Function(Offset)? visible,
  }) : visible = visible ?? ((_) => true) {
    entry = rig.poses.first.socket(const Offset(120, 0));
  }
  LodestarRig rig;
  final Rect bounds;
  final bool Function(Offset a, Offset b, double radius) clear;
  final bool Function(Offset a, Offset b, double radius)? recoveryClear;
  final bool Function(List<LodestarPose>) poseLegal;
  final bool Function(int damage, String cause) hurt;
  final void Function(String cue) signal;
  final bool Function(Offset) visible;
  final sections = LodestarSections();
  LodestarPhase phase = LodestarPhase.arrival;
  LodestarMove move = LodestarMove.shards;
  LodestarMove? forcedMove;
  Offset player = Offset.zero, playerVelocity = Offset.zero;
  Offset aim = Offset.zero, entry = Offset.zero, exit = Offset.zero;
  double elapsed = 0, age = 0, _remainder = 0, _contactGate = 0, _quiet = 0;
  double shardYaw = 0;
  double course = 0, _startTravel = 0, _planClock = 0, _reverseFor = 0;
  int _sequence = 0, _released = 0, _turn = 0;
  bool _eruptionDamage = true, paused = false;
  bool _withdraw = false, _deathSinking = false;
  Offset _deathMouth = Offset.zero;
  double _stalled = 0, _surfaceStall = 0;
  bool _repositioning = false;
  final depths = List<double>.filled(6, 1);
  final shots = <LodestarShot>[],
      mines = <LodestarMine>[],
      bursts = <LodestarBurst>[];
  final warnedSweep = <TargetCapsule>[];
  final _accepted = <int>{};
  final _cooldown = <LodestarMove, double>{};
  final hits = <LodestarSection, double>{};
  final releases = <LodestarMove, int>{};
  double coreOpenedAt = -1000;
  static const shutdownDuration = 4.4;
  static const terminalExplosionAt = 1.65;
  final releasedAt = <LodestarMove, double>{};
  double weaponKick(LodestarMove m) =>
      (1 - (elapsed - (releasedAt[m] ?? -1000)) / .16).clamp(0, 1);
  bool muzzleLit(LodestarMove m) => elapsed - (releasedAt[m] ?? -1000) < .09;
  double get attackSpeed =>
      move == LodestarMove.bite || move == LodestarMove.tail
      ? 180
      : move == LodestarMove.burrow
      ? 0
      : 80;
  final _shutdownParts = List<bool>.filled(6, false);
  bool shutdownIntact(LodestarSection s) => _shutdownParts[s.index];
  double collapse(LodestarSection s) =>
      defeated ? ((age - s.index * .22) / .45).clamp(0, 1) : 0;
  double get wreckOpacity =>
      defeated ? ((shutdownDuration - age) / 1).clamp(0, 1) : 1;
  final _mortarAt = [-1000.0, -1000.0];
  double get mortarElevation =>
      move == LodestarMove.mortars && phase == LodestarPhase.warning
      ? .2 + .25 * (age / .9).clamp(0, 1)
      : .45;
  void restoreMortarRecoil(List<double> values) => _mortarAt.setAll(0, values);
  double mortarRecoil(int tube) =>
      9 * (1 - (elapsed - _mortarAt[tube]) / .16).clamp(0, 1);
  Offset mortarSocket(int tube) {
    final p = rig.poses[2], yaw = heading(aim - p.position);
    return p.position +
        unit(yaw) * 41 * math.cos(mortarElevation) +
        unit(yaw + math.pi / 2) * (tube == 0 ? -20.0 : 20.0) -
        Offset(0, math.sin(mortarElevation) * 14);
  }

  double get feederProgress =>
      sections.living(LodestarSection.mortars) &&
          move == LodestarMove.mortars &&
          [LodestarPhase.warning, LodestarPhase.firing].contains(phase)
      ? phase == LodestarPhase.warning
            ? (age / .9).clamp(0, 1)
            : (age % .35) / .35
      : 0;
  bool get defeated =>
      phase == LodestarPhase.destruction || phase == LodestarPhase.finished;
  bool get finished => phase == LodestarPhase.finished;
  bool get enraged => sections.fraction <= .5;
  bool exposed(LodestarSection s) =>
      !defeated &&
      depths[s.index] < 1 &&
      sections.living(s) &&
      partShapes(rig.poses[s.index]).isNotEmpty;
  bool get vulnerable => phase != LodestarPhase.arrival && !defeated;
  String get label => defeated
      ? 'SHUTTING DOWN'
      : '${sections.coreExposed ? "CORE EXPOSED" : "ARMOR ${sections.brokenWeapons}/2"} · $_actionLabel';
  String get _actionLabel => defeated
      ? 'SHUTTING DOWN'
      : switch (phase) {
          LodestarPhase.arrival => 'DEPLOYING',
          LodestarPhase.entry || LodestarPhase.underground => 'BORING',
          LodestarPhase.exitWarning || LodestarPhase.emerging => 'BREAKTHROUGH',
          LodestarPhase.recovery => 'RELOADING',
          _ => switch (move) {
            LodestarMove.bite => 'CUTTING JAWS',
            LodestarMove.shards => 'SHARD ACCELERATOR',
            LodestarMove.mortars => 'SIEGE MORTARS',
            LodestarMove.mines => 'MINE PROJECTOR',
            LodestarMove.tail => 'ARMORED TAIL',
            _ => 'MANEUVERING',
          },
        };
  static Offset unit(double a) => Offset(math.cos(a), math.sin(a));
  static double heading(Offset d) => math.atan2(d.dy, d.dx);
  static Offset limit(Offset d, double n) =>
      d.distance > n ? d * n / d.distance : d;
  LodestarSection owner(LodestarMove m) => switch (m) {
    LodestarMove.bite || LodestarMove.burrow => LodestarSection.head,
    LodestarMove.shards => LodestarSection.accelerator,
    LodestarMove.mortars => LodestarSection.mortars,
    LodestarMove.mines => LodestarSection.mines,
    LodestarMove.tail => LodestarSection.tail,
  };
  double warning(LodestarMove m) => switch (m) {
    LodestarMove.bite || LodestarMove.burrow => .8,
    LodestarMove.tail => .85,
    _ => .9,
  };
  void _phase(LodestarPhase p) {
    phase = p;
    age = 0;
  }

  List<TargetCapsule> shapes(
    List<LodestarPose> poses, {
    bool targets = false,
  }) => [
    for (final p in poses)
      if (targets ? exposed(p.section) : depths[p.section.index] < 1)
        ...partShapes(p),
    if (!targets)
      for (var i = 0; i < 5; i++)
        if (depths[i] < 1 && depths[i + 1] < 1)
          depths[i] > 0 || depths[i + 1] > 0
              ? ClippedTargetCapsule(
                  poses[i].rear,
                  poses[i + 1].front,
                  8,
                  origin: mouth,
                  normal: unit(course) * (sinking ? 1.0 : -1.0),
                  limit: 0,
                )
              : TargetCapsule(poses[i].rear, poses[i + 1].front, 8),
  ];
  bool get sinking =>
      defeated ? _deathSinking : phase == LodestarPhase.entry || _withdraw;
  double maskCut(double depth) =>
      (sinking ? 1 - 2 * depth : 2 * depth - 1) * 120;
  Iterable<TargetCapsule> partShapes(LodestarPose p) sync* {
    final depth = depths[p.section.index];
    if (depth >= 1) return;
    final full = <TargetCapsule>[
      p.footprint(broken: !sections.living(p.section)),
      if (sections.living(p.section) && p.section == LodestarSection.head)
        TargetCapsule(p.position, p.socket(const Offset(70, 0)), 38),
      if (sections.living(p.section) && p.section == LodestarSection.tail)
        TargetCapsule(p.position, p.socket(const Offset(-85, 0)), 24),
    ];
    for (final shape in full) {
      if (depth <= 0) {
        yield shape;
        continue;
      }
      final normal = unit(course) * (sinking ? 1.0 : -1.0), cut = 0.0;
      double projection(Offset q) =>
          (q - mouth).dx * normal.dx + (q - mouth).dy * normal.dy;
      if (math.min(projection(shape.a), projection(shape.b)) - shape.radius >
          cut) {
        continue;
      }
      yield ClippedTargetCapsule(
        shape.a,
        shape.b,
        shape.radius,
        origin: mouth,
        normal: normal,
        limit: cut,
      );
    }
  }

  void advance(double dt) {
    if (paused || !dt.isFinite || dt <= 0) return;
    _remainder += math.min(dt, .25);
    while (_remainder + 1e-10 >= LodestarRig.tick) {
      _remainder -= LodestarRig.tick;
      _step();
    }
  }

  void _step() {
    const dt = LodestarRig.tick;
    elapsed += dt;
    age += dt;
    _contactGate = math.max(0, _contactGate - dt);
    for (final key in _cooldown.keys.toList()) {
      _cooldown[key] = math.max(0, _cooldown[key]! - dt);
    }
    for (final b in bursts) {
      b.age += dt;
    }
    bursts.removeWhere((b) => b.age > 1.1);
    if (defeated) {
      rig.requestedSpeed = 0;
      rig.tailCurl = 0;
      rig.advance(dt);
      for (final s in LodestarSection.values) {
        final start = s.index * .22;
        if (age - dt <= start && age >= start && depths[s.index] < 1) {
          _burst(rig.poses[s.index].position, 72);
          if (s.index > 0) signal('supply_break.wav');
        }
      }
      if (age - dt < terminalExplosionAt && age >= terminalExplosionAt) {
        final head = rig.poses.first.position;
        final mouth =
            exit != Offset.zero &&
                (head - exit).distance < (head - entry).distance
            ? exit
            : entry;
        _burst(depths.first > .7 ? mouth : head, 205);
        for (final i in [2, 4]) {
          if (depths[i] < .7) _burst(rig.poses[i].position, 150);
        }
        signal('blast.wav');
      }
      if (age >= shutdownDuration) _phase(LodestarPhase.finished);
      return;
    }
    _flights(dt);
    final old = rig.poses;
    if (phase == LodestarPhase.arrival) {
      rig.requestedSpeed = 260;
      rig.desiredHeading = course;
      rig.advance(dt);
      _depth(false);
      if (age >= 3.2) {
        depths.fillRange(0, 6, 0);
        _phase(LodestarPhase.travel);
      }
      return;
    }
    if (phase == LodestarPhase.underground) {
      if (age >= .15) {
        _chooseExit();
        _phase(LodestarPhase.exitWarning);
      }
      return;
    }
    if (phase == LodestarPhase.exitWarning) {
      if (age >= .95) {
        final proposed = LodestarRig(
          head: exit - unit(course) * 120,
          heading: course,
        );
        final safeExit = _repositioning
            ? _recoveryLaneClear(exit, course)
            : proposed.poses.every((p) => clear(p.position, p.position, 110)) &&
                  clear(
                    exit - unit(course) * 760,
                    exit + unit(course) * 760,
                    110,
                  );
        if (!safeExit) {
          if (_repositioning) {
            // A new blocker can enter after warning. Commit a new safe warning
            // before emerging, instead of reusing the original blocked route.
            _recoveryExit();
            _phase(LodestarPhase.exitWarning);
            return;
          }
          exit = entry;
          course = rig.poses.first.yaw;
          _eruptionDamage = false;
        }
        rig = LodestarRig(
          head: exit - unit(course) * 120,
          heading: course,
          acceptPose: rig.acceptPose,
        );
        rig.maximumSpeed = 480;
        rig.primeSpeed(480);
        _startTravel = rig.signedTravel;
        _stalled = 0;
        depths.fillRange(0, 6, 1);
        signal('supply_land.wav');
        _burst(exit, 150, blast: false, excavation: true);
        if (_eruptionDamage &&
            (player - exit).distance < 150 + 26 &&
            clear(exit, player, 0)) {
          _hit(_sequence, 'Lodestar eruption');
        }
        _phase(LodestarPhase.emerging);
      }
      return;
    }
    if (phase == LodestarPhase.entry || phase == LodestarPhase.emerging) {
      rig.maximumSpeed = 480;
      rig.requestedSpeed = 480;
      rig.desiredHeading = course;
      final beforeTravel = rig.signedTravel;
      if (_withdraw) rig.requestedSpeed = -180;
      rig.advance(dt);
      _stalled = (rig.signedTravel - beforeTravel).abs() < .01
          ? _stalled + dt
          : 0;
      _depth(phase == LodestarPhase.entry || _withdraw);
      if (_withdraw && rig.signedTravel <= _startTravel + .5) {
        depths.fillRange(0, 6, 0);
        _withdraw = false;
        _cooldown[LodestarMove.burrow] = 18;
        _recover();
        return;
      }
      if (!_withdraw && phase == LodestarPhase.entry && _stalled > .35) {
        _safeWithdrawal();
        return;
      }
      if (_stalled > 1 && _beginWallRecovery()) return;
      if (!_withdraw && rig.signedTravel - _startTravel >= 760) {
        if (phase == LodestarPhase.entry) {
          depths.fillRange(0, 6, 1);
          _phase(LodestarPhase.underground);
        } else {
          depths.fillRange(0, 6, 0);
          _cooldown[LodestarMove.burrow] = 18;
          _repositioning = false;
          _recover();
        }
      }
      if (phase != LodestarPhase.entry || _eruptionDamage) _contact(old);
      return;
    }
    if ((phase == LodestarPhase.warning || phase == LodestarPhase.firing) &&
        !sections.living(owner(move))) {
      warnedSweep.clear();
      _recover();
    }
    if (phase == LodestarPhase.travel || phase == LodestarPhase.recovery) {
      _navigate(dt);
    } else if (move == LodestarMove.shards ||
        move == LodestarMove.mortars ||
        move == LodestarMove.mines) {
      _navigate(dt, speed: 280);
    } else {
      rig.requestedSpeed = attackSpeed;
      rig.desiredHeading = course;
    }
    if (move == LodestarMove.tail && phase == LodestarPhase.firing) {
      rig.tailCurl = .28 * math.cos(math.pi * (age / .5).clamp(0, 1));
    } else if (move == LodestarMove.tail && phase == LodestarPhase.warning) {
      rig.tailCurl = .28 * (age / .85).clamp(0, 1);
    } else {
      rig.tailCurl = 0;
    }
    final beforeTravel = rig.signedTravel;
    rig.advance(dt);
    _surfaceStall = (rig.signedTravel - beforeTravel).abs() < .01
        ? _surfaceStall + dt
        : 0;
    if (_surfaceStall > 1.2 && _beginWallRecovery()) return;
    _contact(old);
    if (phase == LodestarPhase.recovery) {
      if (!shots.any((s) => s.shell) &&
          !mines.any((m) => m.trigger >= 0 && !m.removed)) {
        _quiet += dt;
      } else {
        _quiet = 0;
      }
      if (_quiet >= (enraged ? .4 : .55)) {
        _phase(LodestarPhase.travel);
      }
      return;
    }
    if (phase == LodestarPhase.travel) {
      if (age > .25) {
        _select();
      }
      return;
    }
    if (phase == LodestarPhase.warning) {
      if (move == LodestarMove.shards && age < .65) {
        aim = player + limit(playerVelocity * .25, 90);
        shardYaw = heading(aim - rig.poses[1].position);
      }
      if (age >= warning(move)) {
        if (move == LodestarMove.burrow) {
          entry = rig.poses.first.socket(const Offset(120, 0));
          _startTravel = rig.signedTravel;
          _eruptionDamage = true;
          _withdraw = false;
          _stalled = 0;
          _phase(LodestarPhase.entry);
        } else {
          _phase(LodestarPhase.firing);
          _released = 0;
        }
      }
      return;
    }
    if (phase == LodestarPhase.firing) {
      _release();
    }
  }

  Offset get mouth => defeated
      ? _deathMouth
      : phase == LodestarPhase.arrival || sinking
      ? entry
      : exit;
  double mouthProjection(Offset p) {
    final d = p - mouth, axis = unit(course);
    return d.dx * axis.dx + d.dy * axis.dy;
  }

  void _depth(bool sinking) {
    for (final p in rig.poses) {
      final projection = mouthProjection(p.position);
      depths[p.section.index] =
          ((sinking ? projection + 120 : 120 - projection) / 240).clamp(0, 1);
    }
  }

  void _safeWithdrawal() {
    _eruptionDamage = false;
    _withdraw = true;
    _stalled = 0;
    _phase(LodestarPhase.emerging);
  }

  void _recover() {
    _quiet = 0;
    warnedSweep.clear();
    _phase(LodestarPhase.recovery);
  }

  void _navigate(double dt, {double? speed}) {
    rig.maximumSpeed = enraged ? 340 : 310;
    rig.requestedSpeed = speed ?? rig.maximumSpeed;
    if (_reverseFor > 0) {
      final reverse = rig.copy()..requestedSpeed = -180;
      reverse.advance(.1);
      if (reverse.rejectedSteps == 0) {
        _reverseFor -= dt;
        rig.requestedSpeed = -180;
        return;
      }
      // A trailing carriage can already be beside a cover corner. Do not spend
      // two seconds trying the same blocked reverse while forward space is free.
      _reverseFor = 0;
      _planClock = 0;
    }
    _planClock -= dt;
    if (_planClock > 0) return;
    _planClock = .15;
    final head = rig.poses.first;
    final radial = head.position - player;
    final lead = limit(playerVelocity * .55, 160);
    final flank = unit(heading(radial) + math.pi / 2) * 190;
    final goal = radial.distance > 430
        ? player + lead + flank
        : player + unit(heading(radial) + .6) * 260;
    final desired = heading(goal - head.position);
    var score = double.infinity;
    double? best;
    for (final offset in [0.0, .45, -.45, .9, -.9, 1.5, -1.5, math.pi]) {
      final candidate = desired + offset;
      var probe = rig.copy()
        ..desiredHeading = candidate
        ..requestedSpeed = rig.requestedSpeed;
      final before = probe.signedTravel;
      probe.advance(.1);
      if (probe.rejectedSteps > 0) continue;
      probe = probe.copy(validate: false);
      var legal = true;
      for (var t = 0; t < 14; t++) {
        probe.advance(1 / 15);
        if (probe.rejectedSteps > 0 || !poseLegal(probe.poses)) {
          legal = false;
          break;
        }
      }
      if (!legal || probe.signedTravel - before < 80) continue;
      final p = probe.poses.first.position;
      final value =
          (p - goal).distance +
          LodestarRig.difference(candidate, head.yaw).abs() * 35;
      if (value < score) {
        score = value;
        best = candidate;
        break;
      }
    }
    if (best != null) {
      rig.desiredHeading = best;
    } else {
      // Bounded swept forward progress clears a tight corner before asking for
      // another long route. Every body and coupling still has to fit.
      for (final turn in [0.0, .6, -.6, 1.2, -1.2]) {
        final probe = rig.copy()
          ..desiredHeading = head.yaw + turn
          ..requestedSpeed = 180;
        final start = probe.signedTravel;
        probe.advance(.25);
        if (probe.rejectedSteps == 0 && probe.signedTravel - start > 12) {
          rig.desiredHeading = head.yaw + turn;
          rig.requestedSpeed = 180;
          return;
        }
      }
      final reverse = rig.copy()..requestedSpeed = -180;
      final start = reverse.signedTravel;
      reverse.advance(.2);
      if (reverse.rejectedSteps == 0 && reverse.signedTravel < start - 6) {
        _reverseFor = 1.0;
        rig.requestedSpeed = -180;
      } else {
        rig.requestedSpeed = 0;
      }
      rig.desiredHeading = head.yaw;
    }
  }

  bool _beginWallRecovery() {
    if (!_recoveryExit()) {
      // Keep retry costs bounded if the player and cover block every corridor.
      _surfaceStall = 1.0;
      _stalled = .8;
      return false;
    }
    _surfaceStall = _stalled = 0;
    _reverseFor = _planClock = 0;
    _withdraw = false;
    _repositioning = true;
    _eruptionDamage = false;
    warnedSweep.clear();
    for (final pose in rig.poses) {
      if (depths[pose.section.index] < .7) {
        _burst(pose.position, 72, blast: false, excavation: true);
      }
    }
    depths.fillRange(0, 6, 1);
    move = LodestarMove.burrow;
    _phase(LodestarPhase.exitWarning);
    signal('supply_incoming.wav');
    return true;
  }

  bool _recoveryExit() {
    for (final y in [.5, .26, .74, .38, .62, .14, .86]) {
      for (final x in [.5, .26, .74, .38, .62, .14, .86]) {
        final at = Offset(
          bounds.left + bounds.width * x,
          bounds.top + bounds.height * y,
        );
        for (var direction = 0; direction < 16; direction++) {
          final angle = direction * math.pi / 8;
          if (!_recoveryLaneClear(at, angle)) {
            continue;
          }
          exit = at;
          course = angle;
          return true;
        }
      }
    }
    return false;
  }

  bool _recoveryLaneClear(Offset at, double angle) {
    final axis = unit(angle);
    // The straight emergence starts 120 units behind the opening and advances
    // 760. Include the last car's tail at the start and the nose at the end.
    final start = at - axis * (120 + 5 * LodestarRig.spacing + 85);
    final end = at + axis * (760 - 120 + 70 + 4);
    return TargetCapsule.distanceToSegment(player, start, end) >= 180 &&
        (recoveryClear ?? clear)(start, end, 55);
  }

  bool _stage(LodestarMove next) {
    final section = owner(next), pose = rig.poses[section.index];
    if (!sections.living(section) ||
        (_cooldown[next] ?? 0) > 0 ||
        !visible(pose.position)) {
      return false;
    }
    if (next == LodestarMove.bite &&
        (rig.poses.first.position - player).distance > 400) {
      return false;
    }
    if (next == LodestarMove.tail &&
        (rig.poses.last.position - player).distance > 470) {
      return false;
    }
    if (next == LodestarMove.mines && mines.length >= 2) return false;
    if (next == LodestarMove.burrow &&
        mines.any((m) => (m.landing - player).distance < 300)) {
      return false;
    }
    if (next == LodestarMove.shards && shots.length + 10 > 20) return false;
    if (next == LodestarMove.mortars &&
        shots.length + sections.mortarSalvo > 20) {
      return false;
    }
    move = next;
    course = rig.poses.first.yaw;
    _sequence++;
    _released = 0;
    aim = player + limit(playerVelocity * .45, 140);
    shardYaw = heading(aim - rig.poses[1].position);
    warnedSweep.clear();
    if (next == LodestarMove.bite || next == LodestarMove.tail) {
      final probe = rig.copy()
        ..requestedSpeed = 180
        ..desiredHeading = course;
      var legal = true;
      for (var i = 0; i < 180; i++) {
        final t = i / 120;
        if (next == LodestarMove.tail) {
          probe.tailCurl = t < .85
              ? .28 * t / .85
              : .28 * math.cos(math.pi * ((t - .85) / .5).clamp(0, 1));
        }
        probe.advance(1 / 120);
        if (probe.rejectedSteps > 0) {
          legal = false;
          break;
        }
        if (t < warning(next) || i % 8 != 0) continue;
        if (next == LodestarMove.bite) {
          final p = probe.poses.first;
          warnedSweep.add(
            TargetCapsule(p.front, p.socket(const Offset(110, 0)), 40),
          );
        } else {
          for (final p in probe.poses.skip(4)) {
            warnedSweep.addAll(partShapes(p));
          }
        }
      }
      if (!legal || !_escape(warnedSweep, warning(next))) return false;
      if (next == LodestarMove.bite &&
          warnedSweep.every(
            (s) =>
                s.distance(
                  player + limit(playerVelocity * warning(next), 260),
                ) >
                110,
          )) {
        return false;
      }
    }
    if (next == LodestarMove.shards) {
      final from = rig.poses[1].position + unit(shardYaw) * 65;
      if ((aim - from).distance > 700 ||
          !_ownClear(from, aim, section) ||
          !_escape([
            for (var n = 0; n < 5; n++)
              TargetCapsule(
                from,
                from + unit(shardYaw + (n - 2) * .13) * 760,
                6,
              ),
          ], .9)) {
        return false;
      }
    }
    _phase(LodestarPhase.warning);
    signal(
      next == LodestarMove.burrow
          ? 'supply_incoming.wav'
          : 'reload_carbine_1.wav',
    );
    return true;
  }

  bool stage(LodestarMove next) => !defeated && _stage(next);
  void _select() {
    if (forcedMove case final selected?) {
      if (_stage(selected)) return;
    }
    const values = [
      LodestarMove.mortars,
      LodestarMove.shards,
      LodestarMove.mines,
      LodestarMove.bite,
      LodestarMove.tail,
      LodestarMove.burrow,
    ];
    for (var i = 0; i < values.length; i++) {
      final next = values[_turn++ % values.length];
      if (next == LodestarMove.burrow &&
          elapsed < 12 &&
          releases.values.fold<int>(0, (a, b) => a + b) < 2) {
        continue;
      }
      if (_stage(next)) return;
    }
    age = 0;
  }

  bool _escape(List<TargetCapsule> hazards, double warning) {
    // Walking-only connected candidates, including current structure and cover.
    final queue = <Offset>[player];
    final distances = <double>[0];
    final seen = <(int, int)>{(0, 0)};
    final budget = 300 * warning * .85;
    for (var i = 0; i < queue.length && i < 180; i++) {
      final p = queue[i];
      if (hazards.every((s) => s.distance(p) > 32) &&
          mines.every((m) => m.removed || (m.landing - p).distance > 177)) {
        return true;
      }
      for (final d in [
        const Offset(45, 0),
        const Offset(-45, 0),
        const Offset(0, 45),
        const Offset(0, -45),
      ]) {
        final n = p + d,
            key = (
              ((n - player).dx / 45).round(),
              ((n - player).dy / 45).round(),
            );
        if (distances[i] + 45 > budget || !seen.add(key) || !clear(p, n, 30)) {
          continue;
        }
        if (shapes(rig.poses).any((s) => s.distance(n) < 30)) continue;
        queue.add(n);
        distances.add(distances[i] + 45);
      }
    }
    return false;
  }

  void _release() {
    final p = rig.poses[owner(move).index];
    // A visible, committed wind-up owns its release. Slow mounted fire keeps
    // the mechanism nearby; crossing the viewport edge does not erase the shot.
    switch (move) {
      case LodestarMove.shards:
        if (_released < 2 && age >= _released * .22) {
          final yaw = shardYaw, from = p.position + unit(yaw) * 65;
          if (!_ownClear(from, aim, owner(move)) ||
              !clear(from, from + unit(yaw) * 110, 6)) {
            _recover();
            return;
          }
          if (shots.length + 5 > 20) return;
          for (var i = 0; i < 5; i++) {
            final a = yaw + (i - 2) * .13;
            shots.add(
              LodestarShot(from, from + unit(a) * 760, _sequence)
                ..position = from,
            );
          }
          _released++;
          _noteRelease();
          signal('sentry_fire.wav');
        }
        if (age > .45) _finish(4.2);
      case LodestarMove.mortars:
        final count = sections.mortarSalvo;
        final fallback = sections.living(LodestarSection.feeder) ? 0.0 : .6;
        if (_released < count && age >= fallback + _released * .35) {
          aim = player + limit(playerVelocity * 1.15, 280);
          final tube = _released.isEven ? 0 : 1, from = mortarSocket(tube);
          var target =
              aim + unit(course + math.pi / 2) * ((_released - 1) * 75.0);
          final safe = bounds.deflate(112);
          target = Offset(
            target.dx.clamp(safe.left, safe.right),
            target.dy.clamp(safe.top, safe.bottom),
          );
          if (!clear(from, target, 5)) {
            for (final t in [.75, .5, .25, 0.0]) {
              final candidate = Offset.lerp(player, target, t)!;
              if (clear(from, candidate, 5)) {
                target = candidate;
                break;
              }
            }
          }
          if (clear(from, target, 5) &&
              _escape([TargetCapsule(target, target, 110)], .95)) {
            shots.add(
              LodestarShot(from, target, _sequence, shell: true)
                ..position = from,
            );
            _noteRelease();
            _mortarAt[tube] = elapsed;
            signal('shot_revolver_0.wav');
          }
          _released++;
        }
        if (_released >= count && age > fallback + count * .35) _finish(5.5);
      case LodestarMove.mines:
        if (_released == 0 && mines.length < 2) {
          final deployment = _mineThrow();
          if (deployment != null) {
            aim = deployment.target;
            mines.add(
              LodestarMine(deployment.from, deployment.target, _sequence),
            );
            _noteRelease();
            signal('walker_rocket_launch.wav');
          }
          _released++;
        }
        _finish(6);
      case LodestarMove.bite:
        final shape = TargetCapsule(
          p.front,
          p.socket(const Offset(110, 0)),
          40,
        );
        if (age < .24 &&
            shape.distance(player) <= 26 &&
            clear(p.front, player, 0)) {
          _hit(_sequence, 'Lodestar jaws');
        }
        if (_released == 0) {
          _released++;
          _noteRelease();
          signal('reload_shotgun_0.wav');
        }
        if (age > .24) _finish(3.8);
      case LodestarMove.tail:
        if (_released == 0) {
          _released++;
          _noteRelease();
          signal('supply_break.wav');
        }
        if (age > .5) _finish(5.5);
      case LodestarMove.burrow:
        break;
    }
  }

  ({Offset from, Offset target})? _mineThrow() {
    final base = rig.poses[LodestarSection.mines.index].position;
    final direction = unit(
      heading(playerVelocity.distance > 20 ? playerVelocity : player - base),
    );
    final side = Offset(-direction.dy, direction.dx);
    for (final desired in [
      player + direction * 220,
      player + side * 300,
      player - side * 300,
      player + side * 260 - direction * 140,
      player - side * 260 - direction * 140,
    ]) {
      final from = base + unit(heading(desired - base)) * 63;
      final target = from + limit(desired - from, 680);
      if (clear(target, target, 165) &&
          clear(from, target, 12) &&
          _ownClear(from, target, LodestarSection.mines) &&
          shapes(rig.poses).every((s) => s.distance(target) > 80) &&
          mines.every((m) => (m.landing - target).distance > 300) &&
          (target - player).distance > 165 &&
          _escape([TargetCapsule(target, target, 145)], .85)) {
        return (from: from, target: target);
      }
    }
    return null;
  }

  bool _ownClear(Offset a, Offset b, LodestarSection own) => rig.poses.every(
    (p) =>
        p.section == own ||
        depths[p.section.index] >= .72 ||
        p
                .footprint(broken: !sections.living(p.section))
                .contact(a, b, padding: 6) ==
            null,
  );
  void _finish(double cooldown) {
    _cooldown[move] = cooldown;
    _recover();
  }

  void _noteRelease() {
    releasedAt[move] = elapsed;
    releases[move] = (releases[move] ?? 0) + 1;
  }

  void _contact(List<LodestarPose> previous) {
    if (_contactGate > 0 || !vulnerable || _withdraw) return;
    for (var i = 0; i < 6; i++) {
      final part = LodestarSection.values[i];
      if (!exposed(part)) continue;
      final a = previous[i], b = rig.poses[i];
      final travel =
          (a.position - b.position).distance +
          LodestarRig.difference(b.yaw, a.yaw).abs() * 120;
      final samples = math.max(1, (travel / .8).ceil());
      var touch = false;
      for (var n = 0; n <= samples; n++) {
        final t = n / samples;
        final pose = LodestarPose(
          part,
          Offset.lerp(a.position, b.position, t)!,
          a.yaw + LodestarRig.difference(b.yaw, a.yaw) * t,
        );
        if (partShapes(pose)
            .any((s) => s.contact(player, player, padding: 26.4) != null)) {
          touch = true;
          break;
        }
      }
      if (!touch || !clear(b.position, player, 0)) continue;
      final special =
          phase == LodestarPhase.emerging ||
          ((move == LodestarMove.tail || move == LodestarMove.bite) &&
              phase == LodestarPhase.firing);
      if (special) {
        if (phase != LodestarPhase.emerging || _eruptionDamage) {
          _hit(_sequence, 'Lodestar ${part.name}');
        }
      } else if (hurt(1, 'Lodestar armor')) {
        _contactGate = .5;
      }
      break;
    }
  }

  bool _hit(int sequence, String cause) {
    if (_accepted.contains(sequence) || _contactGate > 0) return false;
    if (!hurt(1, cause)) return false;
    _accepted.add(sequence);
    _contactGate = .5;
    return true;
  }

  void _flights(double dt) {
    for (final shot in shots) {
      final previous = shot.position;
      shot.age += dt;
      if (shot.shell) {
        shot.position = Offset.lerp(
          shot.from,
          shot.target,
          (shot.age / shot.duration).clamp(0, 1),
        )!;
        if (shot.age >= shot.duration) {
          if ((player - shot.target).distance <= 136 &&
              clear(shot.target, player, 0)) {
            _hit(shot.sequence, 'Lodestar mortar');
          }
          _burst(shot.target, 110);
          shot.removed = true;
          signal('blast.wav');
        }
      } else {
        shot.position =
            shot.from + shot.direction * math.min(760, shot.age * shot.speed);
        if (!clear(previous, shot.position, 6)) {
          shot.removed = true;
          _burst(shot.position, 24, blast: false);
        } else if (TargetCapsule(previous, shot.position, 6).distance(player) <=
            26) {
          _hit(shot.sequence, 'Lodestar shards');
          shot.removed = true;
          _burst(shot.position, 24, blast: false);
        }
        if (shot.age >= shot.duration) shot.removed = true;
      }
    }
    shots.removeWhere((s) => s.removed);
    for (final mine in mines) {
      final previous = mine.position, wasFlying = mine.flying;
      mine.age += dt;
      if (wasFlying &&
          (!clear(previous, mine.position, 12) ||
              !_ownClear(previous, mine.position, LodestarSection.mines))) {
        mine.landing = previous;
        mine.age = .8;
      }
      if (mine.armed && (mine.position - player).distance <= 136) {
        mine.trigger = 0;
        signal('supply_incoming.wav');
      }
      if (mine.trigger >= 0) {
        mine.trigger += dt;
        if (mine.trigger >= .85) {
          if ((player - mine.position).distance <= 171 &&
              clear(mine.position, player, 0)) {
            _hit(100000 + mine.sequence, 'Lodestar mine');
          }
          _burst(mine.position, 145);
          signal('blast.wav');
          mine.removed = true;
        }
      }
      if (mine.age >= 12) {
        mine.removed = true;
        _burst(mine.position, 22, blast: false);
      }
    }
    mines.removeWhere((m) => m.removed);
    _accepted.removeWhere(
      (id) => (id >= 100000 ? id - 100000 : id) < _sequence - 30,
    );
  }

  bool disarm(LodestarMine mine) {
    if (defeated || mine.removed || !mines.contains(mine)) return false;
    mine.removed = true;
    _burst(mine.position, 24, blast: false);
    signal('impact_carbine.wav');
    return true;
  }

  void _burst(
    Offset p,
    double r, {
    bool blast = true,
    bool excavation = false,
  }) {
    if (bursts.length >= 8) bursts.removeAt(0);
    bursts.add(LodestarBurst(p, r, blast: blast, excavation: excavation));
  }

  void localDamage(List<LodestarDamage> result) {
    if (defeated) return;
    if (sections.coreExposed && coreOpenedAt < 0) {
      coreOpenedAt = elapsed;
      signal('supply_break.wav');
      _burst(rig.poses.first.position, 75, blast: false);
    }
    for (final h in result) {
      hits[h.section] = elapsed;
      if (h.broke) {
        signal('supply_break.wav');
        _burst(rig.poses[h.section.index].position, 65);
      }
    }
    if (sections.defeated) destroy();
  }

  void destroy() {
    if (defeated) return;
    _deathMouth = mouth;
    _deathSinking = sinking;
    for (final s in LodestarSection.values) {
      _shutdownParts[s.index] = sections.integrity(s) > 0;
    }
    shots.clear();
    mines.clear();
    warnedSweep.clear();
    bursts.clear();
    _phase(LodestarPhase.destruction);
    signal('supply_break.wav');
    rig.requestedSpeed = 0;
    // No damaging underground exit; visible finite collapse at committed tunnel.
    if (depths.every((d) => d >= .72)) {
      _burst(_deathMouth, 140, blast: false, excavation: true);
    }
  }

  Map<String, dynamic> checkpoint() => {
    'v': 1,
    'releasedAt': {for (final e in releasedAt.entries) e.key.name: e.value},
    'rig': rig.checkpoint(),
    'sections': sections.checkpoint(),
    'phase': phase.name,
    'move': move.name,
    'elapsed': elapsed,
    'age': age,
    'depths': [...depths],
    'entry': [entry.dx, entry.dy],
    'exit': [exit.dx, exit.dy],
    'aim': [aim.dx, aim.dy],
    'course': course,
    'shardYaw': shardYaw,
    'startTravel': _startTravel,
    'sequence': _sequence,
    'turn': _turn,
    'released': _released,
    'withdraw': _withdraw,
    if (_repositioning) 'repositioning': true,
    'eruption': _eruptionDamage,
    'coreOpenedAt': coreOpenedAt,
    'shutdownParts': [..._shutdownParts],
    'deathMouth': [_deathMouth.dx, _deathMouth.dy],
    'deathSinking': _deathSinking,
    'cooldown': {for (final e in _cooldown.entries) e.key.name: e.value},
  };

  static bool validCheckpoint(dynamic raw) {
    if (raw is! Map ||
        raw['v'] != 1 ||
        (raw.containsKey('repositioning') && raw['repositioning'] is! bool)) {
      return false;
    }
    bool n(dynamic v, double lo, double hi) =>
        v is num && v.isFinite && v >= lo && v <= hi;
    bool tuple(dynamic v, int count, double limit) =>
        v is List && v.length == count && v.every((x) => n(x, -limit, limit));
    try {
      final r = raw['rig'] as Map, parts = raw['sections'] as Map;
      if (r['poses'] is! List ||
          (r['poses'] as List).length != 6 ||
          !(r['poses'] as List).every((p) => tuple(p, 3, 1000000))) {
        return false;
      }
      final path = r['path'];
      if (path is! List || path.length < 2 || path.length > 10000) return false;
      double? last;
      for (final p in path) {
        if (!tuple(p, 3, 1e9) || (last != null && p[0] <= last)) return false;
        last = (p[0] as num).toDouble();
      }
      for (final key in [
        'cursor',
        'yaw',
        'speed',
        'curl',
        'travel',
        'roller',
        'elapsed',
        'desired',
        'requested',
      ]) {
        if (!n(r[key], -1e9, 1e9)) return false;
      }
      final hp = parts['hp'] as List;
      if (hp.length != 6 || parts['dead'] is! bool) return false;
      for (final s in LodestarSection.values) {
        if (!n(hp[s.index], 0, s.maxIntegrity)) return false;
      }
      if ((parts['dead'] == true) != (hp[0] == 0)) return false;
      if (hp[0] < 80 &&
          hp[0] > 0 &&
          LodestarSection.values
                  .where((s) => s.weapon && hp[s.index] == 0)
                  .length <
              2) {
        return false;
      }
      if (!LodestarPhase.values.any((p) => p.name == raw['phase']) ||
          !LodestarMove.values.any((p) => p.name == raw['move'])) {
        return false;
      }
      final dead = ['destruction', 'finished'].contains(raw['phase']);
      if (dead != parts['dead']) return false;
      if (!tuple(raw['depths'], 6, 1) ||
          (raw['depths'] as List).any((d) => d < 0)) {
        return false;
      }
      for (final key in ['entry', 'exit', 'aim']) {
        if (!tuple(raw[key], 2, 1000000)) return false;
      }
      for (final key in ['elapsed', 'age']) {
        if (!n(raw[key], 0, 1e9)) return false;
      }
      for (final key in ['course', 'startTravel', 'coreOpenedAt']) {
        if (!n(raw[key], -1e9, 1e9)) return false;
      }
      for (final key in ['sequence', 'turn', 'released']) {
        if (raw[key] is! int || !n(raw[key], 0, 1e9)) return false;
      }
      if (raw['withdraw'] is! bool ||
          raw['eruption'] is! bool ||
          raw['shutdownParts'] is! List ||
          (raw['shutdownParts'] as List).length != 6 ||
          !(raw['shutdownParts'] as List).every((v) => v is bool)) {
        return false;
      }
      if (raw.containsKey('deathMouth') &&
          !tuple(raw['deathMouth'], 2, 1000000)) {
        return false;
      }
      if (raw.containsKey('deathSinking') && raw['deathSinking'] is! bool) {
        return false;
      }
      if (raw.containsKey('shardYaw') && !n(raw['shardYaw'], -1e9, 1e9)) {
        return false;
      }
      if (raw.containsKey('releasedAt')) {
        final releases = raw['releasedAt'];
        if (releases is! Map ||
            releases.length > 6 ||
            !releases.entries.every(
              (e) =>
                  LodestarMove.values.any((m) => m.name == e.key) &&
                  n(e.value, -1000, (raw['elapsed'] as num).toDouble()),
            )) {
          return false;
        }
      }
      final cooldown = raw['cooldown'] as Map;
      return cooldown.entries.every(
        (e) =>
            LodestarMove.values.any((m) => m.name == e.key) &&
            n(e.value, 0, 100),
      );
    } catch (_) {
      return false;
    }
  }

  void restore(Map raw, {bool continueRun = false}) {
    rig.restore(raw['rig'] as Map);
    sections.restore(raw['sections'] as Map);
    phase = LodestarPhase.values.byName(raw['phase'] as String);
    move = LodestarMove.values.byName(raw['move'] as String);
    double n(String key) => (raw[key] as num?)?.toDouble() ?? 0;
    Offset p(String key) => Offset(
      (raw[key][0] as num).toDouble(),
      (raw[key][1] as num).toDouble(),
    );
    elapsed = n('elapsed');
    age = n('age');
    course = n('course');
    shardYaw = n('shardYaw');
    _startTravel = n('startTravel');
    entry = p('entry');
    exit = p('exit');
    aim = p('aim');
    coreOpenedAt = n('coreOpenedAt');
    depths.setAll(0, (raw['depths'] as List).map((v) => (v as num).toDouble()));
    _sequence = raw['sequence'] as int? ?? 0;
    _turn = raw['turn'] as int? ?? 0;
    _released = raw['released'] as int? ?? 0;
    _withdraw = raw['withdraw'] == true;
    _repositioning = raw['repositioning'] == true;
    _deathSinking = raw['deathSinking'] == true;
    _deathMouth = raw['deathMouth'] is List ? p('deathMouth') : entry;
    _eruptionDamage = raw['eruption'] == true;
    _shutdownParts.setAll(0, (raw['shutdownParts'] as List).cast<bool>());
    _cooldown.clear();
    for (final e in (raw['cooldown'] as Map).entries) {
      _cooldown[LodestarMove.values.byName(e.key as String)] = (e.value as num)
          .toDouble();
    }
    releasedAt.clear();
    for (final e in (raw['releasedAt'] as Map? ?? {}).entries) {
      releasedAt[LodestarMove.values.byName(e.key as String)] = (e.value as num)
          .toDouble();
    }
    shots.clear();
    mines.clear();
    warnedSweep.clear();
    bursts.clear();
    // Continue keeps anatomy/HP and never replays a committed attack or arrival.
    // Finish an interrupted dive harmlessly along the saved route.
    if (continueRun && !defeated) {
      _contactGate = 1.5;
      _quiet = 1.5;
      if (_repositioning) {
        _withdraw = false;
        _eruptionDamage = false;
        if (phase == LodestarPhase.exitWarning) age = 0;
        return;
      }
      if (depths.any((d) => d > 0)) {
        _withdraw =
            _withdraw ||
            [
              LodestarPhase.entry,
              LodestarPhase.underground,
              LodestarPhase.exitWarning,
            ].contains(phase);
        _eruptionDamage = false;
        phase = LodestarPhase.emerging;
      } else {
        phase = LodestarPhase.recovery;
      }
      age = 0;
    }
  }

  void _chooseExit() {
    final origin = player + limit(playerVelocity * 1.0, 260);
    for (var n = 0; n < 24; n++) {
      final a = n * 2.399963229728653;
      final at = origin + unit(a) * 400;
      final yaw = heading(origin - at);
      final probe = LodestarRig(head: at, heading: yaw);
      final all = [
        ...probe.poses,
        for (final p in probe.poses)
          LodestarPose(p.section, p.position + unit(yaw) * 680, p.yaw),
      ];
      if (all.every((p) => clear(p.position, p.position, 90)) &&
          clear(at - unit(yaw) * 760, at + unit(yaw) * 760, 110) &&
          _escape([TargetCapsule(at, at + unit(yaw) * 680, 85)], .95)) {
        exit = at;
        course = yaw;
        return;
      }
    }
    // A blocked arena cannot turn an invalid corridor into an invisible hit.
    exit = entry;
    course = rig.poses.first.yaw;
    _eruptionDamage = false;
  }
}
