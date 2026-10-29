import 'dart:math' as math;
import 'dart:ui';

/// Opt-in world-space narrow phase; ordinary actors retain their old circles.
abstract interface class ShapedTarget {
  Iterable<TargetCapsule> get targetShape;
}

class TargetCapsule {
  const TargetCapsule(this.a, this.b, this.radius);
  final Offset a, b;
  final double radius;
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final d = b - a;
    final t = d.distanceSquared < 1e-12
        ? 0.0
        : ((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared;
    return (p - a - d * t.clamp(0.0, 1.0)).distance;
  }

  double distance(Offset p) => math.max(0, distanceToSegment(p, a, b) - radius);
  double? contact(Offset from, Offset to, {double padding = 0}) {
    final r = radius + padding, delta = to - from, length = delta.distance;
    if (distanceToSegment(from, a, b) <= r) return 0;
    if (length < 1e-10) return null;
    final direction = delta / length;
    double? best;
    void accept(double t) {
      if (t >= 0 && t <= length && (best == null || t < best!)) best = t;
    }

    for (final p in [a, b]) {
      final v = from - p,
          projection = v.dx * direction.dx + v.dy * direction.dy;
      final disc = projection * projection - v.distanceSquared + r * r;
      if (disc >= 0) accept(-projection - math.sqrt(disc));
    }
    final axis = b - a, size = axis.distance;
    if (size > 1e-9) {
      final u = axis / size, v = Offset(-u.dy, u.dx), rel = from - a;
      var lo = 0.0, hi = length;
      for (final entry in [
        (
          rel.dx * u.dx + rel.dy * u.dy,
          direction.dx * u.dx + direction.dy * u.dy,
          0.0,
          size,
        ),
        (
          rel.dx * v.dx + rel.dy * v.dy,
          direction.dx * v.dx + direction.dy * v.dy,
          -r,
          r,
        ),
      ]) {
        final (origin, speed, min, max) = entry;
        if (speed.abs() < 1e-10) {
          if (origin < min || origin > max) {
            hi = -1;
            break;
          }
        } else {
          final x = (min - origin) / speed, y = (max - origin) / speed;
          lo = math.max(lo, math.min(x, y));
          hi = math.min(hi, math.max(x, y));
        }
      }
      if (lo <= hi) accept(lo);
    }
    return best;
  }
}
