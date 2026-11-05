import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/loadout.dart';

/// Local weapon pose, relative to the grip. It never changes ballistic aim.
class GunplayFlourish {
  double _age = 0, _duration = 0, _turn = 0, _lift = 0;

  void reload(WeaponType weapon) {
    if (weapon == WeaponType.revolver) {
      _start(.23, -2 * math.pi, 5);
    } else if (weapon == WeaponType.shotgun) {
      _start(.17, .57, 3);
    }
  }

  void landDash(WeaponType weapon, {required bool escaped}) {
    if (weapon != WeaponType.revolver && weapon != WeaponType.shotgun) return;
    if (escaped && weapon == WeaponType.revolver) {
      _start(.23, -2 * math.pi, 5);
    } else if (_duration == 0) {
      _start(.13, weapon == WeaponType.shotgun ? .32 : -.40, 2);
    }
  }

  void _start(double duration, double turn, double lift) {
    _duration = duration;
    _turn = turn;
    _lift = lift;
    _age = 0;
  }

  void advance(double dt) {
    _age += dt;
    if (_age >= _duration) clear();
  }

  void clear() => _duration = 0;

  ({double angle, double lift}) get pose {
    if (_duration == 0) return (angle: 0, lift: 0);
    final t = _age / _duration;
    final arc = math.sin(math.pi * t);
    // The full roll accelerates out of the hand and settles into the catch.
    final spin = t * t * (3 - 2 * t);
    return (
      angle: _turn * (_turn.abs() > math.pi ? spin : arc),
      lift: _lift * arc,
    );
  }
}

/// A near miss compares the projectile and hurtbox over the same frame.
bool isDashNearMiss({
  required Offset dashStart,
  required Offset playerBefore,
  required Offset playerAfter,
  required Offset shotBefore,
  required Offset shotAfter,
  required double contact,
}) {
  final shotStep = shotAfter - shotBefore;
  final relativeStart = shotBefore - playerBefore;
  final relativeStep = shotStep - (playerAfter - playerBefore);
  double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  final relativeLength = relativeStep.distanceSquared;
  if (relativeLength == 0 || shotStep.distanceSquared == 0) return false;
  final pass = -dot(relativeStart, relativeStep) / relativeLength;
  if (pass <= 0 || pass > 1) return false;
  final separation = (relativeStart + relativeStep * pass).distanceSquared;
  if (separation <= contact * contact ||
      separation > (contact + 24) * (contact + 24)) {
    return false;
  }
  final oldPosition = dashStart - shotBefore;
  final closest = (dot(oldPosition, shotStep) / shotStep.distanceSquared).clamp(
    0.0,
    1.0,
  );
  return (oldPosition - shotStep * closest).distanceSquared <=
      contact * contact;
}
