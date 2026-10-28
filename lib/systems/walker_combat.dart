import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/walker_rig.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/systems/player_hurt_geometry.dart';

enum WalkerPhase {
  incoming,
  descending,
  landing,
  approach,
  burstLock,
  burstFire,
  rotaryLock,
  rotaryFire,
  cannonLock,
  cannonFire,
  rocketLock,
  rocketFire,
  chargeLock,
  charge,
  brake,
  recovery,
  failing,
  detonation,
  wreck,
  complete,
}

enum WalkerRoundKind { rotary, cannon, rocket }

enum WalkerSignal {
  rotary,
  cannon,
  rocket,
  spool,
  charge,
  land,
  blast,
  fatal,
  complete,
}

typedef WalkerSight = bool Function(Offset from, Offset to, double radius);

class WalkerMinion {
  const WalkerMinion(this.id, this.position, this.radius);
  final String id;
  final Offset position;
  final double radius;
}

typedef WalkerHurt = void Function(int damage, String cause);

class WalkerRound {
  WalkerRound(
    this.kind,
    this.position,
    this.heading, {
    required this.aim,
    this.id = 0,
  });
  final int id;
  final WalkerRoundKind kind;
  Offset position, aim;
  double heading, age = 0, distance = 0;
  bool removed = false;
  double get radius => switch (kind) {
    WalkerRoundKind.rotary => 5,
    WalkerRoundKind.cannon => 10,
    WalkerRoundKind.rocket => 12,
  };
  double get speed => switch (kind) {
    WalkerRoundKind.rotary => 650,
    WalkerRoundKind.cannon => 650,
    WalkerRoundKind.rocket => age < .6 ? 220 : 390,
  };
  bool get pursuing =>
      kind == WalkerRoundKind.rocket && age >= .6 && distance >= 100;
}

class WalkerBlast {
  WalkerBlast(
    this.position,
    this.radius, {
    this.death = false,
    this.landing = false,
  });
  final Offset position;
  final double radius;
  final bool death, landing;
  double age = 0;
}

/// Trial encounter controller. All release/contact/state events consume active
/// fixed-step time. Native integration supplies actual occupancy and solid cover.
class WalkerCombat {
  WalkerCombat({
    required this.rig,
    required this.clear,
    required this.hurt,
    required this.signal,
    this.moveCharge,
    this.steer,
    this.minions,
    this.crushMinion,
    int seed = 427,
  }) : _choices = RunRandom(seed),
       _recoilRandom = RunRandom(seed ^ 0x5a17) {
    rig.trackTurret = false;
  }
  static const bodyRadius = 88.0, deathRadius = 330.0, rushRadius = 180.0;
  static const roundLimit = 48;
  static const visualOffset = Offset(0, 61.6);
  final WalkerRig rig;
  final WalkerSight clear;
  final Iterable<WalkerMinion> Function()? minions;
  final void Function(String id)? crushMinion;
  final WalkerHurt hurt;
  final void Function(WalkerSignal event) signal;
  final WalkerMoveResolver? moveCharge;
  final Offset Function(Offset desired, double dt)? steer;
  final RunRandom _choices, _recoilRandom;
  WalkerPhase? _lastAttack;
  final _attackAge = <WalkerPhase, int>{};
  double recoveryDuration = 1.0;
  bool attackEnraged = false;
  int rocketSpent = 0;
  double _nextGunRelease = 0;
  int get burstCount => attackEnraged ? 10 : 8;
  int get burstSize => attackEnraged ? 4 : 3;
  int get rotaryCount => attackEnraged ? 96 : 72;
  double get rotarySpacing => attackEnraged ? .05 : .06;
  int get cannonCount => attackEnraged ? 10 : 8;
  double get cannonSpacing => attackEnraged ? .23 : .28;
  final rounds = <WalkerRound>[];
  final blasts = <WalkerBlast>[];
  WalkerPhase phase = WalkerPhase.incoming;
  double clock = 0, elapsed = 0, accumulator = 0;
  double cannonYaw = 0, rackYaw = 0;
  double rotaryRecoil = 0, cannonRecoil = 0, rotaryFlash = 0, cannonFlash = 0;
  double barrelSpin = 0, contactCooldown = 0;
  double rotaryKick = 0, cannonKick = 0, rotaryOffset = 0, cannonOffset = 0;
  double barrelHeading(bool cannon) =>
      (cannon ? cannonYaw : rig.turretYaw) + (cannon ? cannonKick : rotaryKick);
  int sequence = 0, released = 0, shots = 0, detonations = 0;
  bool enraged = false, paused = false, _chargeHit = false;
  Offset player = Offset.zero, playerVelocity = Offset.zero;
  Offset locked = Offset.zero, chargeDirection = const Offset(1, 0);
  double chargeDistance = 0, chargeReach = 720;
  double _rushCooldown = 0;
  bool pursuing = false, _repositioning = false;
  bool get defeated => phase.index >= WalkerPhase.failing.index;
  bool get finished => phase == WalkerPhase.complete;
  bool get vulnerable => phase.index >= WalkerPhase.approach.index && !defeated;
  bool get deployed => phase.index >= WalkerPhase.landing.index;
  bool get firing =>
      phase == WalkerPhase.burstFire ||
      phase == WalkerPhase.rotaryFire ||
      phase == WalkerPhase.cannonFire;
  String get label => switch (phase) {
    WalkerPhase.incoming => 'INCOMING',
    WalkerPhase.descending => 'DEPLOYING',
    WalkerPhase.landing => 'LANDING',
    WalkerPhase.approach => 'ADVANCING',
    WalkerPhase.burstLock => 'ROTARY / BURST LOCK',
    WalkerPhase.burstFire => 'ROTARY / BURSTS',
    WalkerPhase.rotaryLock => 'ROTARY / SPOOL',
    WalkerPhase.rotaryFire => 'ROTARY / SUSTAINED',
    WalkerPhase.cannonLock => 'CANNON / LOCK',
    WalkerPhase.cannonFire => 'CANNON / VOLLEY',
    WalkerPhase.rocketLock => 'ROCKETS / ARMING',
    WalkerPhase.rocketFire => 'ROCKETS / SALVO',
    WalkerPhase.chargeLock => 'THRUSTERS / BRACE',
    WalkerPhase.charge => 'RAM',
    WalkerPhase.brake => 'BRAKING',
    WalkerPhase.recovery => 'RECOVERING',
    WalkerPhase.failing => 'CORE FAILURE / GET CLEAR',
    WalkerPhase.detonation => 'CORE DETONATION',
    WalkerPhase.wreck => 'WRECK',
    WalkerPhase.complete => 'WALKER DESTROYED',
  };
  double get descent => phase == WalkerPhase.incoming
      ? 650
      : phase == WalkerPhase.descending
      ? 650 * math.pow(1 - clock / .9, 2).toDouble().clamp(0, 1)
      : 0;
  Offset pivot(bool cannon) =>
      rig.point(Offset(-12, cannon ? 43 : -43), rig.height + 18).projected +
      visualOffset;
  Offset muzzle(bool cannon) => _gunMuzzle(
    cannon,
    barrelHeading(cannon),
    cannon ? cannonRecoil : rotaryRecoil,
    cannon ? cannonOffset : rotaryOffset,
  );

