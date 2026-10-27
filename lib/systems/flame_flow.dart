import 'dart:math' as math;

import 'package:flame/components.dart';

class FlameTongue {
  FlameTongue(this.origin, this.direction, this.seed, this.reach);
  final Vector2 origin, direction;
  final int seed;
  final double reach;
  final position = Vector2.zero();
  double age = 0;
  double get distance => age * 650;
  double get life => (reach + 30) / 650;
}

/// Bounded advected material: tongues leave the nozzle, travel, spread and die.
/// It owns no damage or audio. The current stream front bounds cone damage.
class FlameFlow {
  final tongues = <FlameTongue>[];
  double sustained = 0, _emit = 0;
  int _serial = 0;
  bool _active = false;
  final _heading = Vector2(1, 0);
  double front(double range) => math.min(range, 35 + sustained * 650);
  void clear() {
    tongues.clear();
    sustained = _emit = 0;
    _active = false;
  }

  void advance(
    double dt, {
    required bool active,
    required Vector2 nozzle,
    required Vector2 direction,
    required double range,
    required Vector2 Function(Vector2, Vector2) clip,
    bool reducedMotion = false,
    double coneDegrees = 20,
  }) {
    if (active && (!_active || direction.dot(_heading) < .94)) {
      sustained = 0;
      _emit = .025;
    }
    _active = active;
    if (active) {
      sustained += dt;
      _heading.setFrom(direction);
      _emit += dt;
    } else {
      sustained = 0;
      _emit = 0;
    }
    if (active && _emit >= .025) {
      _emit -= .025;
      if (tongues.length < 18) {
        tongues.add(
          FlameTongue(
            nozzle.clone(),
            (direction.clone()
              ..rotate(((_serial % 5) - 2) * .14 * coneDegrees / 20)),
            _serial++,
            range,
          )..position.setFrom(nozzle),
        );
      }
    }
    for (final tongue in tongues) {
      final before = tongue.position.clone();
      tongue.age += dt;
      final side = Vector2(-tongue.direction.y, tongue.direction.x);
      final turbulence = reducedMotion
          ? 0.0
          : math.sin(tongue.age * 23 + tongue.seed * 1.7) *
                tongue.distance *
                .035;
      final proposed =
          tongue.origin +
          tongue.direction * tongue.distance +
          side * turbulence;
      final after = clip(before, proposed);
      if (after.distanceToSquared(proposed) > .01) {
        tongue.age = tongue.life;
      }
      tongue.position.setFrom(after);
    }
    tongues.removeWhere((p) => p.age >= p.life);
  }
}
