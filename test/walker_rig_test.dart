import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/walker_rig.dart';

void main() {
  test('battle feet settle between deliberate paired steps without correction taps', () {
    final rig = WalkerRig(
      maxSpeed: 260,
      acceleration: 600,
      turnSpeed: 1.5,
      agileGait: true,
      bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
      footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
    )..command = const Offset(210, 50);
    final lastLanding = <int, double>{};
    var launches = 0;
    for (var frame = 0; frame < 120 * 8; frame++) {
      final before = {for (final leg in rig.legs) leg.index: leg.planted};
      rig.advance(1 / 120);
      for (final leg in rig.legs) {
        if (before[leg.index]! && !leg.planted) {
          launches++;
          expect(
            (leg.destination - leg.from).distance,
            greaterThanOrEqualTo(24),
          );
          if (lastLanding.containsKey(leg.index)) {
            expect(
              rig.elapsed - lastLanding[leg.index]!,
              greaterThanOrEqualTo(.099),
            );
          }
        }
        if (!before[leg.index]! && leg.planted) {
          lastLanding[leg.index] = rig.elapsed;
        }
      }
      final flying = rig.legs.where((leg) => !leg.planted).toList();
      if (flying.length == 2) {
        expect(flying[0].index + flying[1].index, 3);
        expect(flying[0].swing, flying[1].swing);
      }
    }
    expect(launches, greaterThan(16));
  });

  test('battle turns preserve leg lanes, steady knees and planted foot orientation', () {
    final rig = WalkerRig(
      maxSpeed: 260,
      acceleration: 600,
      turnSpeed: 1.5,
      agileGait: true,
      bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
      footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
    );
    var maxKneeTravel = 0.0;
    for (var frame = 0; frame < 120 * 18; frame++) {
      final before = {
        for (final leg in rig.legs)
          leg: (leg.foot, leg.footYaw, leg.planted, rig.pose(leg).knee),
      };
      final t = frame / 120;
      rig.desiredYaw = t < 6
          ? t * 1.1
          : t < 12
          ? 6.6 - (t - 6) * 1.1
          : math.pi;
      rig.command = t < 12
          ? WalkerRig.rotate(const Offset(210, 70), rig.desiredYaw)
          : Offset.zero;
      rig.advance(1 / 120);
      expect(rig.swingingFeet, lessThanOrEqualTo(2));
      for (final leg in rig.legs) {
        final old = before[leg]!;
        final local = WalkerRig.rotate(leg.foot - rig.position, -rig.yaw);
        expect(local.dx * leg.rest.dx.sign, greaterThan(20));
        expect(local.dy * leg.rest.dy.sign, greaterThan(20));
        if (old.$3 && leg.planted) {
          expect(leg.foot, old.$1);
          expect(leg.footYaw, old.$2);
        }
        final travel = (rig.pose(leg).knee - old.$4).length;
        maxKneeTravel = math.max(maxKneeTravel, travel);
        expect(
          travel,
          lessThan(12),
          reason: 'knee snap at $frame / ${leg.index}',
        );
      }
      for (var a = 0; a < 4; a++) {
        for (var b = a + 1; b < 4; b++) {
          expect(
            (rig.legs[a].foot - rig.legs[b].foot).distance,
            greaterThan(55),
          );
        }
      }
    }
    expect(WalkerRig.difference(rig.yaw, math.pi).abs(), lessThan(.05));
    final steps = rig.legs.fold<int>(0, (n, leg) => n + leg.steps);
    rig.advance(2);
    expect(
      rig.legs.fold<int>(0, (n, leg) => n + leg.steps),
      steps,
      reason: 'settled feet must not chatter in place',
    );
    expect(maxKneeTravel, greaterThan(0));
  });

  test('agile battle gait gains ground without sliding planted feet or losing support', () {
    for (final angle in [0.0, math.pi / 4, math.pi / 2, math.pi]) {
      final rig = WalkerRig(
        maxSpeed: 260,
        acceleration: 600,
        turnSpeed: 1.5,
        agileGait: true,
        bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
        footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
      );
      rig.desiredYaw = rig.yaw = angle;
      for (final leg in rig.legs) {
        leg.foot = WalkerRig.rotate(leg.rest, angle);
        leg.from = leg.destination = leg.foot;
      }
      rig.command = Offset(math.cos(angle), math.sin(angle)) * 230;
      for (var i = 0; i < 360; i++) {
        final planted = {
          for (final leg in rig.legs.where((l) => l.planted))
            leg.index: leg.foot,
        };
        rig.advance(1 / 120);
        expect(rig.swingingFeet, lessThanOrEqualTo(2));
        for (final leg in rig.legs) {
          if (leg.planted && planted.containsKey(leg.index)) {
            expect((leg.foot - planted[leg.index]!).distance, lessThan(1e-8));
          }
          final pose = rig.pose(leg);
          expect(
            (pose.knee - pose.hip).length,
            closeTo(WalkerRig.upperLength, .001),
          );
          expect(
            (pose.ankle - pose.knee).length,
            closeTo(WalkerRig.lowerLength, .001),
          );
        }
      }
      expect(
        rig.position.distance,
        greaterThan(400),
        reason: 'direction $angle',
      );
      final before = rig.position;
      rig.command = Offset.zero;
      rig.advance(.5);
      expect(rig.velocity.distance, lessThan(1));
      expect((rig.position - before).distance, lessThan(80));
    }
  });
  test('continuous turn, reversal and brace keep fixed link lengths', () {
    final rig = WalkerRig();
    for (var f = 0; f < 120 * 24; f++) {
      final time = f / 120;
      rig.desiredYaw = time * .9;
      rig.command = time < 8
          ? const Offset(60, 10)
          : time < 16
          ? const Offset(-60, -10)
          : Offset.zero;
      rig.braced = time > 18 && time < 21;
      rig.advance(1 / 120);
      for (final leg in rig.legs) {
        final p = rig.pose(leg);
        expect((p.knee - p.hip).length, closeTo(WalkerRig.upperLength, .001));
        expect(
          (p.ankle - p.knee).length,
          closeTo(WalkerRig.lowerLength, .001),
          reason: 'time=$time leg=${leg.index}',
        );
      }
    }
  });

  test(
    'long legs keep world-planted feet and reachable joints in every direction',
    () {
      for (var direction = 0; direction < 16; direction++) {
        final rig = WalkerRig();
        final a = direction * math.pi / 8;
        rig.command = Offset(math.cos(a), math.sin(a)) * 65;
        rig.desiredYaw = a;
        for (var frame = 0; frame < 600; frame++) {
          final before = {
            for (final leg in rig.legs) leg: (leg.foot, leg.planted, leg.steps),
          };
          rig.advance(1 / 120);
          expect(rig.swingingFeet, lessThanOrEqualTo(1));
          for (final leg in rig.legs) {
            final b = before[leg]!;
            if (b.$2 && leg.planted && leg.steps == b.$3) {
              expect(
                leg.foot,
                b.$1,
                reason: 'A supporting foot must not skate',
              );
            }
            final pose = rig.pose(leg);
            expect(
              (pose.knee - pose.hip).length,
              closeTo(WalkerRig.upperLength, .001),
            );
            expect(
              (pose.ankle - pose.knee).length,
              closeTo(WalkerRig.lowerLength, .001),
              reason: 'direction=$direction leg=${leg.index} frame=$frame',
            );
            expect(
              pose.knee.x.isFinite &&
                  pose.knee.y.isFinite &&
                  pose.knee.z.isFinite,
              isTrue,
            );
          }
        }
        expect(
          rig.legs.fold<int>(0, (n, leg) => n + leg.steps),
          greaterThan(4),
        );
      }
    },
  );

  test('fixed simulation produces identical gait at 30, 60 and 120Hz', () {
    final rigs = <WalkerRig>[];
    for (final hz in [30, 60, 120]) {
      final rig = WalkerRig()
        ..command = const Offset(55, 12)
        ..desiredYaw = .8;
      for (var i = 0; i < hz * 6; i++) {
        rig.advance(1 / hz);
      }
      rigs.add(rig);
    }
    for (final rig in rigs.skip(1)) {
      expect((rig.position - rigs.first.position).distance, lessThan(1e-8));
      expect(rig.yaw, closeTo(rigs.first.yaw, 1e-8));
      for (var i = 0; i < 4; i++) {
        expect(
          (rig.legs[i].foot - rigs.first.legs[i].foot).distance,
          lessThan(1e-8),
        );
        expect(rig.legs[i].steps, rigs.first.legs[i].steps);
      }
    }
  });

  test(
    'wall-stopped root does not run its feet in place; pause freezes the rig',
    () {
      final rig = WalkerRig(moveResolver: (current, proposed) => current)
        ..command = const Offset(72, 0);
      rig.advance(3);
      expect(rig.position, Offset.zero);
      expect(rig.legs.every((leg) => leg.steps == 0 && leg.planted), isTrue);
      rig.paused = true;
      final elapsed = rig.elapsed, muzzle = rig.muzzle;
      rig.target = const Offset(-400, -100);
      rig.advance(10);
      expect(rig.elapsed, elapsed);
      expect((rig.muzzle - muzzle).length, 0);
      rig.paused = false;
      rig.advance(.1);
      expect(rig.elapsed, closeTo(elapsed + .1, 1e-8));
    },
  );

  test('turret covers 360 degrees without rotating a stationary body', () {
    final rig = WalkerRig();
    for (var i = 0; i < 32; i++) {
      final a = i * math.pi / 16;
      rig.target =
          rig.turretPivot.ground + Offset(math.cos(a), math.sin(a)) * 400;
      rig.advance(1);
      expect(WalkerRig.difference(rig.turretYaw, a).abs(), lessThan(.001));
      expect(rig.yaw, 0);
      expect((rig.muzzle - rig.turretPivot).length, closeTo(104, .001));
    }
    expect(
      WalkerRig.difference(
        WalkerRig.turn(math.pi - .01, -math.pi + .01, .1),
        -math.pi + .01,
      ).abs(),
      lessThan(.001),
    );
  });

  test('brace lowers chassis through real leg joints without relocating planted feet', () {
    final rig = WalkerRig()
      ..braced = true
      ..reducedMotion = true;
    final feet = rig.legs.map((leg) => leg.foot).toList();
    rig.advance(2);
    expect(rig.height, 42);
    for (var i = 0; i < 4; i++) {
      expect(rig.legs[i].foot, feet[i]);
      final pose = rig.pose(rig.legs[i]);
      expect(
        (pose.ankle - pose.knee).length,
        closeTo(WalkerRig.lowerLength, .001),
      );
    }
  });
}