  Offset _gunMuzzle(bool cannon, double angle, double kickBack, double offset) {
    final direction = unit(angle);
    final base = pivot(cannon) + unit(angle + math.pi / 2) * offset;
    final relative = base - rig.position;
    final along = relative.dx * direction.dx + relative.dy * direction.dy;
    final perpendicular2 = math.max(
      0.0,
      relative.distanceSquared - along * along,
    );
    const clearance = bodyRadius + 13;
    final minimum =
        -along +
        math.sqrt(math.max(0.0, clearance * clearance - perpendicular2));
    return base + direction * math.max(rig.barrelLength - kickBack, minimum);
  }

  Offset get rack =>
      rig.point(const Offset(-48, 0), rig.height + 30).projected + visualOffset;
  static Offset unit(double angle) => Offset(math.cos(angle), math.sin(angle));
  static double heading(Offset delta) => math.atan2(delta.dy, delta.dx);
  static double segmentDistance(Offset p, Offset a, Offset b) {
    final d = b - a;
    final t = d.distanceSquared < 1e-9
        ? 0.0
        : ((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared;
    return (p - (a + d * t.clamp(0, 1))).distance;
  }

  void _enter(WalkerPhase value) {
    final previous = phase;
    if (value == WalkerPhase.recovery) {
      final base = previous == WalkerPhase.brake
          ? 1.2
          : previous == WalkerPhase.rotaryFire
          ? 1.1
          : previous == WalkerPhase.cannonFire
          ? .95
          : .85;
      recoveryDuration = base - (enraged ? .2 : 0) + _choices.nextDouble() * .2;
    }
    phase = value;
    clock = 0;
    released = 0;
    _nextGunRelease = 0;
    if ([
      WalkerPhase.burstLock,
      WalkerPhase.rotaryLock,
      WalkerPhase.cannonLock,
      WalkerPhase.rocketLock,
      WalkerPhase.chargeLock,
    ].contains(value)) {
      attackEnraged = enraged;
    }
    if (value == WalkerPhase.burstLock ||
        value == WalkerPhase.rotaryLock ||
        value == WalkerPhase.cannonLock) {
      // A firing commitment gives aiming to the mounts, unless pursuit is needed.
      rig.desiredYaw = rig.yaw;
      _repositioning = false;
    }
    if (value == WalkerPhase.rocketLock) rocketSpent = 0;
  }

  void beginDestruction() {
    if (defeated) return;
    rounds.clear();
    rig.command = Offset.zero;
    rig.velocity = Offset.zero;
    rig.folded = false;
    rig.braced = true;
    rig.desiredYaw = rig.yaw;
    _enter(WalkerPhase.failing);
    signal(WalkerSignal.fatal);
  }

  void advance(double dt) {
    if (paused || finished || !dt.isFinite || dt <= 0) return;
    accumulator += dt;
    while (accumulator + 1e-10 >= WalkerRig.tick) {
      accumulator -= WalkerRig.tick;
      _step(WalkerRig.tick);
    }
  }

  void _step(double dt) {
    elapsed += dt;
    clock += dt;
    rotaryRecoil = math.max(0, rotaryRecoil - dt * 150);
    cannonRecoil = math.max(0, cannonRecoil - dt * 120);
    rotaryFlash = math.max(0, rotaryFlash - dt);
    cannonFlash = math.max(0, cannonFlash - dt);
    final settle = math.exp(-24 * dt);
    rotaryKick *= settle;
    cannonKick *= settle;
    rotaryOffset *= settle;
    cannonOffset *= settle;
    contactCooldown = math.max(0, contactCooldown - dt);
    _rushCooldown = math.max(0, _rushCooldown - dt);
    for (final blast in blasts) {
      blast.age += dt;
    }
    blasts.removeWhere((b) => b.age > (b.death ? 2.1 : .65));

    // Gun states remain independent of body yaw, including while strafing.
    rig.command = Offset.zero;
    rig.braced =
        phase == WalkerPhase.landing ||
        phase == WalkerPhase.chargeLock ||
        defeated;
    rig.folded = phase == WalkerPhase.charge || phase == WalkerPhase.brake;
    if (!defeated && deployed) {
      final rotaryAim =
          (phase == WalkerPhase.rotaryLock || phase == WalkerPhase.burstLock) &&
              clock > .55
          ? locked
          : player + playerVelocity * .18;
      final reacquiring =
          phase == WalkerPhase.cannonFire &&
          (clock < _nextGunRelease - .12 || clock > _nextGunRelease + .20);
      if (reacquiring) locked = player + playerVelocity * .3;
      final cannonAim = phase == WalkerPhase.cannonLock && clock < .7
          ? player + playerVelocity * .35
          : locked;
      rig.turretYaw = WalkerRig.turn(
        rig.turretYaw,
        heading(rotaryAim - pivot(false)),
        3.6 * dt,
      );
      cannonYaw = WalkerRig.turn(
        cannonYaw,
        heading(cannonAim - pivot(true)),
        2.8 * dt,
      );
      rackYaw = WalkerRig.turn(rackYaw, heading(player - rack), 2.4 * dt);
      barrelSpin +=
          dt *
          (phase == WalkerPhase.burstLock ||
                  phase == WalkerPhase.burstFire ||
                  phase == WalkerPhase.rotaryLock ||
                  phase == WalkerPhase.rotaryFire
              ? 28
              : 3);
    }
    rig.turretPitch = 0;

    switch (phase) {
      case WalkerPhase.incoming:
        if (clock >= 1.3) _enter(WalkerPhase.descending);
      case WalkerPhase.descending:
        if (clock >= .9) {
          _enter(WalkerPhase.landing);
          signal(WalkerSignal.land);
        }
      case WalkerPhase.landing:
        if (clock >= .8) _enter(WalkerPhase.approach);
      case WalkerPhase.approach:
        final distance = (player - rig.position).distance;
        _combatStride(150);
        if (clock >= .25 && clear(rig.position, player, 0)) {
          locked = player + playerVelocity * .35;
          if (distance >= 780 && _rushCooldown == 0) {
            // Close an escaped player's gap before returning to the arsenal.
            _enter(WalkerPhase.chargeLock);
            signal(WalkerSignal.spool);
          } else if (distance < 1100) {
            _enter(_chooseAttack(distance));
            sequence++;
            signal(WalkerSignal.spool);
          }
        }
      case WalkerPhase.burstLock:
        _combatStride(100);
        if (clock < .55) locked = player + playerVelocity * .18;
        if (clock >= .75) _enter(WalkerPhase.burstFire);
      case WalkerPhase.burstFire:
        _combatStride(100);
        if (released < burstCount * burstSize && clock >= _nextGunRelease) {
          if (_fire(WalkerRoundKind.rotary)) {
            released++;
            _nextGunRelease =
                clock +
                (released % burstSize == 0
                    ? (attackEnraged ? .19 : .24)
                    : (attackEnraged ? .06 : .075));
          } else {
            _nextGunRelease = clock + .04;
          }
        }
        if ((released >= burstCount * burstSize && clock >= _nextGunRelease) ||
            clock >= 6) {
          _enter(WalkerPhase.rotaryLock);
          signal(WalkerSignal.spool);
        }
      case WalkerPhase.rotaryLock:
        _combatStride(100);
        if (clock < .55) locked = player + playerVelocity * .18;
        if (clock >= .55) _enter(WalkerPhase.rotaryFire);
      case WalkerPhase.rotaryFire:
        _combatStride(100);
        if (released < rotaryCount && clock >= _nextGunRelease) {
          if (_fire(WalkerRoundKind.rotary)) {
            released++;
            _nextGunRelease = clock + rotarySpacing;
          } else {
            _nextGunRelease = clock + .04;
          }
        }
        if ((released >= rotaryCount && clock >= _nextGunRelease + .12) ||
            clock >= rotaryCount * rotarySpacing + .65) {
          _enter(WalkerPhase.recovery);
        }
      case WalkerPhase.cannonLock:
        _combatStride(80);
        if (clock < .7) locked = player + playerVelocity * .35;
        if (clock >= .85) _enter(WalkerPhase.cannonFire);
      case WalkerPhase.cannonFire:
        _combatStride(80);
        if (released < cannonCount && clock >= _nextGunRelease) {
          if (_fire(WalkerRoundKind.cannon)) {
            released++;
            _nextGunRelease = clock + cannonSpacing;
          }
        }
        if ((released >= cannonCount && clock >= _nextGunRelease + .12) ||
            clock >= cannonCount * cannonSpacing + .65) {
          _enter(WalkerPhase.recovery);
        }
      case WalkerPhase.rocketLock:
        _combatStride(100);
        if (clock >= 1.1 &&
            WalkerRig.difference(rackYaw, heading(player - rack)).abs() < .18) {
          _enter(WalkerPhase.rocketFire);
        }
      case WalkerPhase.rocketFire:
        _combatStride(100);
        final count = attackEnraged ? 8 : 6;
        if (released < count && clock >= _nextGunRelease) {
          // The visible roof launcher swivels toward the player and ejects
          // forward. Preserve the straight launch before bounded homing.
          final a = rackYaw + (released - (count - 1) / 2) * .12;
          final origin = rack + unit(a) * 44;
          if (WalkerRig.difference(rackYaw, heading(player - rack)).abs() <
                  .18 &&
              clear(rack, origin, 12) &&
              rounds.length < roundLimit) {
            rounds.add(
              WalkerRound(
                WalkerRoundKind.rocket,
                origin,
                a,
                aim: player,
                id: shots + 1,
              ),
            );
            shots++;
            rocketSpent++;
            signal(WalkerSignal.rocket);
            released++;
            _nextGunRelease = clock + .18;
          } else {
            _nextGunRelease = clock + .04;
          }
        }
        if (clock >= count * .18 + .9) _enter(WalkerPhase.recovery);
      case WalkerPhase.chargeLock:
        if (clock < .95) {
          locked = player + playerVelocity * .3;
          chargeDirection = (locked - rig.position).distance < 1
              ? unit(rig.yaw)
              : (locked - rig.position) / (locked - rig.position).distance;
        }
        rig.desiredYaw = heading(chargeDirection);
        if (clock >= 1.45 &&
            WalkerRig.difference(rig.yaw, rig.desiredYaw).abs() < .15) {
          _chargeHit = false;
          chargeDistance = 0;
          // Carry through the committed intercept instead of braking short of
          // a distant target. The final half-second warning stays fixed.
          chargeReach = ((locked - rig.position).distance + 180).clamp(
            720,
            1200,
          );
          _rushCooldown = 10;
          _enter(WalkerPhase.charge);
          signal(WalkerSignal.charge);
        }
      case WalkerPhase.charge:
        final speed = 400.0 + 700.0 * (clock / .25).clamp(0.0, 1.0);
        final before = rig.position,
            desired = before + chargeDirection * speed * dt;
        final next = moveCharge?.call(before, desired) ?? desired;
        chargeDistance += (next - before).distance;
        rig.carryTo(next);
        _ramContact(before, next);
        if ((next - desired).distance > 2 ||
            chargeDistance >= chargeReach ||
            clock > 1.4) {
          _enter(WalkerPhase.brake);
        }
      case WalkerPhase.brake:
        // Folded feet drag deliberately during bounded rocket braking.
        final before = rig.position;
        final desired =
            before + chargeDirection * (1 - clock / .25).clamp(0, 1) * 230 * dt;
        final next = moveCharge?.call(before, desired) ?? desired;
        rig.carryTo(next);
        _ramContact(before, next);
        if (clock >= .3) {
          if (blasts.length >= 12) blasts.removeAt(0);
          blasts.add(WalkerBlast(rig.position, rushRadius, landing: true));
          if (!_chargeHit &&
              (player - rig.position).distance <=
                  rushRadius + PlayerHurtGeometry.radius &&
              clear(rig.position, player, 0)) {
            _chargeHit = true;
            contactCooldown = 1.25;
            hurt(2, 'Walker rush landing');
          }
          _clearMinions(rig.position, rushRadius);
          signal(WalkerSignal.land);
          _enter(WalkerPhase.recovery);
        }
      case WalkerPhase.recovery:
        _combatStride(80);
        // Resume gun pressure while the spaced rockets can still be intercepted.
        // The full burst/gun/cannon sequence separates successive rocket salvos.
        if (clock >= recoveryDuration) {
          _enter(WalkerPhase.approach);
        }
      case WalkerPhase.failing:
        if (released < 4 && clock >= (released + 1) * .5) {
          released++;
          signal(WalkerSignal.spool);
        }
        if (clock >= 2.6) {
          _enter(WalkerPhase.detonation);
          detonations++;
          _blast(rig.position, deathRadius, 3, death: true);
        }
      case WalkerPhase.detonation:
        if (clock >= 1.5) _enter(WalkerPhase.wreck);
      case WalkerPhase.wreck:
        if (clock >= 1.0) {
          _enter(WalkerPhase.complete);
          signal(WalkerSignal.complete);
        }
      case WalkerPhase.complete:
        break;
    }
    if (phase != WalkerPhase.incoming && phase != WalkerPhase.descending) {
      rig.advance(dt);
    }
    if (vulnerable &&
        phase != WalkerPhase.charge &&
        phase != WalkerPhase.brake &&
        (player - rig.position).distance < bodyRadius + 22 &&
        contactCooldown == 0) {
      contactCooldown = 1;
      hurt(1, 'Walker body');
    }
    if (!defeated) _advanceRounds(dt);
  }

  WalkerPhase _chooseAttack(double distance) {
    final weights = <WalkerPhase, double>{
      WalkerPhase.burstLock: distance < 550 ? 1.4 : 1,
      WalkerPhase.cannonLock: distance >= 400 ? 1.3 : .6,
      if (!rounds.any((r) => r.kind == WalkerRoundKind.rocket))
        WalkerPhase.rocketLock: distance > 550 ? 1.2 : .65,
      if (_rushCooldown == 0 && distance > 320) WalkerPhase.chargeLock: .7,
    }..remove(_lastAttack);
    // Avoid both a rigid rotation and starving an available attack forever.
    final overdue = weights.keys
        .where((p) => (_attackAge[p] ?? 0) >= 3)
        .toList();
    if (overdue.isNotEmpty) weights.removeWhere((p, _) => !overdue.contains(p));
    var roll =
        _choices.nextDouble() * weights.values.fold<double>(0, (a, b) => a + b);
    var choice = weights.keys.last;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll <= 0) {
        choice = entry.key;
        break;
      }
    }
    for (final p in [
      WalkerPhase.burstLock,
      WalkerPhase.cannonLock,
      WalkerPhase.rocketLock,
      WalkerPhase.chargeLock,
    ]) {
      _attackAge[p] = p == choice ? 0 : (_attackAge[p] ?? 0) + 1;
    }
    _lastAttack = choice;
    return choice;
  }

