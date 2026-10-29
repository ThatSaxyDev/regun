import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_escort_tactics.dart';

void main() {
  test(
    'moving-target acquisition intersects a straight bullet and bounds lead',
    () {
      const muzzle = Offset(-220, -70), target = Offset.zero;
      for (final velocity in [
        Offset.zero,
        const Offset(0, 300),
        const Offset(300, 0),
        const Offset(-200, 180),
      ]) {
        final aim = ArietEscortTactics.intercept(muzzle, target, velocity);
        final flight = (aim - muzzle).distance / 850;
        expect((aim - (target + velocity * flight)).distance, lessThan(.001));
        expect((aim - target).distance, lessThanOrEqualTo(180));
      }
      final far = ArietEscortTactics.intercept(
        const Offset(-2000, 0),
        target,
        const Offset(0, 300),
      );
      expect(far.distance, closeTo(180, .001));
    },
  );

  test('shared positioning prefers exposed firing sectors over a legal perch hidden by cover', () {
    final t = ArietEscortTactics();
    t.advance(
      .025,
      target: Offset.zero,
      velocity: Offset.zero,
      bodies: const [
        ArietEscortBody(1, Offset(400, 100)),
        ArietEscortBody(2, Offset(400, -100)),
      ],
      legal: (_, __) => true,
      sight: (from, to, radius) => from.dy >= -.01,
    );
    expect(t.goalFor(1)!.dy, greaterThanOrEqualTo(-.01));
    expect(t.goalFor(2)!.dy, greaterThanOrEqualTo(-.01));
    expect((t.goalFor(1)! - t.goalFor(2)!).distance, greaterThan(210));
  });
  test(
    'firing decision anticipates a teammate crossing during bullet flight',
    () {
      final t = ArietEscortTactics();
      t.advance(
        .025,
        target: Offset.zero,
        velocity: Offset.zero,
        legal: (_, __) => true,
        bodies: const [
          ArietEscortBody(1, Offset(-560, 0)),
          ArietEscortBody(2, Offset(-300, -120), velocity: Offset(0, 400)),
        ],
      );
      expect(t.firingLaneClear(1, const Offset(-455, 0), Offset.zero), isFalse);
      expect(
        t.firingLaneClear(
          1,
          const Offset(-455, 0),
          Offset.zero,
          bodies: const [ArietEscortBody(2, Offset(-300, -120))],
        ),
        isTrue,
      );
    },
  );
  void advance(
    ArietEscortTactics t,
    List<ArietEscortBody> bodies, {
    Offset player = Offset.zero,
    Offset velocity = Offset.zero,
    bool Function(Offset, double)? legal,
    double dt = .025,
  }) => t.advance(
    dt,
    target: player,
    velocity: velocity,
    bodies: bodies,
    legal: legal ?? (_, __) => true,
  );

  test(
    'lined-up escorts jointly take distinct player-relative firing angles',
    () {
      final t = ArietEscortTactics();
      const bodies = [
        ArietEscortBody(1, Offset(-400, 0)),
        ArietEscortBody(2, Offset(-560, 0)),
      ];
      advance(t, bodies);
      final a = t.goalFor(1)!, b = t.goalFor(2)!;
      expect(
        ArietEscortTactics.difference(
          ArietEscortTactics.angle(a),
          ArietEscortTactics.angle(b),
        ).abs(),
        greaterThan(1.5),
      );
      expect((a - b).distance, greaterThan(400));
      expect(a.dy * b.dy, lessThan(0));
      expect(t.firingLaneClear(2, const Offset(-455, 0), Offset.zero), isFalse);
      expect(t.firingLaneClear(1, const Offset(-295, 0), Offset.zero), isTrue);
    },
  );

  test('roles are stable regardless of actor update order; angular travel avoids cutting through the target', () {
    final a = ArietEscortTactics(), b = ArietEscortTactics();
    const one = ArietEscortBody(1, Offset(-300, 170)),
        two = ArietEscortBody(2, Offset(-300, -170));
    advance(a, [one, two]);
    advance(b, [two, one]);
    expect(a.goalFor(1), b.goalFor(1));
    expect(a.goalFor(2), b.goalFor(2));
    final goal = a.goalFor(1)!;
    final at = -goal;
    final waypoint = a.waypoint(1, at, (_, __) => true);
    expect(waypoint.distance, greaterThanOrEqualTo(280));
    expect((waypoint - goal).distance, greaterThan(40));
    final firstAngle = ArietEscortTactics.angle(goal);
    advance(a, [
      const ArietEscortBody(1, Offset(300, 170)),
      const ArietEscortBody(2, Offset(300, -170)),
    ], dt: .1);
    expect(
      ArietEscortTactics.difference(
        ArietEscortTactics.angle(a.goalFor(1)!),
        firstAngle,
      ).abs(),
      lessThanOrEqualTo(.0551),
    );
  });

  test(
    'both firing sectors respect cover and bounds and preserve an escape side',
    () {
      final t = ArietEscortTactics();
      bool legal(Offset p, double r) =>
          p.dx.abs() + r < 600 &&
          p.dy.abs() + r < 600 &&
          !(p.dx < -200 && p.dy < -40);
      advance(t, const [
        ArietEscortBody(1, Offset(-400, 100)),
        ArietEscortBody(2, Offset(-400, -100)),
      ], legal: legal);
      final a = t.goalFor(1)!, b = t.goalFor(2)!;
      expect(legal(a, 59.4), isTrue);
      expect(legal(b, 59.4), isTrue);
      final separation = ArietEscortTactics.difference(
        ArietEscortTactics.angle(a),
        ArietEscortTactics.angle(b),
      ).abs();
      expect(separation, greaterThan(.95));
      expect(separation, lessThan(math.pi));
    },
  );

  test('a narrow corridor yields a spaced rear position and blocks shooting through the partner', () {
    final t = ArietEscortTactics();
    bool legal(Offset p, double r) =>
        p.dx < -200 && p.dx > -650 && p.dy.abs() < 2;
    advance(t, const [
      ArietEscortBody(1, Offset(-330, 0)),
      ArietEscortBody(2, Offset(-540, 0)),
    ], legal: legal);
    final a = t.goalFor(1)!, b = t.goalFor(2)!;
    expect(legal(a, 59.4), isTrue);
    expect(legal(b, 59.4), isTrue);
    expect((a - b).distance, greaterThanOrEqualTo(209));
    expect(t.firingLaneClear(2, const Offset(-435, 0), Offset.zero), isFalse);
  });

  test(
    'ready shooters alternate; dead/absent partners never hold a firing role',
    () {
      final t = ArietEscortTactics();
      const a = ArietEscortBody(1, Offset(-330, 0)),
          b = ArietEscortBody(2, Offset(0, 330));
      advance(t, [a, b]);
      expect(t.preferredShooter([1, 2]), 1);
      t.noteVolley(1);
      expect(t.preferredShooter([1, 2]), 2);
      t.noteVolley(2);
      expect(t.preferredShooter([2]), 2);
      advance(t, [a]);
      expect(t.goalFor(2), isNull);
      expect(t.lastShooter, isNull);
      expect(t.preferredShooter([1]), 1);
      expect(t.firingLaneClear(1, const Offset(-225, 0), Offset.zero), isTrue);
    },
  );

  test(
    'zero/invalid time does not rotate a plan and reset retires its roles',
    () {
      final t = ArietEscortTactics();
      const bodies = [
        ArietEscortBody(1, Offset(-400, 0)),
        ArietEscortBody(2, Offset(-400, 100)),
      ];
      advance(t, bodies);
      final goal = t.goalFor(1), elapsed = t.elapsed;
      advance(t, bodies, player: const Offset(300, 100), dt: 0);
      advance(t, bodies, dt: double.nan);
      expect(t.goalFor(1), goal);
      expect(t.elapsed, elapsed);
      t.reset();
      expect(t.goalFor(1), isNull);
      expect(t.bodies, isEmpty);
    },
  );
}
