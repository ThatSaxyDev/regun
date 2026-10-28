import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/systems/walker_combat.dart';

void main() {
  WalkerCombat make({
    WalkerSight? clear,
    WalkerHurt? hurt,
    void Function(WalkerSignal)? signal,
    int seed = 427,
  }) => WalkerCombat(
    seed: seed,
    rig: WalkerRig(
      bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
      footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
      barrelLength: 158,
      maxSpeed: 260,
      acceleration: 600,
      turnSpeed: 1.5,
      agileGait: true,
    ),
    clear: clear ?? (_, _, _) => true,
    hurt: hurt ?? (_, _) {},
    signal: signal ?? (_) {},
  );

  test(
    'recoiling muzzle stays outside the hull through every barrel heading',
    () {
      final fight = make();
      for (var heading = 0; heading < 64; heading++) {
        fight.rig.turretYaw = fight.cannonYaw = heading * math.pi / 32;
        fight.rotaryRecoil = 7;
        fight.cannonRecoil = 18;
        fight.rotaryKick = .05;
        fight.cannonKick = -.013;
        fight.rotaryOffset = 3;
        fight.cannonOffset = -1.5;
        for (final cannon in [false, true]) {
          expect(
            (fight.muzzle(cannon) - fight.rig.position).distance,
            greaterThan(WalkerCombat.bodyRadius + 12),
          );
        }
      }
    },
  );

  test('recoil varies actual muzzle and heading within bounded straight-flight limits', () {
    for (final cannon in [false, true]) {
      late WalkerCombat fight;
      final kicks = <double>[], origins = <Offset>[];
      WalkerRound? first;
      fight =
          make(
              signal: (event) {
                if (event !=
                    (cannon ? WalkerSignal.cannon : WalkerSignal.rotary)) {
                  return;
                }
                final shot = fight.rounds.last;
                first ??= shot;
                kicks.add(
                  WalkerRig.difference(
                    shot.heading,
                    cannon ? fight.cannonYaw : fight.rig.turretYaw,
                  ),
                );
                origins.add(shot.position - fight.pivot(cannon));
                expect(
                  (shot.position - fight.muzzle(cannon)).distance,
                  lessThan(1e-8),
                );
                expect(shot.heading, fight.barrelHeading(cannon));
                expect(
                  kicks.last.abs(),
                  lessThanOrEqualTo((cannon ? .8 : 3) * math.pi / 180),
                );
              },
            )
            ..phase = cannon ? WalkerPhase.cannonLock : WalkerPhase.rotaryLock
            ..player = const Offset(600, 0)
            ..locked = const Offset(600, 0);
      for (
        var tick = 0;
        tick < 120 * 8 && fight.phase != WalkerPhase.recovery;
        tick++
      ) {
        fight.advance(1 / 120);
      }
      expect(kicks.length, greaterThan(6));
      expect(kicks.any((v) => v < 0), isTrue);
      expect(kicks.any((v) => v > 0), isTrue);
      expect(origins.toSet().length, origins.length);
      final heading = first!.heading;
      fight.player = const Offset(0, 800);
      fight.advance(.1);
      expect(
        first!.heading,
        heading,
        reason: 'recoil changes launch, never homes bullets',
      );
    }
  });

  test('attack decisions vary with seed and recent history instead of fixed rotation', () {
    final patterns = <String>{};
    for (var seed = 1; seed <= 8; seed++) {
      final fight = make(seed: seed)..player = const Offset(500, 0);
      final choices = <WalkerPhase>[];
      for (var tick = 0; tick < 120 * 90; tick++) {
        final before = fight.phase;
        fight.advance(1 / 120);
        if (before == WalkerPhase.approach && fight.phase != before) {
          choices.add(fight.phase);
        }
      }
      expect(choices.length, greaterThan(5));
      expect(choices.toSet().length, 4);
      for (var i = 1; i < choices.length; i++) {
        expect(choices[i], isNot(choices[i - 1]));
      }
      patterns.add(choices.take(5).join(','));
    }
    expect(patterns.length, greaterThan(3));
  });

  test('completed heavy volley leaves a vulnerable, paused-safe return-fire window', () {
    final fight = make()
      ..phase = WalkerPhase.cannonFire
      ..released = 8
      ..player = const Offset(550, 0);
    fight.advance(.13);
    expect(fight.phase, WalkerPhase.recovery);
    expect(fight.vulnerable, isTrue);
    expect(fight.recoveryDuration, greaterThanOrEqualTo(.95));
    final shots = fight.shots;
    final clock = fight.clock;
    fight.paused = true;
    fight.advance(5);
    expect(fight.clock, clock);
    fight.paused = false;
    fight.advance(fight.recoveryDuration - clock - .02);
    expect(fight.phase, WalkerPhase.recovery);
    expect(fight.shots, shots);
  });

  test(
    'moving target receives complete repeated bursts then sustained escalation',
    () {
      for (final enraged in [false, true]) {
        late WalkerCombat fight;
        final burstTimes = <double>[], sustainedTimes = <double>[];
        fight =
            make(
                signal: (event) {
                  if (event != WalkerSignal.rotary) return;
                  (fight.phase == WalkerPhase.burstFire
                          ? burstTimes
                          : sustainedTimes)
                      .add(fight.elapsed);
                },
              )
              ..phase = WalkerPhase.burstLock
              ..attackEnraged = enraged
              ..enraged = enraged;
        for (
          var tick = 0;
          tick < 120 * 15 && fight.phase != WalkerPhase.recovery;
          tick++
        ) {
          final angle = tick / 120 * .45;
          fight.player = WalkerCombat.unit(angle) * 600;
          fight.playerVelocity =
              Offset(-math.sin(angle), math.cos(angle)) * 270;
          fight.advance(1 / 120);
          expect(
            fight.rounds.length,
            lessThanOrEqualTo(WalkerCombat.roundLimit),
          );
        }
        expect(burstTimes, hasLength(enraged ? 40 : 24));
        expect(sustainedTimes, hasLength(enraged ? 96 : 72));
        expect(sustainedTimes.first, greaterThan(burstTimes.last));
        expect(sustainedTimes.last - sustainedTimes.first, greaterThan(4));
      }
    },
  );

  test(
    'cannon reacquires moving targets after an initially misaligned attempt',
    () {
      for (final enraged in [false, true]) {
        var shots = 0;
        final fight =
            make(
                signal: (event) {
                  if (event == WalkerSignal.cannon) shots++;
                },
              )
              ..phase = WalkerPhase.cannonLock
              ..cannonYaw = math.pi
              ..attackEnraged = enraged
              ..enraged = enraged;
        for (
          var tick = 0;
          tick < 120 * 7 && fight.phase != WalkerPhase.recovery;
          tick++
        ) {
          final angle = tick / 120 * .4;
          fight.player = WalkerCombat.unit(angle) * 600;
          fight.playerVelocity =
              Offset(-math.sin(angle), math.cos(angle)) * 240;
          fight.advance(1 / 120);
        }
        expect(shots, enraged ? 10 : 8);
      }
    },
  );

  test(
    'expired missiles retire silently rather than playing a launch-time blast',
    () {
      var blasts = 0;
      final fight =
          make(
              signal: (event) {
                if (event == WalkerSignal.blast) blasts++;
              },
            )
            ..phase = WalkerPhase.recovery
            ..player = const Offset(1000, 0);
      final rocket = WalkerRound(
        WalkerRoundKind.rocket,
        const Offset(-800, 0),
        math.pi,
        aim: fight.player,
      )..age = 4.999;
      fight.rounds.add(rocket);
      fight.advance(1 / 120);
      expect(rocket.removed, isTrue);
      expect(blasts, 0);
      expect(fight.blasts, isEmpty);
    },
  );

  test(
    'gun tracks in range without chassis turns, then commits to pursuit',
    () {
      final fight = make()
        ..phase = WalkerPhase.rotaryFire
        ..player = WalkerCombat.unit(.8) * 550;
      fight.advance(.7);
      expect(fight.rig.yaw, 0);
      expect(fight.rig.position, Offset.zero);
      expect(fight.rig.turretYaw, greaterThan(.5));
      expect(fight.shots, greaterThan(0));
      fight.player = WalkerCombat.unit(1) * 900;
      fight.advance(.5);
      expect(fight.pursuing, isTrue);
      expect(fight.rig.yaw, greaterThan(.1));
      for (final distance in [650.0, 600.0, 500.0]) {
        fight.player = fight.rig.position + WalkerCombat.unit(1) * distance;
        fight.advance(1 / 120);
        expect(fight.pursuing, isTrue);
      }
      fight.player = fight.rig.position + WalkerCombat.unit(1) * 450;
      fight.advance(1 / 120);
      expect(fight.pursuing, isFalse);
    },
  );

  test(
    'rush sweeps mid-path and braking contact, never stacks landing damage',
    () {
      for (final phase in [WalkerPhase.charge, WalkerPhase.brake]) {
        final hits = <String>[];
        final fight =
            make(
                hurt: (n, cause) {
                  expect(n, 2);
                  hits.add(cause);
                },
              )
              ..phase = phase
              ..player = phase == WalkerPhase.charge
                  ? const Offset(300, 0)
                  : const Offset(20, 0);
        for (
          var tick = 0;
          tick < 360 && fight.phase != WalkerPhase.recovery;
          tick++
        ) {
          fight.advance(1 / 120);
        }
        expect(hits, ['Walker rocket ram']);
        expect(fight.blasts.where((b) => b.landing), hasLength(1));
      }
    },
  );

  test(
    'rush landing damages body-edge area once and respects cover and pause',
    () {
      for (final covered in [false, true]) {
        var damage = 0;
        final fight =
            make(
                hurt: (n, _) => damage += n,
                clear: (_, to, _) => !(covered && to.dy == 170),
              )
              ..phase = WalkerPhase.charge
              ..player = const Offset(750, 170);
        fight.paused = true;
        fight.advance(2);
        expect(fight.blasts, isEmpty);
        fight.paused = false;
        for (
          var tick = 0;
          tick < 360 && fight.phase != WalkerPhase.recovery;
          tick++
        ) {
          fight.advance(1 / 120);
        }
        expect(fight.blasts.where((b) => b.landing), hasLength(1));
        expect(damage, covered ? 0 : 2);
        fight.advance(.3);
        expect(damage, covered ? 0 : 2);
      }
    },
  );

  test(
    'launcher swivels before emitting forward salvos in every direction',
    () {
      for (final enraged in [false, true]) {
        for (var direction = 0; direction < 8; direction++) {
          final angle = direction * math.pi / 4;
          late WalkerCombat fight;
          var launched = 0;
          fight =
              make(
                  signal: (event) {
                    if (event != WalkerSignal.rocket) return;
                    launched++;
                    final rocket = fight.rounds.last;
                    final toward = WalkerCombat.heading(
                      fight.player - rocket.position,
                    );
                    expect(
                      WalkerRig.difference(rocket.heading, toward).abs(),
                      lessThan(.8),
                    );
                    expect(
                      (rocket.position - fight.rack).distance,
                      closeTo(44, .001),
                    );
                  },
                )
                ..phase = WalkerPhase.rocketLock
                ..enraged = enraged
                ..attackEnraged = enraged
                ..rackYaw = angle + math.pi
                ..player = WalkerCombat.unit(angle) * 850;
          fight.advance(.2);
          expect(
            launched,
            0,
            reason: 'opposite-facing launcher must turn first',
          );
          for (
            var tick = 0;
            tick < 720 && fight.phase != WalkerPhase.recovery;
            tick++
          ) {
            fight.advance(1 / 120);
          }
          expect(launched, enraged ? 8 : 6);
          expect(fight.phase, WalkerPhase.recovery);
        }
      }
    },
  );

  test('heavy cannon round travels at650 and keeps swept collision', () {
    var damage = 0;
    final fight = make(hurt: (n, _) => damage += n)
      ..phase = WalkerPhase.recovery
      ..player = const Offset(500, 0);
    final shell = WalkerRound(
      WalkerRoundKind.cannon,
      Offset.zero,
      0,
      aim: fight.player,
    );
    fight.rounds.add(shell);
    fight.advance(.5);
    expect(shell.position.dx, closeTo(325, .01));
    expect(damage, 0);
    fight.advance(.3);
    expect(shell.removed, isTrue);
    expect(damage, 2);
  });

  test('gun locks and firing close distance while mounts keep firing', () {
    for (final phase in [
      WalkerPhase.rotaryLock,
      WalkerPhase.cannonLock,
      WalkerPhase.rotaryFire,
      WalkerPhase.cannonFire,
      WalkerPhase.rocketLock,
      WalkerPhase.recovery,
    ]) {
      final fight = make()
        ..phase = phase
        ..player = const Offset(900, 0)
        ..locked = const Offset(900, 0);
      final before = (fight.player - fight.rig.position).distance;
      fight.advance(.6);
      expect(
        (fight.player - fight.rig.position).distance,
        lessThan(before - 25),
        reason: '$phase must pursue instead of orbiting at long range',
      );
      if (phase == WalkerPhase.rotaryFire || phase == WalkerPhase.cannonFire) {
        expect(fight.shots, greaterThan(0));
      }
    }
  });

  test('escaped player triggers warned ram that carries through intercept', () {
    var ramDamage = 0;
    final fight =
        make(
            hurt: (n, cause) {
              if (cause == 'Walker rocket ram') ramDamage += n;
            },
          )
          ..phase = WalkerPhase.approach
          ..player = const Offset(1000, 0);
    fight.advance(.3);
    expect(fight.phase, WalkerPhase.chargeLock);
    final start = fight.rig.position;
    fight.advance(1.3);
    expect(fight.phase, WalkerPhase.chargeLock);
    expect(
      (fight.rig.position - start).distance,
      lessThan(50),
      reason: 'brace allows the bounded deceleration from pursuit',
    );
    for (var i = 0; i < 360 && fight.phase != WalkerPhase.brake; i++) {
      fight.advance(1 / 120);
    }
    expect(ramDamage, 2);
    expect(fight.rig.position.dx, greaterThan(1100));
    // After a rush there is a ten-active-second cooldown, even if the target
    // immediately escapes again. Normal guns can still attack during it.
    fight.phase = WalkerPhase.approach;
    fight.clock = 0;
    fight.player = fight.rig.position + const Offset(1000, 0);
    fight.advance(.5);
    expect(fight.phase, isNot(WalkerPhase.chargeLock));
  });

  test('ram keeps its final warning heading and can be sidestepped', () {
    var hits = 0;
    final fight = make(hurt: (_, _) => hits++)
      ..phase = WalkerPhase.chargeLock
      ..player = const Offset(900, 0);
    fight.advance(1.05);
    final committed = fight.chargeDirection;
    fight.player = const Offset(900, 450);
    for (var i = 0; i < 360 && fight.phase != WalkerPhase.brake; i++) {
      fight.advance(1 / 120);
    }
    expect(fight.chargeDirection, committed);
    expect(hits, 0);
    expect(fight.rig.position.dx, greaterThan(1000));
    expect(fight.rig.position.dy.abs(), lessThan(1));
  });

  test('blocked sight prevents a distance-triggered ram', () {
    final fight = make(clear: (_, _, _) => false)
      ..phase = WalkerPhase.approach
      ..player = const Offset(1000, 0);
    fight.advance(.6);
    expect(fight.phase, WalkerPhase.approach);
    expect(fight.rig.position.dx, greaterThan(0));
  });

  test(
    'rotary sustains pressure and cannon releases a real volley in both phases',
    () {
      for (final enraged in [false, true]) {
        for (final phase in [WalkerPhase.rotaryLock, WalkerPhase.cannonLock]) {
          final events = <WalkerSignal>[];
          final fight = make(signal: events.add)
            ..phase = phase
            ..enraged = enraged
            ..attackEnraged = enraged
            ..player = const Offset(600, 0)
            ..locked = const Offset(600, 0);
          for (
            var i = 0;
            i < 120 * 7 && fight.phase != WalkerPhase.recovery;
            i++
          ) {
            fight.advance(1 / 120);
          }
          final gun = phase == WalkerPhase.rotaryLock
              ? WalkerSignal.rotary
              : WalkerSignal.cannon;
          expect(
            events.where((e) => e == gun).length,
            phase == WalkerPhase.rotaryLock
                ? (enraged ? 96 : 72)
                : (enraged ? 10 : 8),
          );
          expect(
            fight.rounds.length,
            lessThanOrEqualTo(WalkerCombat.roundLimit),
          );
        }
      }
    },
  );
  test('rocket interception is exactly once, respects pause/death, and keeps near-blast risk', () {
    for (final distance in [100.0, 200.0]) {
      var damage = 0, blasts = 0;
      final fight =
          make(
              hurt: (n, _) => damage += n,
              signal: (s) {
                if (s == WalkerSignal.blast) blasts++;
              },
            )
            ..phase = WalkerPhase.recovery
            ..player = Offset.zero;
      final rocket = WalkerRound(
        WalkerRoundKind.rocket,
        Offset(distance, 0),
        0,
        aim: Offset.zero,
      );
      fight.rounds.add(rocket);
      fight.paused = true;
      expect(fight.interceptRocket(rocket), isFalse);
      fight.paused = false;
      expect(fight.interceptRocket(rocket), isTrue);
      expect(fight.interceptRocket(rocket), isFalse);
      expect(fight.rounds, isEmpty);
      expect(blasts, 1);
      expect(damage, distance == 100 ? 2 : 0);
      fight.advance(.4);
      expect(blasts, 1);
    }
  });
  test(
    'full deployment, all weapons and committed ram complete a working cycle',
    () {
      final signals = <WalkerSignal>[];
      final fight = make(signal: signals.add)..player = const Offset(450, 0);
      final states = <WalkerPhase>{};
      for (var i = 0; i < 120 * 55; i++) {
        states.add(fight.phase);
        fight.advance(1 / 120);
      }
      for (final phase in [
        WalkerPhase.descending,
        WalkerPhase.landing,
        WalkerPhase.burstFire,
        WalkerPhase.rotaryFire,
        WalkerPhase.cannonFire,
        WalkerPhase.rocketFire,
        WalkerPhase.charge,
        WalkerPhase.brake,
      ]) {
        expect(states, contains(phase));
      }
      expect(
        signals,
        containsAll([
          WalkerSignal.rotary,
          WalkerSignal.cannon,
          WalkerSignal.rocket,
          WalkerSignal.charge,
        ]),
      );
      expect(fight.rounds.length, lessThanOrEqualTo(WalkerCombat.roundLimit));
    },
  );

  test(
    'sky drop cannot fire or hurt before touchdown settles; pause freezes it',
    () {
      var hits = 0;
      final fight = make(hurt: (_, _) => hits++);
      fight.advance(1);
      expect(fight.vulnerable, isFalse);
      expect(fight.shots, 0);
      expect(hits, 0);
      fight.paused = true;
      fight.advance(10);
      expect(fight.clock, closeTo(1, 1e-8));
      fight.paused = false;
      fight.advance(2.1);
      expect(fight.vulnerable, isTrue);
    },
  );

  test(
    'rockets travel straight before acquisition and turn at a bounded rate',
    () {
      final fight = make()
        ..phase = WalkerPhase.recovery
        ..player = const Offset(0, 500);
      final rocket = WalkerRound(
        WalkerRoundKind.rocket,
        const Offset(-400, 0),
        0,
        aim: fight.player,
      );
      fight.rounds.add(rocket);
      fight.advance(.5);
      expect(rocket.heading, 0);
      expect(rocket.pursuing, isFalse);
      final previous = rocket.heading;
      fight.advance(.2);
      expect(rocket.pursuing, isTrue);
      expect(
        (rocket.heading - previous).abs(),
        lessThanOrEqualTo(.2 * 1.8 + .001),
      );
      expect(rocket.position.dx, greaterThan(-400));
    },
  );

  test('every muzzle clears its own body through360 degrees; cover suppresses releases', () {
    final fight = make()..player = const Offset(600, 0);
    for (var i = 0; i < 64; i++) {
      fight.rig.yaw = i * math.pi / 32;
      for (var j = 0; j < 64; j++) {
        fight.rig.turretYaw = fight.cannonYaw = j * math.pi / 32;
        for (final cannon in [false, true]) {
          expect(
            (fight.muzzle(cannon) - fight.rig.position).distance,
            greaterThan(WalkerCombat.bodyRadius + 12),
          );
        }
      }
    }
    final blocked = make(clear: (_, _, _) => false)
      ..phase = WalkerPhase.cannonLock
      ..player = const Offset(600, 0)
      ..locked = const Offset(600, 0);
    blocked.advance(2);
    expect(blocked.shots, 0);
  });

  test('fatal cancels ordnance, warns, blasts once through body edges and respects cover', () {
    for (final covered in [false, true]) {
      var damage = 0;
      final fight = make(
        clear: (_, _, _) => !covered,
        hurt: (n, _) => damage += n,
      )..player = const Offset(350, 0);
      fight.rounds.add(
        WalkerRound(WalkerRoundKind.rocket, Offset.zero, 0, aim: fight.player),
      );
      fight.beginDestruction();
      expect(fight.rounds, isEmpty);
      fight.advance(2.5);
      expect(damage, 0);
      fight.advance(.2);
      expect(damage, covered ? 0 : 3);
      fight.beginDestruction();
      fight.advance(10);
      expect(fight.detonations, 1);
      expect(fight.finished, isTrue);
      expect(damage, covered ? 0 : 3);
    }
  });

  test(
    'swept charge locks its route, stops at obstruction and deals one strike',
    () {
      var hits = 0;
      final fight =
          WalkerCombat(
              rig: WalkerRig(
                moveResolver: (a, b) => Offset(math.min(b.dx, 280), b.dy),
              ),
              clear: (_, _, _) => true,
              hurt: (_, _) => hits++,
              signal: (_) {},
              moveCharge: (a, b) => Offset(math.min(b.dx, 280), b.dy),
            )
            ..phase = WalkerPhase.charge
            ..chargeDirection = const Offset(1, 0)
            ..player = const Offset(220, 0);
      fight.advance(.8);
      expect(hits, 1);
      expect(fight.rig.position.dx, lessThanOrEqualTo(280));
      expect(fight.phase, anyOf(WalkerPhase.brake, WalkerPhase.recovery));
    },
  );

  test('battle stepping is invariant at30/60/120Hz including rocket and death events', () {
    final cases = <WalkerCombat>[];
    for (final hz in [30, 60, 120]) {
      final fight = make()..player = const Offset(450, 0);
      for (var i = 0; i < hz * 20; i++) {
        fight.advance(1 / hz);
      }
      cases.add(fight);
    }
    for (final other in cases.skip(1)) {
      expect(other.phase, cases.first.phase);
      expect(other.shots, cases.first.shots);
      expect(
        (other.rig.position - cases.first.rig.position).distance,
        lessThan(1e-6),
      );
    }
  });
}
