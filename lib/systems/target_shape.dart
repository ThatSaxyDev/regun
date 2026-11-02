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

  double signedDistance(Offset p) => distanceToSegment(p, a, b) - radius;
  double distance(Offset p) => math.max(0, signedDistance(p));
  Offset outwardAt(Offset p) {
    final axis = b - a;
    final t = axis.distanceSquared < 1e-12
        ? 0.0
        : (((p - a).dx * axis.dx + (p - a).dy * axis.dy) / axis.distanceSquared)
              .clamp(0.0, 1.0);
    final delta = p - a - axis * t;
    return delta.distance < 1e-9 ? const Offset(1, 0) : delta / delta.distance;
  }

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

/// One damage/proc owner with locally destructible armor. Query hints are only
/// a fallback; swept bullets and blasts supply their authoritative hit geometry.
abstract interface class LocalDamageTarget {
  void noteDamageContact(Offset point);
  bool receiveLocalDamage(
    double amount, {
    Offset? point,
    Offset? blastCenter,
    double? blastRadius,
  });
}

/// Full ground footprint under a single occupancy owner, including inert spine.
abstract interface class CompoundGroundActor {
  Iterable<TargetCapsule> get groundShape;
}

/// Capsule intersected with the section's ground-mask half-plane. The renderer
/// clips to this same plane while a connected section enters/emerges.
class ClippedTargetCapsule extends TargetCapsule {
  const ClippedTargetCapsule(
    super.a,
    super.b,
    super.radius, {
    required this.origin,
    required this.normal,
    required this.limit,
  });
  final Offset origin, normal;
  final double limit;
  double side(Offset p) =>
      (p - origin).dx * normal.dx + (p - origin).dy * normal.dy - limit;
  @override
  double signedDistance(Offset p) => math.max(super.signedDistance(p), side(p));
  @override
  Offset outwardAt(Offset p) =>
      normal.distance > 1e-9 && side(p) >= super.signedDistance(p)
      ? normal / normal.distance
      : super.outwardAt(p);
  @override
  double? contact(Offset from, Offset to, {double padding = 0}) {
    final start = side(from) - padding, end = side(to) - padding;
    if (start > 0 && end > 0) return null;
    final length = (to - from).distance;
    final lo = start > 0 ? start / (start - end) : 0.0;
    final hi = end > 0 ? start / (start - end) : 1.0;
    final a = Offset.lerp(from, to, lo)!, b = Offset.lerp(from, to, hi)!;
    final hit = super.contact(a, b, padding: padding);
    return hit == null ? null : lo * length + hit;
  }
}