  void _combatStride(double speed) {
    final delta = player - rig.position;
    if (delta.distance < 1) return;
    final toward = delta / delta.distance;
    final distance = delta.distance;
    final side = Offset(-toward.dy, toward.dx) * (sequence.isEven ? 1 : -1);
    // Hysteresis separates deliberate pursuit from an anchored firing stance.
    if (distance > 680) pursuing = true;
    if (distance < 480 && pursuing) {
      pursuing = false;
      rig.desiredYaw = rig.yaw;
    }
    final aiming =
        firing ||
        phase == WalkerPhase.burstLock ||
        phase == WalkerPhase.rotaryLock ||
        phase == WalkerPhase.cannonLock ||
        phase == WalkerPhase.rocketLock ||
        phase == WalkerPhase.rocketFire;
    if (pursuing) {
      _repositioning = false;
      rig.desiredYaw = heading(toward);
    } else if (!aiming) {
      if (!_repositioning &&
          WalkerRig.difference(heading(toward), rig.yaw).abs() > 1.7) {
        _repositioning = true;
        rig.desiredYaw = heading(toward);
      }
      if (WalkerRig.difference(rig.desiredYaw, rig.yaw).abs() < .12) {
        _repositioning = false;
      }
    }
    final forward = pursuing
        ? ((distance - 420) * 2).clamp(0.0, enraged ? 260.0 : 230.0)
        : distance < 260
        ? -140.0
        : 0.0;
    final lateral = pursuing || (!aiming && _repositioning) ? speed : 0.0;
    rig.command = WalkerRig.limit(
      toward * forward + side * lateral,
      rig.maxSpeed,
    );
    if (rig.command.distance > 0) {
      rig.command = steer?.call(rig.command, WalkerRig.tick) ?? rig.command;
    }
  }

