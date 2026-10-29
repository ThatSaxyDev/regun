import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/target_shape.dart';
import 'package:regun/systems/walker_combat.dart' show WalkerMinion;
import 'package:regun/systems/run_random.dart';

enum ArietPhase {
  incoming,
  descent,
  settle,
  navigate,
  strafeLock,
  strafe,
  strafeBrake,
  turnFire,
  cannonLock,
  cannon,
  seekerLock,
  seekers,
  flakLock,
  flak,
  exhaustLock,
  exhaust,
  recovery,
  failing,
  crash,
  wreck,
  complete,
}

enum ArietCue {
  incoming,
  nose,
  cannon,
  seeker,
  flak,
  intercept,
  engine,
  release,
  land,
  fatal,
  complete,
  impact,
}

class ArietRound {
  ArietRound(
    this.position,
    this.heading, {
    this.cannon = false,
    this.seeker = false,
    this.fragment = false,
    this.flakPacket = false,
    this.burstAt,
    this.owner = 0,
    this.pass = 0,
  });
  Offset position;
  double heading;
  final bool cannon, seeker, fragment, flakPacket;
  final Offset? burstAt;
  bool removed = false;
  final int owner, pass;
  double age = 0, travel = 0;
  double get radius => seeker
      ? 12
      : cannon
      ? 9
      : fragment
      ? 6
      : 5;
  double get speed => flakPacket
      ? 600
      : seeker
      ? 320
      : cannon
      ? 750
      : fragment
      ? 520
      : 850;
}

class ArietImpact {
  ArietImpact(
    this.position,
    this.radius, {
    this.dust = false,
    this.rocketBlast = false,
  });
  Offset position;
  final double radius;
  final bool dust;
  final bool rocketBlast;
  double age = 0;
}

class ArietDrop {
  ArietDrop(this.id, this.landing, this.releaseAt);
  final int id;
  final Offset landing;
  final double releaseAt;
  Offset? origin, groundOrigin;
  double age = -1;
  bool activated = false, aborted = false;
  double get fall => (age / .9).clamp(0, 1);
  Offset get position => Offset.lerp(origin ?? landing, landing, fall)!;
  Offset get shadowPosition =>
      Offset.lerp(groundOrigin ?? landing, landing, fall)!;
}

