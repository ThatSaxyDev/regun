import 'dart:math' as math;
import 'dart:ui';

/// Bounded constant-velocity intercept. A released round never homes.
Offset supportAim(Offset pivot, Offset target, Offset velocity, double speed) {
  if (!velocity.dx.isFinite || !velocity.dy.isFinite || speed <= 0) {
    return target;
  }
  if (velocity.distance > 1200) velocity *= 1200 / velocity.distance;
  final r = target - pivot;
  const muzzle = 56.0;
  if (r.distance <= muzzle) return target;
  final a = velocity.distanceSquared - speed * speed;
  final b = 2 * (r.dx * velocity.dx + r.dy * velocity.dy - muzzle * speed);
  final c = r.distanceSquared - muzzle * muzzle;
  final roots = <double>[];
  if (a.abs() < 1e-6) {
    if (b.abs() > 1e-6) roots.add(-c / b);
  } else {
    final d = b * b - 4 * a * c;
    if (d >= 0) {
      roots.addAll([
        (-b - math.sqrt(d)) / (2 * a),
        (-b + math.sqrt(d)) / (2 * a),
      ]);
    }
  }
  final positive = roots.where((t) => t.isFinite && t >= 0).toList()..sort();
  if (positive.isEmpty) return target;
  var lead = velocity * positive.first.clamp(0.0, .55);
  if (lead.distance > 140) lead *= 140 / lead.distance;
  return target + lead;
}

/// A brief receipt of real flight/contact, so a round consumed in one update is
/// still visible. It has no collision, damage, save or reward ownership.
class SupportTrace {
  SupportTrace(this.from, this.to, this.direction);
  final Offset from, to, direction;
  double age = 0;
  static const duration = .09;
}
