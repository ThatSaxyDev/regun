import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/ariet_escort_study.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/views/ariet_workshop_view.dart';

void main() {
  test('live hover stays active without navigation drift, freezes on pause and settles in Reduced Motion', () {
    final r = ArietRig()
      ..hoverMotion = true
      ..hoverElevation = 160;
    final heights = <double>[], lateral = <double>[], flows = <double>[];
    for (var i = 0; i < 360; i++) {
      r.advance(1 / 120);
      heights.add(r.height);
      lateral.add(r.bodyPosition.dx);
      flows.add(r.jetFlow(0, 0));
      expect(r.position, Offset.zero);
      expect(r.height, inInclusiveRange(153.0, 167.0));
      expect(r.hoverOffset.dx.abs(), lessThanOrEqualTo(4.5));
    }
    expect(heights.reduce(math.max) - heights.reduce(math.min), greaterThan(4));
    expect(lateral.reduce(math.max) - lateral.reduce(math.min), greaterThan(2));
    expect(flows.toSet().length, greaterThan(100));
    final body = r.bodyPosition, flow = r.jetFlow(0, 0);
    r.paused = true;
    r.advance(3);
    expect(r.bodyPosition, body);
    expect(r.jetFlow(0, 0), flow);
    r.paused = false;
    r.reducedMotion = true;
    r.advance(.1);
    expect(r.hoverOffset, Offset.zero);
    expect(r.height, 160);
  });
  test('jet thrust axis matches the painted nozzle for every yaw and pod tilt without bending', () {
    final r = ArietRig();
    for (final reduced in [false, true]) {
      r.reducedMotion = reduced;
      for (var i = 0; i < 24; i++) {
        r.yaw = i * math.pi / 12;
        for (final tilt in [-.3, 0.0, .3]) {
          r.podAngle = tilt;
          r.pitch = .04;
          r.bank = -.08;
          for (var nozzle = 0; nozzle < 2; nozzle++) {
            final paintedAxis =
                r.projectOnPod(nozzle, const Offset(-145, 0), z: -12) -
                r.projectOnPod(nozzle, const Offset(-114, 0), z: -12);
            expect(
              (r.engineDirection(nozzle) - paintedAxis / paintedAxis.distance)
                  .distance,
              lessThan(1e-10),
            );
          }
        }
      }
    }
  });
  test('engine smoke is bounded, advances on the simulation clock and settles in Reduced Motion', () {
    final r = ArietRig()..hoverElevation = 160;
    r.advance(.5);
    expect(r.exhaustPuffs, isNotEmpty);
    expect(r.exhaustPuffs.length, lessThanOrEqualTo(ArietRig.exhaustLimit));
    final puff = r.exhaustPuffs.first, at = r.exhaustPuffs.first.position;
    r.paused = true;
    r.advance(4);
    expect(puff.position, at);
    r.paused = false;
    r.advance(.1);
    expect(puff.position, isNot(at));
    r.command = const Offset(220, 0);
    r.advance(20);
    expect(r.exhaustPuffs.length, lessThanOrEqualTo(ArietRig.exhaustLimit));
    r.reducedMotion = true;
    r.advance(ArietRig.tick);
    expect(r.exhaustPuffs, isEmpty);
    final low = r.bodyPosition;
    expect(r.project(Offset.zero), low);
    r.reducedMotion = false;
    r.enginesRunning = false;
    r.advance(2);
    expect(r.exhaustPuffs, isEmpty);
  });
  test('fixed-tick navigation/rig matches at 30, 60 and 120 Hz', () {
    final runs = <ArietWorkshopController>[];
    for (final hz in [30, 60, 120]) {
      final c = ArietWorkshopController();
      for (final demo in [
        ArietDemo.accelerate,
        ArietDemo.strafe,
        ArietDemo.turn,
      ]) {
        c.choose(demo);
        for (var i = 0; i < 12 * hz; i++) {
          c.advance(1 / hz);
        }
      }
      runs.add(c);
    }
    final first = runs.first.rig;
    for (final c in runs.skip(1)) {
      expect((c.rig.position - first.position).distance, lessThan(1e-7));
      expect((c.rig.velocity - first.velocity).distance, lessThan(1e-7));
      expect(c.rig.yaw, closeTo(first.yaw, 1e-9));
      expect(c.rig.podAngle, closeTo(first.podAngle, 1e-9));
    }
    for (final c in runs) {
      c.dispose();
    }
  });
  test(
    'pause freezes every mechanism; deliberate step advances exactly two ticks',
    () {
      final c = ArietWorkshopController()..choose(ArietDemo.accelerate);
      c.advance(1);
      c.paused = true;
      final p = c.rig.position, t = c.rig.elapsed, pod = c.rig.podAngle;
      c.advance(5);
      expect(c.rig.position, p);
      expect(c.rig.elapsed, t);
      expect(c.rig.podAngle, pod);
      c.advance(1 / 60, singleStep: true);
      expect(c.rig.elapsed, closeTo(t + 1 / 60, 1e-10));
      c.restart();
      expect(c.rig.position, Offset.zero);
      expect(c.rig.elapsed, 0);
      expect(c.paused, isTrue);
      c.dispose();
    },
  );
  test('idle is steady; stop and reversal are bounded, pods stay attached', () {
    final r = ArietRig();
    r.advance(8);
    expect(r.position, Offset.zero);
    expect(r.bank, 0);
    expect(r.height, ArietRig.hoverHeight);
    r.command = const Offset(220, 0);
    r.advance(2);
    expect(r.velocity.dx, closeTo(220, 1e-6));
    final old = r.velocity.dx;
    r.command = const Offset(-220, 0);
    r.advance(ArietRig.tick);
    expect(r.velocity.dx, lessThan(old));
    expect(r.velocity.dx, greaterThan(0));
    for (var i = 0; i < 200; i++) {
      r.advance(ArietRig.tick);
      expect(r.podAngle.abs(), lessThanOrEqualTo(ArietRig.podLimit));
      for (var n = 0; n < 2; n++) {
        expect(
          (r.podSocket(n) - r.position).distance,
          closeTo(ArietRig.podMounts[n].distance, 1e-8),
        );
      }
    }
    r.command = Offset.zero;
    r.advance(2);
    final stopped = r.position;
    r.advance(5);
    expect((r.position - stopped).distance, lessThan(1e-8));
    expect(r.bank, closeTo(0, 1e-8));
    expect(r.pitch, closeTo(0, 1e-8));
  });
  test(
    'yaw crosses wrap by short route, bounded; no navigation from gun yaw',
    () {
      final r = ArietRig()
        ..yaw = math.pi - .05
        ..desiredYaw = -math.pi + .05;
      r.advance(ArietRig.tick);
      expect(r.yaw, greaterThan(math.pi - .05));
      r.advance(1);
      expect(ArietRig.difference(r.yaw, -math.pi + .05), closeTo(0, 1e-8));
      final root = r.position;
      r.cannonYaw = -1;
      r.advance(1);
      expect(r.position, root);
      expect(ArietRig.difference(r.yaw, -math.pi + .05), closeTo(0, 1e-8));
    },
  );
  test(
    'reduced motion preserves positions, ground sockets and thrust decisions',
    () {
      final normal = ArietRig(), reduced = ArietRig()..reducedMotion = true;
      for (final r in [normal, reduced]) {
        r.command = const Offset(120, 160);
        r.desiredYaw = 1;
        r.advance(2);
      }
      expect(normal.position, reduced.position);
      expect(normal.yaw, reduced.yaw);
      expect(normal.cargoSocket(0), reduced.cargoSocket(0));
      expect(normal.noseSocket(1), reduced.noseSocket(1));
      expect(reduced.bank, 0);
      expect(reduced.pitch, 0);
      expect(normal.bank.abs(), greaterThan(.001));
    },
  );
  test('supplied arena resolver stops fast travel at cover and bounds', () {
    final geometry = ArenaGeometry(
      const ArenaBounds(Rect.fromLTRB(-1000, -700, 1000, 700)),
      obstacles: [const Rect.fromLTRB(250, -500, 280, 500)],
    );
    final r =
        ArietRig(
            resolveMove: (from, to) {
              final p = Vector2(from.dx, from.dy);
              geometry.move(
                p,
                Vector2(to.dx - from.dx, to.dy - from.dy),
                ArietRig.navigationRadius,
              );
              return Offset(p.x, p.y);
            },
          )
          ..speedLimit = ArietRig.passSpeed
          ..command = const Offset(420, 0);
    r.advance(5);
    expect(r.position.dx, closeTo(250 - ArietRig.navigationRadius, 1e-6));
    expect(r.velocity.distance, lessThan(1e-6));
    r.command = const Offset(-420, 0);
    r.advance(8);
    expect(
      r.position.dx,
      greaterThanOrEqualTo(
        geometry.bounds.interior.left + ArietRig.navigationRadius,
      ),
    );
  });
  test(
    'escort adapter scales actual IK, feet, target body and muzzle together',
    () {
      for (final scale in [.65, .675, .7]) {
        final e = ArietEscortStudy(scale: scale);
        for (final leg in e.rig.legs) {
          final p = e.pose(leg);
          expect((p.knee - p.hip).length, closeTo(110 * scale, 1e-6));
          expect((p.ankle - p.knee).length, closeTo(130 * scale, 1e-6));
          expect(e.foot(leg), leg.foot * scale);
        }
        expect(e.bodyRadius, 88 * scale);
        expect(e.muzzle.ground, e.rig.muzzle.ground * scale);
        expect(e.muzzle.z, e.rig.muzzle.z * scale);
        expect(e.muzzleClearance, 13 * scale);
      }
      final full = WalkerRig()..folded = true;
      expect(full.foldedReach, .72);
      for (final leg in full.legs) {
        expect(full.pose(leg).ankle.ground, full.ground(leg.rest * .72));
      }
    },
  );
  test('both folded candidate envelopes fit rails without overlap', () {
    for (final scale in [.65, .675, .7]) {
      final e = ArietEscortStudy(scale: scale, folded: true);
      final front = e.cargoEnvelope.shift(ArietRig.cargoMounts[1]),
          rear = e.cargoEnvelope.shift(ArietRig.cargoMounts[0]);
      expect(front.overlaps(rear), isFalse);
      expect(front.right, lessThanOrEqualTo(160));
      expect(rear.left, greaterThanOrEqualTo(-160));
      expect(front.height, lessThanOrEqualTo(136));
      for (final leg in e.rig.legs) {
        final pose = e.pose(leg);
        expect((pose.knee - pose.hip).length, closeTo(e.upperLength, 1e-5));
        expect((pose.ankle - pose.knee).length, closeTo(e.lowerLength, 1e-5));
      }
    }
  });
  test(
    'loaded clearance keeps tucked knees above floor and feet under deck',
    () {
      final c = ArietWorkshopController()..choose(ArietDemo.cargo);
      c.advance(1);
      final e = ArietEscortStudy(folded: true);
      for (final leg in e.rig.legs) {
        final pose = e.pose(leg);
        double carrierZ(double z) =>
            c.rig.height - 28 + z - e.rig.height * e.scale;
        expect(carrierZ(pose.knee.z), greaterThan(12));
        expect(carrierZ(pose.ankle.z), lessThan(c.rig.height));
        expect((pose.knee - pose.hip).length, closeTo(e.upperLength, 1e-6));
      }
      c.dispose();
    },
  );
  test('inspection input follows zoom/root; invalid dt never advances', () {
    final c = ArietWorkshopController()..inspect = true;
    c.rig.position = const Offset(280, 10);
    const size = Size(844, 250), p = Offset(-20, 40);
    expect(
      (c.worldPoint(c.viewOrigin(size) + p * c.viewScale(size), size) - p)
          .distance,
      lessThan(1e-8),
    );
    c.advance(double.nan);
    c.advance(-1);
    expect(c.rig.elapsed, 0);
    c.dispose();
  });
}