/// Portable active-clock fight. Native code supplies bodies, cover and damage;
/// no wall-clock callbacks or Flame ownership live inside the controller.
class ArietCombat {
  ArietCombat({
    required this.rig,
    required this.clear,
    required this.hurt,
    required this.signal,
    required this.landingLegal,
    required this.deploy,
    this.minions,
    this.crushMinion,
    this.steer,
    int seed = 427,
    int? reinforcementCount,
  }) : random = RunRandom(seed) {
    final supportRoll = RunRandom(seed ^ 0x51a7).nextInt(100);
    escortQuota =
        reinforcementCount ??
        (supportRoll < 25
            ? 0
            : supportRoll < 70
            ? 1
            : 2);
    deploymentSpent = escortQuota == 0;
    rig.trackCannon = false;
    rig.hoverMotion = true;
    rig.height = rig.hoverElevation = flightHeight;
  }
  final ArietRig rig;
  final Offset Function(Offset, double)? steer;
  final RunRandom random;
  final bool Function(Offset, Offset, double) clear;
  final bool Function(double, String) hurt;
  final void Function(ArietCue) signal;
  final bool Function(Offset, double) landingLegal;
  final void Function(ArietDrop) deploy;
  final Iterable<WalkerMinion> Function()? minions;
  final void Function(String)? crushMinion;
  static const roundLimit = 32;
  static const flightHeight = 160.0;
  final rounds = <ArietRound>[];
  final impacts = <ArietImpact>[];
  final drops = <ArietDrop>[];
  final exhaust = <TargetCapsule>[];
  List<double> get noseYaw => rig.rotaryYaw;
  final recoil = [0.0, 0.0], flash = [0.0, 0.0];
  final flakTargets = <Offset>[];
  double flakRecoil = 0, flakFlash = 0, launcherFlash = 0;
  int totalSeekers = 0, totalFlak = 0, totalIntercepts = 0;
  int seekerVolley = 4, launcherCell = -1;
  int _attackCycle = 0;
  bool _flakHit = false;
  double _quiet = 0;
  Offset? _flightFocus, _previousPlayer;
  Offset _aimVelocity = Offset.zero, _observedVelocity = Offset.zero;
  double _aimTurn = 0;
  double _flightRefresh = 0;
  double cannonRecoil = 0, cannonFlash = 0;
  Offset player = Offset.zero, playerVelocity = Offset.zero;
  ArietPhase phase = ArietPhase.incoming;
  ArietPhase? lastAttack;
  bool enraged = false,
      paused = false,
      deploymentSpent = false,
      deploymentPass = false;
  bool _exhaustHit = false;
  late int escortQuota;
  double healthFraction = 1, _lastDropAt = -1000, _gunHitReady = 0;
  bool get _canReinforce =>
      enraged &&
      totalDrops < escortQuota &&
      drops.every((d) => d.activated || d.aborted) &&
      (totalDrops == 0 ||
          (elapsed - _lastDropAt >= 20 &&
              (healthFraction <= .25 || elapsed - _lastDropAt >= 32)));
  double clock = 0,
      elapsed = 0,
      _remainder = 0,
      grace = 0,
      _nextShot = 0,
      _closeDwell = 0;
  double _escortGate = 0;
  double? _passStart;
  int _escortOwner = 0;
  int totalEscort = 0;
  int sequence = 0,
      released = 0,
      totalNose = 0,
      totalCannon = 0,
      totalDrops = 0;
  Offset routeStart = Offset.zero,
      routeEnd = Offset.zero,
      routeHeading = const Offset(1, 0),
      locked = Offset.zero,
      crashEnd = Offset.zero;
  double routeLength = 0, _distance = 0;
  double get recoveryDuration => lastAttack == ArietPhase.strafe ? 1.2 : 1.3;
  bool get defeated => phase.index >= ArietPhase.failing.index;
  bool get finished => phase == ArietPhase.complete;
  bool get vulnerable => phase.index >= ArietPhase.navigate.index && !defeated;
  bool get settled => phase.index >= ArietPhase.settle.index;
  String get label => switch (phase) {
    ArietPhase.incoming => 'INCOMING',
    ArietPhase.descent => 'DEPLOYING',
    ArietPhase.settle => 'HOVER',
    ArietPhase.navigate => 'REPOSITIONING',
    ArietPhase.strafeLock =>
      deploymentPass ? 'CARGO FLIGHT LOCK' : 'THRUST CHARGING',
    ArietPhase.strafe => deploymentPass ? 'CARGO RELEASE' : 'JET CHARGE',
    ArietPhase.strafeBrake => 'AIR BRAKE',
    ArietPhase.turnFire => 'ROTARY COUNTER',
    ArietPhase.cannonLock => 'CANNON LOCK',
    ArietPhase.cannon => 'HEAVY CANNON',
    ArietPhase.seekerLock => 'SEEKER LOCK',
    ArietPhase.seekers => 'SEEKERS',
    ArietPhase.flakLock => 'FLAK LOCK',
    ArietPhase.flak => 'FLAK BURST',
    ArietPhase.exhaustLock => 'ENGINES VENTING',
    ArietPhase.exhaust => 'EXHAUST',
    ArietPhase.recovery => 'COOLING',
    ArietPhase.failing => 'POWER FAILURE',
    ArietPhase.crash => 'EMERGENCY LANDING',
    ArietPhase.wreck => 'WRECK',
    ArietPhase.complete => 'ARIET DOWN',
  };
  static Offset unit(double a) => Offset(math.cos(a), math.sin(a));
  static double heading(Offset d) => math.atan2(d.dy, d.dx);
  bool get escortsMayFire =>
      !defeated &&
      (phase == ArietPhase.navigate ||
          (!deploymentPass &&
              [
                ArietPhase.strafeLock,
                ArietPhase.strafe,
                ArietPhase.strafeBrake,
                ArietPhase.turnFire,
              ].contains(phase)));
  bool claimEscortVolley(int id) {
    if (!escortsMayFire ||
        elapsed < _escortGate ||
        (phase == ArietPhase.navigate && clock >= grace)) {
      return false;
    }
    _escortOwner = id;
    _escortGate = elapsed + 1.15;
    return true;
  }

  bool escortRelease(int id, Offset origin, double angle) {
    if (!escortsMayFire ||
        _escortOwner != id ||
        rounds.length >= roundLimit ||
        !clear(origin, origin + unit(angle) * 16, 6)) {
      return false;
    }
    rounds.add(ArietRound(origin, angle, owner: id));
    totalEscort++;
    signal(ArietCue.nose);
    return true;
  }

  Offset noseMuzzle(int i) =>
      rig.noseSocket(i) +
      unit(noseYaw[i]) * (ArietRig.rotaryLength - recoil[i]);
  Offset get cannonMuzzle =>
      rig.cannonSocket +
      unit(rig.cannonYaw) * (ArietRig.cannonLength - cannonRecoil);
  Offset get flakMuzzle =>
      rig.flakSocket + unit(rig.flakYaw) * (ArietRig.flakLength - flakRecoil);
  int get reservedRounds =>
      phase == ArietPhase.flakLock || phase == ArietPhase.flak
      ? (2 - released).clamp(0, 2) * 4 +
            rounds.where((r) => r.flakPacket).length * 2
      : 0;
  bool intercept(ArietRound round) {
    if (paused ||
        defeated ||
        !round.seeker ||
        round.removed ||
        !rounds.remove(round)) {
      return false;
    }
    round.removed = true;
    totalIntercepts++;
    signal(ArietCue.intercept);
    _impact(round.position, 70, rocketBlast: true);
    return true;
  }