  void _ramContact(Offset before, Offset next) {
    if (!_chargeHit &&
        segmentDistance(player, before, next) <=
            bodyRadius + PlayerHurtGeometry.radius &&
        clear(before, player, 0)) {
      _chargeHit = true;
      contactCooldown = 1.25;
      hurt(2, 'Walker rocket ram');
    }
  }

  /// Predicted stopping point, clipped against the same solid/floor sight test.
  Offset? presentationLanding;
  Offset get rushLanding {
    if (presentationLanding != null) return presentationLanding!;
    final remaining = phase == WalkerPhase.chargeLock
        ? ((locked - rig.position).distance + 180).clamp(720.0, 1200.0)
        : math.max(0.0, chargeReach - chargeDistance);
    final endpoint = rig.position + chargeDirection * (remaining + 28);
    var lo = 0.0, hi = 1.0;
    if (clear(rig.position, endpoint, bodyRadius)) return endpoint;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (clear(
        rig.position,
        Offset.lerp(rig.position, endpoint, mid)!,
        bodyRadius,
      )) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return Offset.lerp(rig.position, endpoint, lo)!;
  }

  /// A player hit detonates one live rocket; interception cannot reward kills
  /// or repeat after removal. The normal hostile blast still threatens nearby players.
  bool interceptRocket(WalkerRound round) {
    if (paused ||
        defeated ||
        round.removed ||
        round.kind != WalkerRoundKind.rocket ||
        !rounds.contains(round)) {
      return false;
    }
    round.removed = true;
    rounds.remove(round);
    _blast(round.position, 110, 2);
    return true;
  }

