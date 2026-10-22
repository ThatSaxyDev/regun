import 'dart:ui';

/// Ground travel drives a heavy stride, retaining footfall phase across turns.
class MummyWalk {
  static const distancePerFrame = 9.0;
  double distance = 0;
  bool left = false;
  Offset? _position;
  int get frame => (distance / distancePerFrame).floor() % 8;

  void follow(Offset position, {required bool walking, double? facingX}) {
    final delta = _position == null ? Offset.zero : position - _position!;
    _position = position;
    // Reconnect/relocation is not a step. Near-vertical travel retains facing.
    if (walking && delta.distance > .001 && delta.distance < 120) {
      distance = (distance + delta.distance) % (distancePerFrame * 8);
      if (delta.dx.abs() > delta.dy.abs() * .2 && delta.dx.abs() > .01) {
        left = delta.dx < 0;
      }
    } else if (!walking && facingX != null && facingX.abs() > .05) {
      left = facingX < 0;
    }
  }
}