  double get descent => phase == ArietPhase.incoming
      ? 600
      : phase == ArietPhase.descent
      ? 600 * math.pow(1 - clock / 1.0, 2).clamp(0, 1).toDouble()
      : 0;
  void _enter(ArietPhase next) {
    phase = next;
    clock = 0;
    released = 0;
    _nextShot = 0;
    if ([
      ArietPhase.cannonLock,
      ArietPhase.exhaustLock,
      ArietPhase.seekerLock,
      ArietPhase.flakLock,
    ].contains(next)) {
      rig.desiredYaw = rig.yaw;
    }
    if (next == ArietPhase.seekerLock) {
      locked = player;
      seekerVolley = enraged ? 6 : 4;
    }
    if (next == ArietPhase.strafe) {
      _passStart = elapsed;
    }
    if (next == ArietPhase.recovery && _passStart == null) {
      for (final d in drops) {
        if (d.origin == null) d.aborted = true;
      }
    }
    if (next == ArietPhase.recovery) {
      _quiet = 0;
      rig.command = Offset.zero;
    }
    if (next == ArietPhase.navigate) {
      grace = .7;
    }
  }

  void beginDestruction() {
    if (defeated) return;
    rig.enginesRunning = false;
    impacts.removeWhere((i) => i.rocketBlast);
    rounds.clear();
    exhaust.clear();
    flakTargets.clear();
    for (final d in drops) {
      if (!d.activated) d.aborted = true;
    }
    rig.command = Offset.zero;
    final end = rig.position - unit(rig.yaw) * 70;
    crashEnd = clear(rig.position, end, ArietRig.navigationRadius)
        ? end
        : rig.position;
    _enter(ArietPhase.failing);
    signal(ArietCue.fatal);
  }

  void advance(double dt) {
    if (paused || !dt.isFinite || dt <= 0) return;
    _remainder += dt;
    while (_remainder + 1e-10 >= ArietRig.tick) {
      _remainder -= ArietRig.tick;
      _step(ArietRig.tick);
    }
  }

