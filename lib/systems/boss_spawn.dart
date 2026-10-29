import 'dart:math' as math;
import 'dart:ui';

/// Search distant authored-arena positions, rejecting a clamped point if it
/// loses clearance. No fallback may move an arrival onto the survivor.
class BossSpawn {
  static const minimumDistance = 700.0;
  static Offset? choose({
    required Offset player,
    required Rect bounds,
    required double footprint,
    required bool Function(Offset, double) legal,
    bool companion = false,
  }) {
    final room = bounds.deflate(footprint + .01);
    if (room.isEmpty) return null;
    for (final distance in [1000.0, 900.0, 800.0, 1200.0]) {
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8 + (companion ? math.pi : 0);
        final raw = player + Offset(math.cos(a), math.sin(a)) * distance;
        final point = Offset(
          raw.dx.clamp(room.left, room.right),
          raw.dy.clamp(room.top, room.bottom),
        );
        if ((point - player).distance < minimumDistance ||
            !legal(point, footprint)) {
          continue;
        }
        return point;
      }
    }
    return null;
  }
}