  bool _fire(WalkerRoundKind kind) {
    final cannon = kind == WalkerRoundKind.cannon;
    final from = muzzle(cannon), a = cannon ? cannonYaw : rig.turretYaw;
    final aim = cannon ? locked : player + playerVelocity * .18;
    // Elevated barrels clear their own roof. Their tips must also be outside
    // the body and every external cover sweep before releasing anything.
    if ((player - rig.position).distance < 180 ||
        rounds.length >= roundLimit ||
        (from - rig.position).distance < bodyRadius + 12 ||
        !clear(pivot(cannon), from, cannon ? 10 : 5) ||
        !clear(from, aim, cannon ? 10 : 5) ||
        WalkerRig.difference(a, heading(aim - from)).abs() > .13) {
      return false;
    }
    final spread = cannon
        ? .8
        : phase == WalkerPhase.burstFire
        ? 1.5
        : 1.8 + 1.2 * (released / 24).clamp(0.0, 1.0);
    final kick = (_recoilRandom.nextDouble() * 2 - 1) * spread * math.pi / 180;
    final offset = (_recoilRandom.nextDouble() * 2 - 1) * (cannon ? 1.5 : 3.0);
    final shotHeading = a + kick;
    final origin = _gunMuzzle(cannon, shotHeading, cannon ? 18 : 7, offset);
    if ((origin - rig.position).distance < bodyRadius + 12 ||
        !clear(pivot(cannon), origin, cannon ? 10 : 5)) {
      return false;
    }
    if (cannon) {
      cannonKick = kick;
      cannonOffset = offset;
    } else {
      rotaryKick = kick;
      rotaryOffset = offset;
    }
    rounds.add(WalkerRound(kind, origin, shotHeading, aim: aim, id: shots + 1));
    shots++;
    if (cannon) {
      cannonRecoil = 18;
      cannonFlash = .08;
      signal(WalkerSignal.cannon);
    } else {
      rotaryRecoil = 7;
      rotaryFlash = .05;
      signal(WalkerSignal.rotary);
    }
    return true;
  }