  void _step(double dt) {
    elapsed += dt;
    clock += dt;
    final previous = _previousPlayer;
    final movement = previous == null ? Offset.zero : player - previous;
    final observed = movement.distance > 80 ? Offset.zero : movement / dt;
    final velocity = playerVelocity.distance > 1 ? playerVelocity : observed;
    _aimVelocity = ArietRig.limit(velocity, 700);
    final turn = velocity.distance > 50 && _observedVelocity.distance > 50
        ? ArietRig.difference(heading(velocity), heading(_observedVelocity)) /
              dt
        : 0.0;
    _aimTurn += (turn.clamp(-2.5, 2.5) - _aimTurn) * (1 - math.exp(-8 * dt));
    _observedVelocity = velocity;
    _previousPlayer = player;
    for (var i = 0; i < 2; i++) {
      recoil[i] = math.max(0, recoil[i] - 90 * dt);
      flash[i] = math.max(0, flash[i] - dt);
    }
    cannonRecoil = math.max(0, cannonRecoil - 100 * dt);
    cannonFlash = math.max(0, cannonFlash - dt);
    flakRecoil = math.max(0, flakRecoil - 90 * dt);
    flakFlash = math.max(0, flakFlash - dt);
    launcherFlash = math.max(0, launcherFlash - dt);
    // Bearings track independently of flight, with no hull-relative arc clamp.
    for (var i = 0; i < 2; i++) {
      noseYaw[i] = ArietRig.turn(noseYaw[i], _rotaryAim(i), 12 * dt);
    }
    if (phase != ArietPhase.flakLock && phase != ArietPhase.flak) {
      rig.flakYaw = ArietRig.turn(
        rig.flakYaw,
        heading(player - rig.flakSocket),
        12 * dt,
      );
    }
    for (final impact in impacts) {
      impact.age += dt;
    }
    impacts.removeWhere((i) => i.age > .65);
    _rounds(dt);
    _drops(dt);
    rig.thrustBoost = 0;
    final distance = (player - rig.position).distance;
    _closeDwell = distance < 260 ? _closeDwell + dt : 0;
    switch (phase) {
      case ArietPhase.incoming:
        if (clock >= .9) {
          signal(ArietCue.incoming);
          _enter(ArietPhase.descent);
        }
      case ArietPhase.descent:
        if (clock >= 1) {
          _enter(ArietPhase.settle);
          signal(ArietCue.land);
          _impact(rig.position, 190, dust: true);
        }
      case ArietPhase.settle:
        if (clock >= .65) _enter(ArietPhase.navigate);
      case ArietPhase.navigate:
        _combatOrbit(speed: enraged ? 330 : 300);
        if (clock >= grace) {
          _select();
        }
      case ArietPhase.strafeLock:
        rig.command = deploymentPass ? Offset.zero : routeHeading * 120;
        rig.thrustBoost = (clock / .8).clamp(0, 1);
        rig.desiredYaw = heading(routeHeading);
        if (clock >= 1) {
          _distance = 0;
          sequence++;
          _enter(ArietPhase.strafe);
        } else if (clock > 2.8) {
          _enter(ArietPhase.recovery);
        }
      case ArietPhase.strafe:
        final speed = deploymentPass ? 420.0 : ArietRig.passSpeed;
        rig.speedLimit = speed;
        rig.command = routeHeading * speed;
        rig.thrustBoost = deploymentPass ? .45 : 1;
        rig.desiredYaw = heading(routeHeading);
        const count = 18;
        // A normal charge spends its rotary volley after braking. Cargo keeps
        // its slower, quiet-release pass and restricted opening cover stream.
        final firing = deploymentPass && clock < .90;
        if (firing &&
            released < count &&
            clock >= _nextShot &&
            rounds.length < roundLimit) {
          if (_nose(released % 2)) {
            released++;
            _nextShot = clock + (deploymentPass ? .045 : .06);
          }
        }
        _distance = (rig.position - routeStart).distance;
        if (_distance >= routeLength || clock >= 3.3) {
          _enter(deploymentPass ? ArietPhase.recovery : ArietPhase.strafeBrake);
        }
      case ArietPhase.strafeBrake:
        rig.command = Offset.zero;
        rig.thrustBoost = .55;
        // Keep the hull on its flight heading until real braking finishes.
        rig.desiredYaw = heading(routeHeading);
        if (rig.velocity.distance <= 25 && clock >= .12) {
          rig.velocity = Offset.zero;
          _enter(ArietPhase.turnFire);
          _nextShot = .10;
        }
      case ArietPhase.turnFire:
        // Real stop and quick opening shot, then resume flight during counterfire.
        if (clock < .18) {
          rig.command = Offset.zero;
        } else {
          _combatOrbit();
        }
        rig.thrustBoost = .3;
        if (released < 36 &&
            clock >= _nextShot &&
            rounds.length < roundLimit &&
            _nose(released % 2)) {
          released++;
          _nextShot = clock + .05;
        }
        if (released >= 36 || clock >= 3.2) _enter(ArietPhase.recovery);
      case ArietPhase.cannonLock:
        _combatOrbit();
        _aimCannon();
        if (clock >= .9) {
          locked = player;
          _enter(ArietPhase.cannon);
          _nextShot = .23;
        }
      case ArietPhase.cannon:
        _combatOrbit();
        if (clock < _nextShot - .22) locked = player;
        // The committed aim point stays planted even while the firing platform
        // moves. Only the gun-to-that-point bearing is solved again.
        _aimCannon(locked);
        if (clock >= _nextShot) {
          final aim = heading(locked - rig.cannonSocket);
          if (ArietRig.difference(rig.cannonYaw, aim).abs() < .10 &&
              _cannon()) {
            released++;
            _nextShot += .30;
          } else if (clock > _nextShot + .18) {
            _nextShot = clock + .30;
          }
          if (released >= 4 || clock >= 3.0) _enter(ArietPhase.recovery);
        }
      case ArietPhase.seekerLock:
        _combatOrbit();
        if (clock <= dt + 1e-9) {
          seekerVolley = enraged ? 6 : 4;
          locked = player;
        }
        if (clock >= .9 && rounds.isEmpty) {
          _enter(ArietPhase.seekers);
        }
      case ArietPhase.seekers:
        _combatOrbit();
        if (released < seekerVolley &&
            clock >= _nextShot &&
            rounds.length < roundLimit) {
          final a =
              heading(locked - rig.launcherSocket) +
              (released - (seekerVolley - 1) / 2) * .26;
          final origin = rig.launcherSocket + unit(a) * 20;
          if (clear(rig.launcherSocket, origin, 12)) {
            rounds.add(ArietRound(origin, a, seeker: true));
            launcherFlash = .1;
            launcherCell = released;
            totalSeekers++;
            signal(ArietCue.seeker);
          }
          released++;
          _nextShot += .28;
        }
        if (released == seekerVolley && !rounds.any((r) => r.seeker)) {
          _enter(ArietPhase.recovery);
        }
      case ArietPhase.flakLock:
        rig.command = Offset.zero;
        if (clock >= .9 && rounds.length + 8 <= roundLimit) {
          _flakHit = false;
          sequence++;
          _enter(ArietPhase.flak);
          _nextShot = .01;
        }
      case ArietPhase.flak:
        rig.command = Offset.zero;
        if (released < 2) {
          rig.flakYaw = ArietRig.turn(
            rig.flakYaw,
            heading(flakTargets[released] - rig.flakSocket),
            12 * dt,
          );
        }
        if (released < 2 &&
            clock >= _nextShot &&
            ArietRig.difference(
                  rig.flakYaw,
                  heading(flakTargets[released] - rig.flakSocket),
                ).abs() <
                .04) {
          final target = flakTargets[released];
          final origin = flakMuzzle;
          if (rig.barrelClear(3, rig.flakYaw, recoil: flakRecoil) &&
              clear(rig.flakSocket, origin, 6) &&
              clear(origin, target, 6)) {
            rounds.add(
              ArietRound(
                origin,
                heading(target - origin),
                flakPacket: true,
                burstAt: target,
                pass: sequence,
              ),
            );
            flakRecoil = 8;
            flakFlash = .065;
            totalFlak++;
            signal(ArietCue.flak);
          }
          released++;
          _nextShot += .25;
        }
        if (released == 2 && !rounds.any((r) => r.flakPacket)) {
          flakTargets.clear();
          _enter(ArietPhase.recovery);
        }
      case ArietPhase.exhaustLock:
        rig.command = Offset.zero;
        if (clock >= 1) {
          _enter(ArietPhase.exhaust);
          signal(ArietCue.engine);
        }
      case ArietPhase.exhaust:
        rig.command = Offset.zero;
        if (!_exhaustHit &&
            exhaust.any((e) => e.distance(player) <= 26) &&
            clear(rig.position, player, 0)) {
          if (hurt(2, 'Ariet exhaust')) _exhaustHit = true;
        }
        for (final m in minions?.call() ?? <WalkerMinion>[]) {
          if (exhaust.any((e) => e.distance(m.position) <= m.radius) &&
              clear(rig.position, m.position, 0)) {
            crushMinion?.call(m.id);
          }
        }
        if (clock >= .2) {
          exhaust.clear();
          _enter(ArietPhase.recovery);
        }
      case ArietPhase.recovery:
        _combatOrbit(speed: 230);
        _quiet = rounds.isEmpty && drops.every((d) => d.activated || d.aborted)
            ? _quiet + dt
            : 0;
        if (_quiet >= recoveryDuration) _enter(ArietPhase.navigate);
      case ArietPhase.failing:
        rig.command = Offset.zero;
        if (clock >= 1.1) _enter(ArietPhase.crash);
      case ArietPhase.crash:
        rig.command = ArietRig.limit((crashEnd - rig.position) * 3, 100);
        if (clock >= 1) {
          rig.command = Offset.zero;
          _impact(rig.position, 210, dust: true);
          signal(ArietCue.land);
          _enter(ArietPhase.wreck);
        }
      case ArietPhase.wreck:
        rig.command = Offset.zero;
        if (clock >= 2) {
          _enter(ArietPhase.complete);
          signal(ArietCue.complete);
        }
      case ArietPhase.complete:
        rig.command = Offset.zero;
    }
    final planted = [
      ArietPhase.exhaustLock,
      ArietPhase.exhaust,
      ArietPhase.flakLock,
      ArietPhase.flak,
    ].contains(phase);
    if (planted || (phase == ArietPhase.turnFire && clock < .18)) {
      rig.velocity = Offset.zero;
    }
    // Cargo release does not lower the gunship onto the ground combat plane.
    rig.hoverElevation = flightHeight;
    if (phase == ArietPhase.crash) {
      rig.hoverElevation = flightHeight * (1 - clock).clamp(0, 1);
    }
    if (phase.index >= ArietPhase.wreck.index) rig.hoverElevation = 0;
    if ([
      ArietPhase.navigate,
      ArietPhase.turnFire,
      ArietPhase.recovery,
      ArietPhase.cannonLock,
      ArietPhase.cannon,
      ArietPhase.seekerLock,
      ArietPhase.seekers,
    ].contains(phase)) {
      rig.command = steer?.call(rig.command, dt) ?? rig.command;
      if (rig.command.distance > 1 &&
          !(phase == ArietPhase.turnFire && clock < .18)) {
        final current = rig.velocity.distance > 60
            ? heading(rig.velocity)
            : rig.yaw;
        final course = ArietRig.turn(current, heading(rig.command), 1.6 * dt);
        final curved = unit(course) * rig.command.distance;
        // Cover steering can make an urgent correction; never curve back into
        // a wall just to preserve a decorative arc.
        if (clear(
          rig.position,
          rig.position + unit(course) * 90,
          ArietRig.navigationRadius,
        )) {
          rig.command = curved;
        }
        rig.desiredYaw = heading(rig.command);
      }
    }
    final before = rig.position;
    rig.advance(dt);
    if (phase == ArietPhase.strafe &&
        (rig.position - before).distance < .05 &&
        clock > .6) {
      _enter(deploymentPass ? ArietPhase.recovery : ArietPhase.strafeBrake);
    }
    rig.speedLimit = ArietRig.cruiseSpeed;
  }

