import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_rig.dart';

ArietCombat makeJet({
  ArietRig? rig,
  bool Function(Offset, Offset, double)? clear,
  bool Function(double, String)? hurt,
}) => ArietCombat(
  rig: rig ?? ArietRig(),
  clear: clear ?? (_, __, ___) => true,
  hurt: hurt ?? (_, __) => true,
  signal: (_) {},
  landingLegal: (_, __) => true,
  deploy: (_) {},
);

void main() {
  test('open-arena flight stays mobile through attack and cooling cycles', () {
    for (final enraged in [false, true]) {
      final f = makeJet()
        ..phase = ArietPhase.navigate
        ..enraged = enraged;
      var stopped = 0, longest = 0, streak = 0;
      final phases = <ArietPhase>{};
      for (var i = 0; i < 120 * 60; i++) {
        final a = i / 120 * .5;
        f.player = Offset(math.cos(a), math.sin(a)) * 550;
        f.advance(1 / 120);
        phases.add(f.phase);
        if (f.rig.velocity.distance < 40) {
          stopped++;
          streak++;
          longest = math.max(longest, streak);
        } else {
          streak = 0;
        }
      }
      expect(stopped / (120 * 60), lessThan(.2), reason: 'enraged=$enraged');
      expect(longest / 120, lessThan(2.3), reason: 'no long idle holds');
      expect(
        phases,
        containsAll([
          ArietPhase.turnFire,
          ArietPhase.recovery,
          ArietPhase.cannon,
          ArietPhase.flak,
          ArietPhase.seekers,
        ]),
      );
    }
  });

  test('hull flies a broad independent course while roof guns reacquire a reversing target', () {
    final f = makeJet()
      ..phase = ArietPhase.navigate
      ..grace = 50
      ..player = const Offset(650, 0);
    f.rig.yaw = f.rig.desiredYaw = math.pi / 2;
    f.advance(.6);
    expect(
      ArietRig.difference(
        f.rig.yaw,
        ArietCombat.heading(f.player - f.rig.bodyPosition),
      ).abs(),
      greaterThan(.8),
    );
    final yaw = f.rig.yaw;
    f.player = const Offset(-650, 0);
    f.advance(.3);
    expect(ArietRig.difference(f.rig.yaw, yaw).abs(), lessThan(.6));
    expect(
      ArietRig.difference(
        f.noseYaw.first,
        ArietCombat.heading(f.player - f.rig.noseSocket(0)),
      ).abs(),
      lessThan(.12),
    );
    expect(f.rig.velocity.distance, greaterThan(200));
  });

  test('ordinary repositioning is fast and turns promptly without needing a charge', () {
    final f = makeJet()
      ..phase = ArietPhase.navigate
      ..grace = 50
      ..player = const Offset(1800, 0);
    f.rig.yaw = f.rig.desiredYaw = 0;
    f.advance(1.4);
    expect(
      ArietRig.difference(f.rig.yaw, ArietCombat.heading(f.rig.velocity)).abs(),
      lessThan(.2),
    );
    expect(f.rig.velocity.distance, greaterThan(330));
    f.advance(1.6);
    expect(f.phase, ArietPhase.navigate);
    expect(f.rig.position.distance, greaterThan(900));
  });

  test('charge spools, commits, brakes, then acquires and fires while the hull is still turning', () {
    var damage = 0;
    late ArietCombat f;
    f =
        makeJet(
            hurt: (d, _) {
              expect(f.phase, isNot(ArietPhase.strafe));
              damage += d.toInt();
              return true;
            },
          )
          ..phase = ArietPhase.navigate
          ..player = const Offset(650, 0);
    final seen = <ArietPhase>[];
    Offset? route, end;
    double peak = 0,
        brakeStart = 0,
        stoppedAt = 0,
        firstFireDelay = 10,
        firstHullError = 0;
    var shots = 0;
    for (var i = 0; i < 120 * 12; i++) {
      final before = f.phase;
      f.advance(1 / 120);
      if (seen.isEmpty || seen.last != f.phase) seen.add(f.phase);
      peak = math.max(peak, f.rig.velocity.distance);
      if (f.phase == ArietPhase.strafeLock && route == null) {
        route = f.routeHeading;
        end = f.routeEnd;
      }
      if (f.phase == ArietPhase.strafe) {
        expect(f.routeHeading, route);
        expect(f.routeEnd, end);
        f.player = const Offset(650, 180);
      }
      if (f.phase == ArietPhase.strafeBrake && before != f.phase) {
        brakeStart = f.elapsed;
      }
      if (f.phase == ArietPhase.turnFire && before != f.phase) {
        stoppedAt = f.elapsed;
        expect(f.rig.velocity.distance, lessThan(1));
        expect(stoppedAt - brakeStart, lessThan(.6));
      }
      if (f.totalNose > shots) {
        if (shots == 0) {
          firstFireDelay = f.elapsed - stoppedAt;
          firstHullError = ArietRig.difference(
            f.rig.yaw,
            ArietCombat.heading(f.player - f.rig.bodyPosition),
          ).abs();
        }
        shots = f.totalNose;
      }
      expect(f.rounds.length, lessThanOrEqualTo(32));
      if (f.phase == ArietPhase.recovery) break;
    }
    expect(
      seen,
      containsAllInOrder([
        ArietPhase.strafeLock,
        ArietPhase.strafe,
        ArietPhase.strafeBrake,
        ArietPhase.turnFire,
        ArietPhase.recovery,
      ]),
    );
    expect(peak, greaterThan(780));
    expect(firstFireDelay, lessThan(.35));
    expect(firstHullError, greaterThan(.6));
    expect(f.totalNose, 36);
    expect(
      damage,
      greaterThan(1),
      reason: 'later rotary hits register after the shared protection interval',
    );
  });

  test('cannon and seeker fire keep an agile lateral firing platform', () {
    for (final seeker in [false, true]) {
      final f = makeJet()
        ..phase = seeker ? ArietPhase.seekerLock : ArietPhase.cannonLock
        ..enraged = true
        ..player = const Offset(650, 0);
      f.advance(2.55);
      expect(f.rig.position.distance, greaterThan(250));
      if (seeker) {
        expect(f.totalSeekers, 6);
      } else {
        expect(f.totalCannon, 4);
      }
    }
  });

  test('pause freezes a committed fast charge and a later obstruction stops it before the counter', () {
    var obstruction = false;
    final rig = ArietRig(
      resolveMove: (from, to) =>
          obstruction && to.dx > 600 ? Offset(600, to.dy) : to,
    );
    final f = makeJet(rig: rig)
      ..phase = ArietPhase.navigate
      ..player = const Offset(650, 0);
    while (f.phase != ArietPhase.strafe) {
      f.advance(1 / 120);
    }
    f.advance(.3);
    final at = rig.position,
        velocity = rig.velocity,
        clock = f.elapsed,
        flow = rig.jetFlow(0, 0);
    f.paused = true;
    f.advance(5);
    expect(rig.position, at);
    expect(rig.velocity, velocity);
    expect(f.elapsed, clock);
    expect(rig.jetFlow(0, 0), flow);
    f.paused = false;
    obstruction = true;
    var stopped = false;
    for (var i = 0; i < 120 * 3; i++) {
      f.advance(1 / 120);
      expect(rig.position.dx, lessThanOrEqualTo(600.001));
      if (f.phase == ArietPhase.turnFire) {
        stopped = true;
        break;
      }
    }
    expect(stopped, isTrue);
  });

  test(
    'charge planning checks the braking corridor before committing its warning',
    () {
      final f =
          makeJet(
              clear: (a, b, radius) =>
                  a.dx + radius < 1000 && b.dx + radius < 1000,
            )
            ..phase = ArietPhase.navigate
            ..player = const Offset(650, 0);
      f.advance(.5);
      expect(f.phase, ArietPhase.cannonLock);
    },
  );
}
