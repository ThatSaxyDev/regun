import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';

void main() {
  test('validated reverse can branch into a new forward bend instead of replaying a blocked route', () {
    final r = LodestarRig()..requestedSpeed = 220;
    for (var n = 0; n < 480; n++) {
      r.advance(1 / 120);
    }
    r.requestedSpeed = -220;
    for (var n = 0; n < 240; n++) {
      r.advance(1 / 120);
    }
    final before = r.poses.first.position;
    r.requestedSpeed = 220;
    r.desiredHeading = math.pi / 2;
    for (var n = 0; n < 240; n++) {
      r.advance(1 / 120);
      expect(LodestarRig.connected(r.poses), isTrue);
    }
    expect(r.poses.first.position.dy, greaterThan(before.dy + 120));
    expect(r.rejectedSteps, 0);
  });

  test('rotated spawn retains heading and actual coupling endpoints', () {
    final rig = LodestarRig(head: const Offset(100, 100), heading: math.pi / 2)
      ..requestedSpeed = 100;
    rig.advance(1 / 60);
    expect(rig.poses.first.yaw, closeTo(math.pi / 2, 1e-9));
    expect(rig.poses.first.position.dx, closeTo(100, 1e-9));
    expect(rig.couplings.first.length, closeTo(23, 1e-6));
  });
  test('wreck removes armor occupancy while retaining its actual spine', () {
    final rig = LodestarRig(head: const Offset(260, 0));
    final side = LodestarSpace(
      bounds: const Rect.fromLTRB(-2000, -2000, 2000, 2000),
      solids: [const TargetCapsule(Offset(-52, 40), Offset(-52, 40), 2)],
    );
    expect(side.accepts(rig.poses, rig.poses), isFalse);
    final broken = LodestarSpace(
      bounds: side.bounds,
      solids: side.solids,
      broken: (s) => s == LodestarSection.feeder,
    );
    expect(broken.accepts(rig.poses, rig.poses), isTrue);
    final spine = LodestarSpace(
      bounds: side.bounds,
      solids: [const TargetCapsule(Offset(-52, 0), Offset(-52, 0), 2)],
      broken: (s) => s == LodestarSection.feeder,
    );
    expect(spine.accepts(rig.poses, rig.poses), isFalse);
  });
  test(
    'fixed 120Hz arc-length following agrees at 30/60/120Hz without stretching',
    () {
      LodestarRig simulate(int hz) {
        final r = LodestarRig();
        for (var i = 0; i < hz * 30; i++) {
          r.advance(
            1 / hz,
            beforeStep: (t) {
              r.requestedSpeed = 260;
              r.desiredHeading = t * 260 / 320;
            },
          );
          expect(LodestarRig.connected(r.poses), isTrue);
          for (var j = 0; j < 5; j++) {
            expect(
              (r.poses[j].position - r.poses[j + 1].position).distance,
              inInclusiveRange(102.0, 104.001),
            );
            expect(r.couplings[j].length, inInclusiveRange(15.0, 32.0));
          }
        }
        expect(r.rejectedSteps, 0);
        expect(r.historySamples, lessThan(1400));
        return r;
      }

      final a = simulate(30), b = simulate(60), c = simulate(120);
      for (var i = 0; i < 6; i++) {
        expect(
          (a.poses[i].position - b.poses[i].position).distance,
          lessThan(1e-6),
        );
        expect(
          (b.poses[i].position - c.poses[i].position).distance,
          lessThan(1e-6),
        );
      }
    },
  );
  test('stopped body never turns in place, reverse retraces accepted curved history', () {
    final r = LodestarRig();
    final at = r.poses;
    r.desiredHeading = math.pi;
    for (var i = 0; i < 120; i++) {
      r.advance(1 / 120);
    }
    expect(r.poses.first.position, at.first.position);
    expect(r.poses.first.yaw, at.first.yaw);
    r.requestedSpeed = 220;
    r.desiredHeading = 1;
    for (var i = 0; i < 120 * 4; i++) {
      r.advance(1 / 120);
    }
    final front = r.poses.first.position, before = r.signedTravel;
    r.requestedSpeed = -220;
    r.desiredHeading = -2; // Reverse cannot invent a new unvalidated path.
    for (var i = 0; i < 120 * 2; i++) {
      r.advance(1 / 120);
    }
    expect(r.signedTravel, lessThan(before - 300));
    expect((r.poses.first.position - front).distance, greaterThan(250));
    expect(r.rejectedSteps, 0);
    expect(LodestarRig.connected(r.poses), isTrue);
    expect(r.rollerTravel, r.signedTravel);
  });
  test(
    'full-body cover sweep rejects a middle carriage even when head is clear',
    () {
      final r = LodestarRig(head: const Offset(260, -60));
      final from = r.poses;
      final to = [
        for (final p in from)
          LodestarPose(p.section, p.position + const Offset(0, 120), p.yaw),
      ];
      final space = LodestarSpace(
        bounds: const Rect.fromLTRB(-2000, -2000, 2000, 2000),
        solids: [const TargetCapsule(Offset(-52, 0), Offset(-52, 0), 2)],
      );
      expect(space.accepts(from, to), isFalse);
      // Same narrow obstacle in an actual empty bend/away from all bodies is legal.
      final empty = LodestarSpace(
        bounds: space.bounds,
        solids: [const TargetCapsule(Offset(600, 0), Offset(600, 0), 2)],
      );
      expect(empty.accepts(from, to), isTrue);
    },
  );
  test('player/body crossing and structural coupling occupancy are swept', () {
    final r = LodestarRig(head: const Offset(260, -60));
    final to = [
      for (final p in r.poses)
        LodestarPose(p.section, p.position + const Offset(0, 120), p.yaw),
    ];
    final space = LodestarSpace(
      bounds: const Rect.fromLTRB(-2000, -2000, 2000, 2000),
      bodies: [const TargetCapsule(Offset(52, 0), Offset(52, 0), 26)],
    );
    expect(space.accepts(r.poses, to), isFalse);
    final link = r.couplings[2];
    expect(link.footprint.distance((link.a + link.b) / 2), 0);
  });
  test(
    'rejected pose never records a path, yaw or partial follower movement',
    () {
      final r = LodestarRig(acceptPose: (_, _) => false)
        ..requestedSpeed = 260
        ..desiredHeading = 1;
      final poses = r.poses, history = r.historySamples;
      for (var i = 0; i < 120; i++) {
        r.advance(1 / 120);
      }
      expect(r.rejectedSteps, 120);
      expect(r.historySamples, history);
      expect(r.signedTravel, 0);
      for (var i = 0; i < 6; i++) {
        expect(r.poses[i].position, poses[i].position);
        expect(r.poses[i].yaw, poses[i].yaw);
      }
    },
  );
  test(
    'wall stops whole moving rig; pause and invalid deltas cannot change state',
    () {
      final space = LodestarSpace(
        bounds: const Rect.fromLTRB(-1200, -1000, 400, 1000),
      );
      final r = LodestarRig(
        head: const Offset(260, 0),
        acceptPose: space.accepts,
      )..requestedSpeed = 260;
      for (var i = 0; i < 120 * 4; i++) {
        r.advance(1 / 120);
      }
      expect(r.poses.first.position.dx, lessThan(358));
      expect(r.rejectedSteps, greaterThan(0));
      final before = r.poses, clock = r.elapsed;
      r.paused = true;
      r.advance(20);
      r.paused = false;
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        r.advance(invalid);
      }
      expect(r.elapsed, clock);
      expect(r.poses.first.position, before.first.position);
    },
  );
  test('self crossing anatomy rejected; wreck footprint remains narrow structural spine', () {
    final r = LodestarRig();
    final poses = r.poses;
    final folded = [...poses]
      ..[5] = LodestarPose(LodestarSection.tail, poses[0].position, 0);
    expect(LodestarRig.connected(folded), isFalse);
    expect(poses[3].footprint(broken: true).radius, 11);
    expect(poses[3].footprint().radius, 42);
  });
}