  void _select() {
    final range = (player - rig.position).distance;
    // An owned escort burst finishes before a main warning starts.
    if (rounds.any((r) => r.owner != 0) || elapsed < _escortGate) return;
    if (range < 265 &&
        _closeDwell >= .6 &&
        lastAttack != ArietPhase.exhaust &&
        [-1.0, 1.0].any(
          (side) =>
              TargetCapsule(
                rig.ground(Offset(-65, side * 180)),
                rig.ground(Offset(10, side * 205)),
                62,
              ).distance(player) <=
              26,
        )) {
      _exhaustHit = false;
      exhaust.clear();
      for (final side in [-1.0, 1.0]) {
        exhaust.add(
          TargetCapsule(
            rig.ground(Offset(-65, side * 180)),
            rig.ground(Offset(10, side * 205)),
            62,
          ),
        );
      }
      lastAttack = ArietPhase.exhaust;
      _enter(ArietPhase.exhaustLock);
      return;
    }
    // Cargo is a full, quiet alternate pass; no seeking/flak under the drop.
    if (_canReinforce && _planPass() && deploymentPass) {
      lastAttack = ArietPhase.strafe;
      _enter(ArietPhase.strafeLock);
      return;
    }
    final choice = _attackCycle % 4;
    _attackCycle++;
    if (choice == 0 && _planPass()) {
      lastAttack = ArietPhase.strafe;
      _enter(ArietPhase.strafeLock);
    } else if (choice == 2 && rounds.length + 8 <= roundLimit) {
      final from = rig.flakSocket;
      final delta = player - from;
      final aim = heading(delta);
      rig.flakYaw = aim;
      final origin = from + unit(aim) * ArietRig.flakLength;
      final target = _clip(
        origin,
        from + unit(aim) * math.min(650, delta.distance),
        6,
      );
      flakTargets
        ..clear()
        ..add(target)
        ..add(_clip(origin, target + unit(aim + math.pi / 2) * 65, 6));
      lastAttack = ArietPhase.flak;
      _enter(ArietPhase.flakLock);
    } else if (choice == 3 && rounds.isEmpty) {
      lastAttack = ArietPhase.seekers;
      _enter(ArietPhase.seekerLock);
    } else if (clear(rig.cannonSocket, player, 9)) {
      locked = player;
      lastAttack = ArietPhase.cannon;
      _enter(ArietPhase.cannonLock);
    }
  }

