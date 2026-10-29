import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/target_shape.dart';

class ArietEscortBody {
  const ArietEscortBody(
    this.id,
    this.position, {
    this.radius = 59.4,
    this.velocity = Offset.zero,
  });
  final int id;
  final Offset position, velocity;
  final double radius;
}

/// One shared plan for the living pair. Roles are relative to the player and
/// allocated together, rather than two independent world-axis pursuit offsets.
class ArietEscortTactics {
  final _sides = <int, double>{};
  final _goals = <int, Offset>{};
  List<ArietEscortBody> _bodies = const [];
  Offset player = Offset.zero;
  double? _anchor;
  int? lastShooter;
  double elapsed = 0;
  static const flankAngle = 1.0, standOff = 330.0;

  static Offset unit(double a) => Offset(math.cos(a), math.sin(a));
  static double angle(Offset p) => math.atan2(p.dy, p.dx);
  static double difference(double a, double b) =>
      (a - b + math.pi) % (2 * math.pi) - math.pi;

  /// Constant-velocity interception, capped so reversals remain dodgeable.
  /// Only acquisition predicts; a released round always travels straight.
  static Offset intercept(Offset muzzle, Offset target, Offset velocity) {
    final delta = target - muzzle;
    const speed = 850.0;
    final a = velocity.distanceSquared - speed * speed;
    final b = 2 * (delta.dx * velocity.dx + delta.dy * velocity.dy);
    final c = delta.distanceSquared;
    double time = delta.distance / speed;
    final discriminant = b * b - 4 * a * c;
    if (a.abs() > 1e-6 && discriminant >= 0) {
      final root = math.sqrt(discriminant);
      final times = [
        (-b - root) / (2 * a),
        (-b + root) / (2 * a),
      ].where((t) => t >= 0);
      if (times.isNotEmpty) time = times.reduce(math.min);
    }
    var lead = velocity * time.clamp(0, .6);
    if (lead.distance > 180) lead = lead / lead.distance * 180;
    return target + lead;
  }

  Offset? goalFor(int id) => _goals[id];
  Iterable<ArietEscortBody> get bodies => _bodies;
  void reset() {
    _sides.clear();
    _goals.clear();
    _bodies = const [];
    _anchor = null;
    lastShooter = null;
    elapsed = 0;
  }

  void advance(
    double dt, {
    required Offset target,
    required Offset velocity,
    required Iterable<ArietEscortBody> bodies,
    required bool Function(Offset, double) legal,
    bool Function(Offset, Offset, double)? sight,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    elapsed += dt;
    player = target;
    _bodies = bodies.toList()..sort((a, b) => a.id.compareTo(b.id));
    final ids = _bodies.map((b) => b.id).toSet();
    _sides.removeWhere((id, _) => !ids.contains(id));
    _goals.removeWhere((id, _) => !ids.contains(id));
    if (!ids.contains(lastShooter)) lastShooter = null;
    if (_bodies.isEmpty) return;
    final midpoint =
        _bodies.fold(Offset.zero, (Offset p, b) => p + b.position) /
        _bodies.length.toDouble();
    final rel = midpoint - player;
    final wanted = rel.distance > 100
        ? angle(rel)
        : (_anchor ?? angle(_bodies.first.position - player));
    _anchor ??= wanted;
    _anchor =
        _anchor! + difference(wanted, _anchor!).clamp(-.55 * dt, .55 * dt);
    final lead = velocity.distance > 1
        ? velocity * (math.min(80, velocity.distance * .3) / velocity.distance)
        : Offset.zero;
    final centre = player + lead;
    if (_bodies.length >= 2 && _sides.length < 2) {
      final left = centre + unit(_anchor! - flankAngle) * standOff;
      final right = centre + unit(_anchor! + flankAngle) * standOff;
      final a = _bodies[0], b = _bodies[1];
      final direct =
          (a.position - left).distanceSquared +
          (b.position - right).distanceSquared;
      final swapped =
          (a.position - right).distanceSquared +
          (b.position - left).distanceSquared;
      _sides[a.id] = direct <= swapped ? -1 : 1;
      _sides[b.id] = -_sides[a.id]!;
    }
    final selected = <Offset>[];
    for (final body in _bodies) {
      final side = _sides[body.id] ?? 1;
      final desiredAngle =
          _anchor! + (_bodies.length > 1 ? side * flankAngle : 0);
      Offset? best;
      var score = double.infinity;
      // Bounded cover/bounds alternatives preserve the allocated firing sector.
      for (final radius in [330.0, 390.0, 270.0, 540.0]) {
        for (final offset in [0.0, .3, -.3, .6, -.6, .9, -.9, 1.0, -1.0]) {
          final candidate =
              centre + unit(desiredAngle + offset * side) * radius;
          if (!legal(candidate, body.radius)) continue;
          final bodyCrowded = selected.any(
            (p) => (p - candidate).distance < 210,
          );
          final laneCrowded = selected.any(
            (p) =>
                difference(angle(p - player), angle(candidate - player)).abs() <
                .95,
          );
          final covered = sight != null && !sight(candidate, player, 6);
          final value =
              (covered ? 2500 : 0) +
              offset.abs() * 160 +
              (radius - standOff).abs() * .4 +
              (candidate - body.position).distance * .08 +
              (bodyCrowded ? 5000 : 0) +
              (laneCrowded ? 2000 : 0);
          if (value < score) {
            score = value;
            best = candidate;
          }
        }
      }
      _goals[body.id] = best ?? body.position;
      selected.add(_goals[body.id]!);
    }
  }

  /// An angular waypoint gets a flanker around the player/partner instead of
  /// cutting a straight chord through both bodies and the same firing lane.
  Offset waypoint(int id, Offset at, bool Function(Offset, double) legal) {
    final goal = _goals[id] ?? at;
    final radial = at - player, goalRadial = goal - player;
    final radius = radial.distance;
    final turn = difference(angle(goalRadial), angle(radial));
    if (_bodies.length > 1 && radius < 480 && radius > 60 && turn.abs() > .35) {
      final point =
          player +
          unit(angle(radial) + turn.clamp(-.55, .55)) * math.max(280, radius);
      final body = _bodies.firstWhere((b) => b.id == id);
      if (legal(point, body.radius)) return point;
    }
    return goal;
  }

  bool firingLaneClear(
    int id,
    Offset muzzle,
    Offset target, {
    Iterable<ArietEscortBody>? bodies,
  }) {
    final line = target - muzzle, length2 = line.distanceSquared;
    if (length2 < 1) return false;
    for (final other in bodies ?? _bodies) {
      if (other.id == id) continue;
      final time = math.min(.45, math.sqrt(length2) / 850);
      final future = other.position + other.velocity * time;
      final along =
          ((other.position - muzzle).dx * line.dx +
              (other.position - muzzle).dy * line.dy) /
          length2;
      final futureAlong =
          ((future - muzzle).dx * line.dx + (future - muzzle).dy * line.dy) /
          length2;
      if (math.min(along, futureAlong) < 1 &&
          TargetCapsule(
                other.position,
                future,
                other.radius + 16,
              ).contact(muzzle, target) !=
              null) {
        return false;
      }
    }
    return true;
  }

  int? preferredShooter(Iterable<int> ready) {
    final ids = ready.toList()..sort();
    if (ids.isEmpty) return null;
    return ids.firstWhere((id) => id != lastShooter, orElse: () => ids.first);
  }

  void noteVolley(int id) => lastShooter = id;
}