  void _advanceRounds(double dt) {
    for (final round in rounds) {
      final before = round.position;
      round.age += dt;
      if (round.pursuing && clear(before, player, 0)) {
        round.heading = WalkerRig.turn(
          round.heading,
          heading(player - before),
          1.8 * dt,
        );
      }
      final next = before + unit(round.heading) * round.speed * dt;
      round.distance += (next - before).distance;
      if (!clear(before, next, round.radius)) {
        // Binary clip at first solid contact; never burst beyond the wall.
        var lo = 0.0, hi = 1.0;
        for (var i = 0; i < 12; i++) {
          final mid = (lo + hi) / 2;
          if (clear(before, Offset.lerp(before, next, mid)!, round.radius)) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        round.position = Offset.lerp(before, next, lo)!;
        round.removed = true;
      } else {
        round.position = next;
        double contact(Offset center, double radius) {
          final delta = next - before, relative = center - before;
          final length2 = delta.distanceSquared;
          if (relative.distanceSquared <= radius * radius) return 0;
          if (length2 < 1e-12) return double.infinity;
          final projection = relative.dx * delta.dx + relative.dy * delta.dy;
          final perpendicular =
              relative.distanceSquared - projection * projection / length2;
          if (perpendicular > radius * radius) return double.infinity;
          final t =
              (projection -
                  math.sqrt(
                    math.max(0, (radius * radius - perpendicular) * length2),
                  )) /
              length2;
          return t >= 0 && t <= 1 ? t : double.infinity;
        }

        var first = contact(player, round.radius + PlayerHurtGeometry.radius);
        WalkerMinion? minion;
        if (round.kind != WalkerRoundKind.rocket) {
          for (final m in minions?.call().toList() ?? <WalkerMinion>[]) {
            final t = contact(m.position, round.radius + m.radius);
            if (t < first && clear(before, m.position, 0)) {
              first = t;
              minion = m;
            }
          }
        }
        if (first.isFinite) {
          round.position = Offset.lerp(before, next, first)!;
          round.removed = true;
          if (round.kind == WalkerRoundKind.rotary) {
            if (minion != null) {
              crushMinion?.call(minion.id);
            } else {
              hurt(1, 'Walker rotary gun');
            }
          }
        }
      }
      final maxDistance = switch (round.kind) {
        WalkerRoundKind.rotary => 1300.0,
        WalkerRoundKind.cannon => 1800.0,
        WalkerRoundKind.rocket => 2600.0,
      };
      final expired = round.age >= 5 || round.distance > maxDistance;
      if (expired) round.removed = true;
      if (round.removed && !expired && round.kind != WalkerRoundKind.rotary) {
        _blast(
          round.position,
          round.kind == WalkerRoundKind.rocket ? 110 : 85,
          2,
        );
      }
    }
    rounds.removeWhere((r) => r.removed);
  }

  void _blast(Offset at, double radius, int damage, {bool death = false}) {
    if (blasts.length < 12) blasts.add(WalkerBlast(at, radius, death: death));
    if ((player - at).distance <= radius + PlayerHurtGeometry.radius &&
        clear(at, player, 0)) {
      hurt(damage, death ? 'Walker core detonation' : 'Walker ordnance');
    }
    _clearMinions(at, radius);
    signal(WalkerSignal.blast);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'nextRelease': _nextGunRelease,
    'phase': phase.name,
    'rig': rig.toJson(),
    'player': [player.dx, player.dy],
    'playerVelocity': [playerVelocity.dx, playerVelocity.dy],
    'locked': [locked.dx, locked.dy],
    'chargeDirection': [chargeDirection.dx, chargeDirection.dy],
    'choiceSeed': _choices.state,
    'recoilSeed': _recoilRandom.state,
    'rushCooldown': _rushCooldown,
    'chargeHit': _chargeHit,
    'repositioning': _repositioning,
    'lastAttack': _lastAttack?.name,
    'attackAge': {for (final e in _attackAge.entries) e.key.name: e.value},
    'clock': clock,
    'elapsed': elapsed,
    'accumulator': accumulator,
    'cannonYaw': cannonYaw,
    'rackYaw': rackYaw,
    'rotaryRecoil': rotaryRecoil,
    'cannonRecoil': cannonRecoil,
    'rotaryFlash': rotaryFlash,
    'cannonFlash': cannonFlash,
    'rotaryKick': rotaryKick,
    'cannonKick': cannonKick,
    'rotaryOffset': rotaryOffset,
    'cannonOffset': cannonOffset,
    'barrelSpin': barrelSpin,
    'contactCooldown': contactCooldown,
    'chargeDistance': chargeDistance,
    'chargeReach': chargeReach,
    'recoveryDuration': recoveryDuration,
    'rocketSpent': rocketSpent,
    'sequence': sequence,
    'released': released,
    'shots': shots,
    'detonations': detonations,
    'attackEnraged': attackEnraged,
    'enraged': enraged,
    'pursuing': pursuing,
    'rounds': [
      for (final r in rounds)
        {
          'id': r.id,
          'kind': r.kind.name,
          'position': [r.position.dx, r.position.dy],
          'aim': [r.aim.dx, r.aim.dy],
          'heading': r.heading,
          'age': r.age,
          'distance': r.distance,
        },
    ],
    'blasts': [
      for (final b in blasts)
        {
          'position': [b.position.dx, b.position.dy],
          'radius': b.radius,
          'death': b.death,
          'landing': b.landing,
          'age': b.age,
        },
    ],
  };

  void restore(Map<String, dynamic> data) {
    double n(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 4e9) {
        throw const FormatException('Invalid Walker state');
      }
      return value.toDouble();
    }

    Offset point(dynamic value) {
      final p = value as List;
      if (p.length != 2) throw const FormatException('Invalid Walker point');
      return Offset(n(p[0]), n(p[1]));
    }

    if (data['version'] != 1) {
      throw const FormatException('Invalid Walker version');
    }
    phase = WalkerPhase.values.byName(data['phase'] as String);
    _nextGunRelease = n(data['nextRelease']);
    rig.restore(Map<String, dynamic>.from(data['rig'] as Map));
    player = point(data['player']);
    playerVelocity = point(data['playerVelocity']);
    locked = point(data['locked']);
    chargeDirection = point(data['chargeDirection']);
    _choices.state = n(data['choiceSeed']).toInt();
    _recoilRandom.state = n(data['recoilSeed']).toInt();
    _rushCooldown = n(data['rushCooldown']);
    _chargeHit = data['chargeHit'] == true;
    _repositioning = data['repositioning'] == true;
    _lastAttack = data['lastAttack'] == null
        ? null
        : WalkerPhase.values.byName(data['lastAttack'] as String);
    _attackAge.clear();
    for (final e in (data['attackAge'] as Map).entries) {
      _attackAge[WalkerPhase.values.byName(e.key as String)] = n(e.value)
          .toInt();
    }
    clock = n(data['clock']);
    elapsed = n(data['elapsed']);
    accumulator = n(data['accumulator']);
    cannonYaw = n(data['cannonYaw']);
    rackYaw = n(data['rackYaw']);
    rotaryRecoil = n(data['rotaryRecoil']);
    cannonRecoil = n(data['cannonRecoil']);
    rotaryFlash = n(data['rotaryFlash']);
    cannonFlash = n(data['cannonFlash']);
    rotaryKick = n(data['rotaryKick']);
    cannonKick = n(data['cannonKick']);
    rotaryOffset = n(data['rotaryOffset']);
    cannonOffset = n(data['cannonOffset']);
    barrelSpin = n(data['barrelSpin']);
    contactCooldown = n(data['contactCooldown']);
    chargeDistance = n(data['chargeDistance']);
    chargeReach = n(data['chargeReach']);
    recoveryDuration = n(data['recoveryDuration']);
    rocketSpent = n(data['rocketSpent']).toInt();
    sequence = n(data['sequence']).toInt();
    released = n(data['released']).toInt();
    shots = n(data['shots']).toInt();
    detonations = n(data['detonations']).toInt();
    attackEnraged = data['attackEnraged'] == true;
    enraged = data['enraged'] == true;
    pursuing = data['pursuing'] == true;
    final savedRounds = data['rounds'] as List,
        savedBlasts = data['blasts'] as List;
    if (savedRounds.length > roundLimit ||
        savedBlasts.length > 12 ||
        clock < 0 ||
        elapsed < 0 ||
        chargeReach < 0 ||
        chargeReach > 1400 ||
        accumulator < -.000001 ||
        accumulator > WalkerRig.tick + .0001) {
      throw const FormatException('Invalid Walker bounds');
    }
    rounds.clear();
    for (final raw in savedRounds) {
      final r = raw as Map;
      rounds.add(
        WalkerRound(
            WalkerRoundKind.values.byName(r['kind'] as String),
            point(r['position']),
            n(r['heading']),
            aim: point(r['aim']),
            id: n(r['id']).toInt(),
          )
          ..age = n(r['age'])
          ..distance = n(r['distance']),
      );
    }
    blasts.clear();
    for (final raw in savedBlasts) {
      final b = raw as Map;
      final radius = n(b['radius']);
      if (radius <= 0 || radius > deathRadius) {
        throw const FormatException('Invalid Walker blast');
      }
      blasts.add(
        WalkerBlast(
          point(b['position']),
          radius,
          death: b['death'] == true,
          landing: b['landing'] == true,
        )..age = n(b['age']),
      );
    }
  }

  static bool validState(dynamic raw) {
    try {
      if (raw is! Map) return false;
      WalkerCombat(
        rig: WalkerRig(),
        clear: (_, _, _) => true,
        hurt: (_, _) {},
        signal: (_) {},
      ).restore(Map<String, dynamic>.from(raw));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _clearMinions(Offset at, double radius) {
    for (final m in minions?.call().toList() ?? <WalkerMinion>[]) {
      if ((m.position - at).distance <= radius + m.radius &&
          clear(at, m.position, 0)) {
        crushMinion?.call(m.id);
      }
    }
  }
}
