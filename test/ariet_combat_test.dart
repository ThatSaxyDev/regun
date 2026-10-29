import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/systems/ariet_hull.dart';
import 'package:regun/systems/target_shape.dart';

void main() {
  test('hover, cargo release, roof weapons and crash share the visible airborne plane', () {
    final f =
        ArietCombat(
            rig: ArietRig(),
            clear: (_, __, ___) => true,
            hurt: (_, __) => true,
            signal: (_) {},
            landingLegal: (_, __) => true,
            deploy: (_) {},
          )
          ..enraged = true
          ..player = const Offset(650, 0);
    expect(f.rig.height, ArietCombat.flightHeight);
    for (var i = 0; i < 120 * 12; i++) {
      f.advance(1 / 120);
      expect(
        f.rig.height,
        inInclusiveRange(
          ArietCombat.flightHeight - 7,
          ArietCombat.flightHeight + 7,
        ),
      );
      expect(f.rig.project(Offset.zero), f.rig.bodyPosition);
      for (var gun = 0; gun < 2; gun++) {
        expect(
          f.rig.noseSocket(gun),
          f.rig.air(ArietRig.noseMounts[gun], z: ArietRig.rotaryZ(gun)),
        );
      }
    }
    expect(f.totalDrops, 2);
    for (final d in f.drops) {
      expect(
        d.groundOrigin!.dy - d.origin!.dy,
        inInclusiveRange(
          (ArietCombat.flightHeight - 7 - 28) * .7,
          (ArietCombat.flightHeight + 7 - 28) * .7,
        ),
      );
    }
    f.beginDestruction();
    expect(f.rig.enginesRunning, isFalse);
    f.advance(2.0);
    expect(f.rig.height, lessThan(ArietCombat.flightHeight));
    f.advance(.2);
    expect(f.rig.height, 0);
    expect(f.rig.bodyPosition, f.rig.position);
  });
  ArietCombat make({
    bool Function(Offset, Offset, double)? clear,
    bool Function(Offset, double)? legal,
    void Function(ArietDrop)? deploy,
    bool Function(double, String)? hurt,
    int seed = 427,
  }) => ArietCombat(
    rig: ArietRig(),
    seed: seed,
    clear: clear ?? (_, __, ___) => true,
    landingLegal: legal ?? (_, __) => true,
    deploy: deploy ?? (_) {},
    hurt: hurt ?? (_, __) => true,
    signal: (_) {},
  );
  test('compound hull leaves real gaps and contacts first swept machinery', () {
    final rig = ArietRig();
    final shape = ArietHull.regions(rig).toList();
    bool touches(Offset p) => shape.any((s) => s.distance(p) == 0);
    expect(touches(const Offset(0, 0)), isTrue);
    expect(touches(const Offset(0, 110)), isTrue);
    expect(touches(rig.air(const Offset(70, 94))), isFalse);
    const sphere = TargetCapsule(Offset(100, 0), Offset(150, 0), 20);
    expect(
      sphere.contact(Offset.zero, const Offset(500, 0)),
      closeTo(80, 1e-9),
    );
    expect(
      sphere.contact(const Offset(110, -100), const Offset(110, 100)),
      closeTo(80, 1e-9),
    );
    expect(sphere.contact(const Offset(0, 25), const Offset(500, 25)), isNull);
    for (var i = 0; i < 8; i++) {
      rig.yaw = i * math.pi / 4;
      expect(
        ArietHull.regions(rig)
            .any((s) => s.distance(rig.air(const Offset(0, 110))) == 0),
        isTrue,
      );
    }
  });
  test(
    'director completes strafe and broadside with real recovery windows',
    () {
      final f = make()..player = const Offset(650, 0);
      final seen = <ArietPhase>{};
      final recoveries = <double>[];
      double? recoveryStart;
      for (var i = 0; i < 120 * 60; i++) {
        f.advance(1 / 120);
        seen.add(f.phase);
        if (f.phase == ArietPhase.recovery) {
          recoveryStart ??= f.elapsed;
        } else if (recoveryStart != null) {
          recoveries.add(f.elapsed - recoveryStart);
          recoveryStart = null;
        }
      }
      expect(
        seen,
        containsAll([
          ArietPhase.descent,
          ArietPhase.strafeLock,
          ArietPhase.strafe,
          ArietPhase.strafeBrake,
          ArietPhase.turnFire,
          ArietPhase.cannon,
          ArietPhase.recovery,
        ]),
      );
      expect(f.totalNose, greaterThanOrEqualTo(36));
      expect(f.totalCannon, greaterThanOrEqualTo(4));
      expect(recoveries, everyElement(greaterThanOrEqualTo(1.19)));
    },
  );
  test(
    'valid moving broadside releases all four; blocked attempts finish safely',
    () {
      for (final blocked in [false, true]) {
        final f = make(clear: (_, __, ___) => !blocked)
          ..phase = ArietPhase.cannonLock;
        f.rig.yaw = f.rig.desiredYaw = -math.pi / 2;
        f.rig.cannonYaw = 0;
        for (var i = 0; i < 120 * 5; i++) {
          f.player = Offset(350, math.sin(i / 120) * 40);
          f.advance(1 / 120);
          if (f.phase == ArietPhase.recovery) break;
        }
        expect(f.totalCannon, blocked ? 0 : 4);
        expect(f.phase, ArietPhase.recovery);
      }
    },
  );
  test(
    'enraged pass drops one real pair, counts pending and never duplicates',
    () {
      final actors = <int>[];
      final f = make(deploy: (d) => actors.add(d.id))
        ..player = const Offset(650, 0)
        ..enraged = true;
      final releases = <int>[];
      for (var i = 0; i < 120 * 45; i++) {
        f.advance(1 / 120);
        releases.add(f.rounds.length);
        expect(f.drops.length, lessThanOrEqualTo(2));
      }
      expect(actors, [1, 2]);
      expect(f.totalDrops, 2);
      expect(f.deploymentSpent, isTrue);
      expect(releases, everyElement(lessThanOrEqualTo(32)));
      final invalid = make(legal: (_, __) => false)
        ..player = const Offset(650, 0)
        ..enraged = true;
      invalid.advance(9);
      expect(invalid.totalDrops, 0);
      expect(invalid.drops, isEmpty);
      expect(invalid.totalNose, 36);
    },
  );
  test(
    'exhaust plants two patches and deals one accepted hit across overlap',
    () {
      var hits = 0;
      final f = make(
        hurt: (_, __) {
          hits++;
          return true;
        },
      )..player = const Offset(-30, 165);
      for (var i = 0; i < 120 * 6; i++) {
        f.player = f.rig.ground(const Offset(-30, 190));
        f.advance(1 / 120);
        if (f.phase == ArietPhase.exhaustLock) break;
      }
      expect(f.phase, ArietPhase.exhaustLock);
      final planted = f.exhaust.map((s) => s.a).toList();
      f.advance(.8);
      expect(f.exhaust.map((s) => s.a), planted);
      f.player = Offset.lerp(f.exhaust.first.a, f.exhaust.first.b, .5)!;
      f.advance(.5);
      expect(hits, 1);
      expect(f.phase, ArietPhase.recovery);
    },
  );
  test(
    'pause freezes ordnance/drop state; death clears owners and has no bomb',
    () {
      final actors = <int>[];
      var damage = 0;
      final f =
          make(
              deploy: (d) => actors.add(d.id),
              hurt: (_, __) {
                damage++;
                return true;
              },
            )
            ..player = const Offset(650, 0)
            ..enraged = true;
      f.advance(3.3);
      final time = f.elapsed, point = f.rig.position;
      f.paused = true;
      f.advance(10);
      expect(f.elapsed, time);
      expect(f.rig.position, point);
      f.paused = false;
      f.beginDestruction();
      final before = damage;
      expect(f.rounds, isEmpty);
      expect(
        f.drops.where((d) => !d.activated).every((d) => d.aborted),
        isTrue,
      );
      f.advance(5);
      expect(f.finished, isTrue);
      expect(damage, before);
      expect(actors, isEmpty);
    },
  );
  test('escort pressure supports ordinary charges but cannot delay main attacks forever', () {
    final f = make()..phase = ArietPhase.navigate;
    f.clock = f.grace;
    expect(f.claimEscortVolley(1), isFalse);
    for (final phase in [
      ArietPhase.strafeLock,
      ArietPhase.strafe,
      ArietPhase.strafeBrake,
      ArietPhase.turnFire,
    ]) {
      f.phase = phase;
      f.elapsed += 2;
      expect(f.claimEscortVolley(1), isTrue);
      expect(f.escortRelease(1, Offset.zero, 0), isTrue);
    }
    f.deploymentPass = true;
    expect(f.escortsMayFire, isFalse);
    for (final phase in [
      ArietPhase.flakLock,
      ArietPhase.flak,
      ArietPhase.seekerLock,
      ArietPhase.seekers,
      ArietPhase.recovery,
    ]) {
      f.phase = phase;
      expect(f.escortsMayFire, isFalse);
    }
  });
  test(
    'escort release respects cannon/exhaust/recovery and combined capacity',
    () {
      final f = make()
        ..phase = ArietPhase.navigate
        ..grace = .7;
      expect(f.claimEscortVolley(1), isTrue);
      expect(f.claimEscortVolley(2), isFalse);
      expect(f.escortRelease(1, Offset.zero, 0), isTrue);
      for (final phase in [
        ArietPhase.cannonLock,
        ArietPhase.cannon,
        ArietPhase.exhaustLock,
        ArietPhase.exhaust,
        ArietPhase.recovery,
      ]) {
        f.phase = phase;
        expect(f.escortRelease(1, Offset.zero, 0), isFalse);
      }
      f.phase = ArietPhase.navigate;
      while (f.rounds.length < 32) {
        expect(f.escortRelease(1, Offset.zero, 0), isTrue);
      }
      expect(f.escortRelease(1, Offset.zero, 0), isFalse);
    },
  );
  test(
    'a full moving-target pass completes 36 rounds under the shared cap',
    () {
      final f = make()..player = const Offset(650, 0);
      while (f.phase != ArietPhase.strafe) {
        f.advance(1 / 120);
      }
      final heading = f.routeHeading, end = f.routeEnd;
      for (var n = 0; n < 6; n++) {
        f.rounds.add(ArietRound(f.rig.position, math.pi, owner: 1));
      }
      while ([
        ArietPhase.strafe,
        ArietPhase.strafeBrake,
        ArietPhase.turnFire,
      ].contains(f.phase)) {
        f.player = f.rig.position + const Offset(0, 1000);
        f.advance(1 / 120);
        expect(f.rounds.length, lessThanOrEqualTo(32));
        expect(f.routeHeading, heading);
        expect(f.routeEnd, end);
      }
      expect(f.totalNose, 36);
    },
  );
  test(
    'one strafe cannot stack accepted hits and arrival/crash never hurt',
    () {
      var hits = 0;
      final f = make(
        hurt: (_, __) {
          hits++;
          return true;
        },
      )..player = const Offset(650, 0);
      f.advance(2.5);
      expect(hits, 0);
      f.advance(5);
      expect(hits, 1);
      f.beginDestruction();
      f.advance(5);
      expect(hits, 1);
    },
  );
  test('every unfolding pose retains fixed real links, including the tight hinge crossing', () {
    for (var i = 0; i <= 100; i++) {
      final t = i / 100, e = t * t * (3 - 2 * t);
      final r =
          WalkerRig(
              foldedReach: .28 + .72 * e,
              foldedAnkleZ: 72 * (1 - e),
              foldedKneeDown: true,
              foldedPoleAngle: e * math.pi,
            )
            ..folded = true
            ..height = 48 + 40 * e;
      for (final l in r.legs) {
        final p = r.pose(l);
        expect((p.knee - p.hip).length, closeTo(110, 1e-6));
        expect((p.ankle - p.knee).length, closeTo(130, 1e-6));
      }
    }
  });
  test('30/60/120Hz yield same movement, volleys and deployment ledger', () {
    final runs = <ArietCombat>[];
    for (final hz in [30, 60, 120]) {
      final f = make()
        ..player = const Offset(650, 0)
        ..enraged = true;
      for (var i = 0; i < hz * 20; i++) {
        f.advance(1 / hz);
      }
      runs.add(f);
    }
    for (final f in runs.skip(1)) {
      expect(
        (f.rig.position - runs.first.rig.position).distance,
        lessThan(1e-6),
      );
      expect(f.totalNose, runs.first.totalNose);
      expect(f.totalCannon, runs.first.totalCannon);
      expect(f.totalDrops, runs.first.totalDrops);
    }
  });
}