  Offset _clip(Offset from, Offset to, double radius) {
    if (clear(from, to, radius)) return to;
    var lo = 0.0, hi = 1.0;
    for (var n = 0; n < 14; n++) {
      final mid = (lo + hi) / 2;
      if (clear(from, Offset.lerp(from, to, mid)!, radius)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return Offset.lerp(from, to, lo)!;
  }

  bool _planPass() {
    final delta = player + playerVelocity * .3 - rig.position;
    if (delta.distance < 1) return false;
    final direction = delta / delta.distance;
    final cargo = _canReinforce;
    final length = cargo
        ? (delta.distance + 400).clamp(1000.0, 1100.0)
        : (delta.distance + 180).clamp(620.0, 1100.0);
    final stopping = cargo
        ? 140.0
        : ArietRig.passSpeed * ArietRig.passSpeed / (2 * ArietRig.braking) + 24;
    final end = rig.position + direction * (length + stopping);
    if (!clear(rig.position, end, ArietRig.navigationRadius)) return false;
    routeStart = rig.position;
    routeHeading = direction;
    routeEnd = end;
    routeLength = length;
    deploymentPass = false;
    if (_canReinforce) {
      final side = Offset(-direction.dy, direction.dx);
      final id = totalDrops + 1, sign = id.isOdd ? -1.0 : 1.0;
      for (final candidate in [
        rig.position + direction * 480 + side * (300 * sign),
        rig.position + direction * 620 - side * (300 * sign),
        rig.position + direction * 420 + side * (420 * sign),
      ]) {
        if (!landingLegal(candidate, 70) ||
            drops.any((d) => (d.landing - candidate).distance < 420)) {
          continue;
        }
        drops.removeWhere((d) => d.id == id && d.origin == null);
        drops.add(ArietDrop(id, candidate, .95));
        deploymentPass = true;
        _passStart = null;
        break;
      }
    }
    return true;
  }

  void _combatOrbit({double? speed}) {
    // Fly a leg around a sampled intercept, rather than leash every frame to
    // the survivor. Roof bearings keep tracking independently at full speed.
    if (_flightFocus == null || elapsed >= _flightRefresh) {
      _flightFocus = player + ArietRig.limit(playerVelocity * .55, 180);
      _flightRefresh = elapsed + 1.2;
    }
    final delta = _flightFocus! - rig.position;
    final direction = delta.distance > 1
        ? delta / delta.distance
        : unit(rig.yaw);
    final tangent = Offset(-direction.dy, direction.dx);
    final radial = ((delta.distance - 520) * .9).clamp(-190.0, 190.0);
    rig.command = ArietRig.limit(
      direction * radial + tangent * (speed ?? (enraged ? 290 : 250)),
      ArietRig.cruiseSpeed,
    );
    rig.thrustBoost = .3;
  }

  void _aimCannon([Offset? target]) {
    rig.cannonYaw = ArietRig.turn(
      rig.cannonYaw,
      heading((target ?? player) - rig.cannonSocket),
      12 * ArietRig.tick,
    );
  }

  double _rotaryAim(int i) {
    final socket = rig.noseSocket(i);
    var time = ((player - noseMuzzle(i)).distance / 850).clamp(0.0, 1.3);
    var lead = Offset.zero;
    for (var n = 0; n < 3; n++) {
      final w = _aimTurn;
      if (w.abs() < .1) {
        lead = _aimVelocity * time;
      } else {
        final sine = math.sin(w * time), arc = 1 - math.cos(w * time);
        lead = Offset(
          (_aimVelocity.dx * sine - _aimVelocity.dy * arc) / w,
          (_aimVelocity.dx * arc + _aimVelocity.dy * sine) / w,
        );
      }
      lead = ArietRig.limit(lead, 360);
      time = ((player + lead - noseMuzzle(i)).distance / 850).clamp(0.0, 1.3);
    }
    return heading(player + lead - socket);
  }

  bool _nose(int i) {
    final aim = _rotaryAim(i);
    if (ArietRig.difference(aim, noseYaw[i]).abs() > .12) return false;
    final origin = noseMuzzle(i);
    if (rig.barrelClear(i, noseYaw[i], recoil: recoil[i]) &&
        clear(rig.noseSocket(i), origin, 6)) {
      rounds.add(
        ArietRound(
          origin,
          noseYaw[i] + (random.nextDouble() - .5) * .03,
          pass: sequence,
        ),
      );
      recoil[i] = 7;
      flash[i] = .045;
      totalNose++;
      signal(ArietCue.nose);
      return true;
    }
    return false;
  }

  bool _cannon() {
    final origin = cannonMuzzle;
    if (rounds.length >= roundLimit ||
        !rig.barrelClear(2, rig.cannonYaw, recoil: cannonRecoil) ||
        !clear(rig.cannonSocket, origin, 10) ||
        !clear(origin, origin + unit(rig.cannonYaw) * 12, 10)) {
      return false;
    }
    final aim = _clip(origin, locked, 9);
    final distance = math.min(900.0, math.max(80.0, (aim - origin).distance));
    rounds.add(
      ArietRound(
        origin,
        rig.cannonYaw,
        cannon: true,
        burstAt: origin + unit(rig.cannonYaw) * distance,
      ),
    );
    cannonRecoil = 15;
    cannonFlash = .065;
    totalCannon++;
    signal(ArietCue.cannon);
    return true;
  }

  void _drops(double dt) {
    if (defeated) return;
    for (final d in drops) {
      if (d.aborted || d.activated) continue;
      if (d.origin == null) {
        if (_passStart == null || elapsed - _passStart! < d.releaseAt) continue;
        d.groundOrigin = rig.cargoSocket(d.id - 1);
        d.origin = rig.cargoReleaseSocket(d.id - 1);
        d.age = 0;
        totalDrops++;
        _lastDropAt = elapsed;
        deploymentSpent = totalDrops >= escortQuota;
        signal(ArietCue.release);
      } else {
        d.age += dt;
        if (d.age >= 1.4) {
          d.activated = true;
          if (landingLegal(d.landing, 60)) {
            deploy(d);
            signal(ArietCue.land);
            _impact(d.landing, 85, dust: true);
          } else {
            d.aborted = true;
          }
        }
      }
    }
  }

  void _impact(
    Offset p,
    double radius, {
    bool dust = false,
    bool rocketBlast = false,
  }) {
    if (impacts.length >= 6) impacts.removeAt(0);
    impacts.add(ArietImpact(p, radius, dust: dust, rocketBlast: rocketBlast));
  }

  void _blast(Offset p) {
    signal(ArietCue.impact);
    _impact(p, 70, rocketBlast: true);
    if ((player - p).distance <= 96 && clear(p, player, 0)) {
      hurt(2, 'Ariet cannon');
    }
    for (final m in minions?.call() ?? <WalkerMinion>[]) {
      if ((m.position - p).distance <= 70 + m.radius &&
          clear(p, m.position, 0)) {
        crushMinion?.call(m.id);
      }
    }
  }

  /// Continue keeps encounter identity, reinforcement history and pending
  /// deployments. Hostile rounds/warnings are discarded and resume safely.
  Map<String, dynamic> checkpoint() => {
    'schema': 1,
    'position': [rig.position.dx, rig.position.dy],
    'yaw': rig.yaw,
    'phase': phase.name,
    'clock': clock,
    'elapsed': elapsed,
    'quota': escortQuota,
    'released': totalDrops,
    'lastDrop': _lastDropAt,
    'cycle': _attackCycle,
    'random': random.state,
    'crash': [crashEnd.dx, crashEnd.dy],
    'drops': [
      for (final d in drops)
        {
          'id': d.id,
          'landing': [d.landing.dx, d.landing.dy],
          'origin': d.origin == null ? null : [d.origin!.dx, d.origin!.dy],
          'ground': d.groundOrigin == null
              ? null
              : [d.groundOrigin!.dx, d.groundOrigin!.dy],
          'age': d.age,
          'activated': d.activated,
          'aborted': d.aborted,
        },
    ],
  };

  static bool validCheckpoint(dynamic value) {
    bool number(dynamic v, double lo, double hi) =>
        v is num && v.isFinite && v >= lo && v <= hi;
    bool point(dynamic p) =>
        p is List &&
        p.length == 2 &&
        p.every((v) => number(v, -100000, 100000));
    try {
      final m = value as Map;
      if (m['schema'] != 1 ||
          !point(m['position']) ||
          !point(m['crash']) ||
          !number(m['yaw'], -1e9, 1e9) ||
          !number(m['clock'], 0, 1e9) ||
          !number(m['elapsed'], 0, 1e9) ||
          !number(m['lastDrop'], -1000, m['elapsed'].toDouble()) ||
          m['quota'] is! int ||
          !number(m['quota'], 0, 2) ||
          m['released'] is! int ||
          !number(m['released'], 0, m['quota'].toDouble()) ||
          m['cycle'] is! int ||
          !number(m['cycle'], 0, 1e9) ||
          m['random'] is! int ||
          !number(m['random'], 0, 0x7fffffff.toDouble()) ||
          !ArietPhase.values.any((p) => p.name == m['phase'])) {
        return false;
      }
      final ds = m['drops'] as List;
      if (ds.length > 2) return false;
      final ids = <int>{};
      for (final raw in ds) {
        final d = raw as Map;
        if (d['id'] is! int ||
            !number(d['id'], 1, m['quota'].toDouble()) ||
            !ids.add(d['id'] as int) ||
            !point(d['landing']) ||
            (d['origin'] != null && !point(d['origin'])) ||
            (d['ground'] != null && !point(d['ground'])) ||
            ((d['origin'] == null) != (d['ground'] == null)) ||
            !number(d['age'], -1, 2) ||
            d['activated'] is! bool ||
            d['aborted'] is! bool) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void restore(Map<String, dynamic> m) {
    if (!validCheckpoint(m)) throw const FormatException('Invalid Ariet state');
    Offset point(dynamic p) =>
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
    rig.position = point(m['position']);
    rig.yaw = rig.desiredYaw = (m['yaw'] as num).toDouble();
    elapsed = (m['elapsed'] as num).toDouble();
    escortQuota = m['quota'] as int;
    totalDrops = m['released'] as int;
    deploymentSpent = totalDrops >= escortQuota;
    _lastDropAt = (m['lastDrop'] as num).toDouble();
    _attackCycle = m['cycle'] as int;
    random.state = m['random'] as int;
    crashEnd = point(m['crash']);
    final savedPhase = ArietPhase.values.byName(m['phase'] as String);
    phase = savedPhase.index >= ArietPhase.failing.index
        ? savedPhase
        : ArietPhase.navigate;
    clock = defeated ? (m['clock'] as num).toDouble() : 0;
    grace = 1.5;
    drops.clear();
    for (final raw in m['drops'] as List) {
      final d = raw as Map;
      if (d['origin'] == null) continue;
      final item = ArietDrop(d['id'] as int, point(d['landing']), .95)
        ..age = (d['age'] as num).toDouble()
        ..activated = d['activated'] as bool
        ..aborted = d['aborted'] as bool;
      if (d['origin'] != null) {
        item.origin = point(d['origin']);
        item.groundOrigin = point(d['ground']);
      } else {
        item.aborted = true;
      }
      drops.add(item);
    }
    rig.enginesRunning = !defeated;
  }

  void _rounds(double dt) {
    for (final r in rounds.toList()) {
      r.age += dt;
      if (r.seeker && r.age >= .6 && r.travel >= 100) {
        r.heading = ArietRig.turn(
          r.heading,
          heading(player - r.position),
          1.8 * dt,
        );
      }
      final from = r.position;
      final timedShell = r.flakPacket || (r.cannon && r.burstAt != null);
      final step = timedShell
          ? math.min(r.speed * dt, (r.burstAt! - from).distance)
          : math.min(r.speed * dt, math.max(0.0, 1600 - r.travel));
      final desired = from + unit(r.heading) * step;
      final airburst = timedShell && (desired - r.burstAt!).distance < .01;
      var end = desired;
      var wall = !clear(from, desired, r.radius);
      if (wall) {
        var lo = 0.0, hi = 1.0;
        for (var i = 0; i < 12; i++) {
          final mid = (lo + hi) / 2;
          if (clear(from, Offset.lerp(from, desired, mid)!, r.radius)) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        end = Offset.lerp(from, desired, lo)!;
      }
      var distance = (end - from).distance;
      WalkerMinion? hit;
      for (final m
          in r.seeker
              ? <WalkerMinion>[]
              : minions?.call() ?? <WalkerMinion>[]) {
        final at = TargetCapsule(
          m.position,
          m.position,
          m.radius,
        ).contact(from, end, padding: r.radius);
        if (at != null && at <= distance) {
          hit = m;
          distance = at;
        }
      }
      final playerAt = TargetCapsule(
        player,
        player,
        26,
      ).contact(from, end, padding: r.radius);
      final touch = playerAt != null && playerAt <= distance;
      if (touch) distance = playerAt;
      end = from + unit(r.heading) * distance;
      r.position = end;
      r.travel += distance;
      if (touch || hit != null || wall || airburst) {
        r.removed = true;
        rounds.remove(r);
        if (r.flakPacket) {
          _impact(end, 55);
          signal(ArietCue.impact);
          if (!_flakHit &&
              (player - end).distance <= 81 &&
              clear(end, player, 0)) {
            _flakHit = hurt(1, 'Ariet flak');
          }
          for (final spread in [-.65, 0.0, .65]) {
            rounds.add(
              ArietRound(end, r.heading + spread, fragment: true, pass: r.pass),
            );
          }
        } else if (r.seeker) {
          _impact(end, 90, rocketBlast: true);
          signal(ArietCue.impact);
          if ((player - end).distance <= 116 && clear(end, player, 0)) {
            hurt(1, 'Ariet seeker');
          }
          for (final m in minions?.call() ?? <WalkerMinion>[]) {
            if ((m.position - end).distance <= 90 + m.radius &&
                clear(end, m.position, 0)) {
              crushMinion?.call(m.id);
            }
          }
        } else if (r.cannon) {
          _blast(end);
        } else if (touch && r.fragment) {
          if (!_flakHit) _flakHit = hurt(1, 'Ariet flak');
        } else if (touch) {
          if (elapsed >= _gunHitReady) {
            if (hurt(
              1,
              r.owner == 0 ? 'Ariet strafing run' : 'Walker escort',
            )) {
              _gunHitReady = elapsed + .5;
            }
          }
        } else if (hit != null) {
          crushMinion?.call(hit.id);
        }
        rounds.remove(r);
      } else if (r.age >
              (r.seeker
                  ? 3.5
                  : r.fragment
                  ? .65
                  : r.cannon
                  ? 2.2
                  : 1.6) ||
          r.travel > 1600) {
        r.removed = true;
        if (r.cannon) _blast(r.position);
        if (r.seeker) {
          _impact(r.position, 70, rocketBlast: true);
          signal(ArietCue.intercept);
        }
        rounds.remove(r);
      }
    }
  }
}
