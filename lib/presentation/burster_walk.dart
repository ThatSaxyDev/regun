import 'dart:ui';

/// Authored facing rows and actual-distance gait: no sprite translation/leg rig.
class BursterWalk {
  static int frame(Offset direction, double distance) {
    final row = direction.dy.abs() > direction.dx.abs()
        ? (direction.dy > 0 ? 0 : 1)
        : (direction.dx >= 0 ? 2 : 3);
    return row * 4 + (distance / 14).floor() % 4;
  }
}
