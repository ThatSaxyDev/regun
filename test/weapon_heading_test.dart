import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/weapon_heading.dart';

void main() {
  test('gun holds last aim briefly then turns smoothly toward running', () {
    final heading = WeaponHeading();
    var direction = const Offset(-1, 0);
    direction = heading.advance(
      direction,
      const Offset(1, 0),
      Offset.zero,
      .65,
    );
    expect(direction, const Offset(-1, 0));
    direction = heading.advance(direction, const Offset(1, 0), Offset.zero, .1);
    expect(direction.dx, greaterThan(-1));
    expect(direction.dx, lessThan(.9));
    for (var i = 0; i < 60; i++) {
      direction = heading.advance(
        direction,
        const Offset(1, 0),
        Offset.zero,
        1 / 60,
      );
    }
    expect(direction.dx, closeTo(1, .001));
    expect(direction.dy, closeTo(0, .001));
  });
  test('deliberate aim wins immediately and resets resting delay, stationary holds', () {
    final heading = WeaponHeading();
    var direction = heading.advance(
      const Offset(1, 0),
      const Offset(1, 0),
      const Offset(0, -1),
      2,
    );
    expect(direction, const Offset(0, -1));
    expect(heading.idle, 0);
    direction = heading.advance(direction, const Offset(1, 0), Offset.zero, .6);
    expect(direction, const Offset(0, -1));
    direction = heading.advance(direction, Offset.zero, Offset.zero, 2);
    expect(direction, const Offset(0, -1));
  });
  test('turn crosses the short angular route; reduced motion settles without sweep', () {
    final heading = WeaponHeading();
    heading.idle = 1;
    final current = Offset(math.cos(3.1), math.sin(3.1)),
        target = Offset(math.cos(-3.1), math.sin(-3.1));
    final next = heading.advance(current, target, Offset.zero, .1);
    expect((next - target).distance, lessThan(.001));
    expect(
      heading.advance(
        const Offset(1, 0),
        const Offset(-1, 0),
        Offset.zero,
        .1,
        reducedMotion: true,
      ),
      const Offset(-1, 0),
    );
  });
}
