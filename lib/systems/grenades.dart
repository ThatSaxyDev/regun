import 'dart:math' as math;
import 'dart:ui';

/// Separate secondary ammunition. Only active simulation time advances this.
class GrenadeInventory {
  int capacity = 2, charges = 2;
  void setCapacity(int value) {
    final next = value.clamp(2, 4);
    charges = (charges + math.max(0, next - capacity)).clamp(0, next).toInt();
    capacity = next;
    if (charges == capacity) remaining = 0;
  }

  double remaining = 0, cooldown = 0, duration = 18;
  bool get ready => charges > 0 && cooldown <= 0;
  double get progress =>
      remaining <= 0 ? 1 : (1 - remaining / duration).clamp(0, 1);
  void reset() {
    charges = capacity;
    remaining = 0;
    cooldown = 0;
    duration = 18;
  }

  bool spend(double recharge) {
    if (!ready) return false;
    charges--;
    cooldown = .25;
    if (remaining <= 0) {
      duration = recharge;
      remaining = recharge;
    }
    return true;
  }

  void advance(double dt, double recharge) {
    if (!dt.isFinite || dt <= 0) return;
    cooldown = math.max(0, cooldown - dt);
    if (charges >= capacity) return;
    remaining -= dt;
    while (remaining <= 1e-9 && charges < capacity) {
      charges++;
      duration = recharge;
      remaining = charges < capacity ? remaining + recharge : 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'capacity': capacity,
    'charges': charges,
    'remaining': remaining,
    'cooldown': cooldown,
    'duration': duration,
  };
  void restore(Map<String, dynamic> data) {
    final cap = data['capacity'] ?? 2;
    final c = data['charges'],
        r = data['remaining'],
        d = data['duration'],
        t = data['cooldown'];
    if (cap is! int ||
        cap < 2 ||
        cap > 4 ||
        c is! int ||
        c < 0 ||
        c > cap ||
        [r, d, t].any((v) => v is! num || !v.isFinite) ||
        (r as num) < 0 ||
        r > 18 ||
        (d as num) < 10 ||
        d > 18 ||
        (t as num) < 0 ||
        t > .25 ||
        (c == cap && r != 0) ||
        (c < cap && r <= 0)) {
      throw const FormatException('Invalid grenade inventory');
    }
    capacity = cap;
    charges = c;
    remaining = r.toDouble();
    duration = d.toDouble();
    cooldown = t.toDouble();
  }
}

class GrenadeSpec {
  static const fuse = 1.4, arm = .18, speed = 600.0;
  static double damage(double rank) => 8 * (1 + rank * .2);
  static double radius(double rank) => 205 * (1 + rank * .08);
  static double recharge(double rank) => (18 - rank * 1.5).clamp(10, 18);
}

/// Fixed-step planar flight plus a small physical vertical bounce. Walls bounce
/// the casing; body contact after arming or the fuse requests one detonation.
class GrenadeFlight {
  GrenadeFlight(this.position, this.velocity);
  Offset position, velocity;
  double age = 0, height = 12, lift = 190, spin = 0;
  bool spent = false;
  void advance(
    double dt, {
    required bool Function(Offset, Offset) blocked,
    required bool Function(Offset, Offset) contact,
  }) {
    if (spent || !dt.isFinite || dt <= 0) return;
    var left = math.min(dt, GrenadeSpec.fuse - age);
    while (left > 1e-8 && !spent) {
      final step = math.min(left, 1 / 120);
      final previous = position;
      final next = previous + velocity * step;
      if (blocked(previous, next)) {
        final x = Offset(next.dx, previous.dy),
            y = Offset(previous.dx, next.dy);
        final bx = blocked(previous, x), by = blocked(previous, y);
        velocity = Offset(
          bx || !by ? -velocity.dx * .45 : velocity.dx,
          by || !bx ? -velocity.dy * .45 : velocity.dy,
        );
      } else {
        position = next;
      }
      age += step;
      height += lift * step;
      lift -= 420 * step;
      if (height < 0) {
        height = 0;
        lift = -lift * .24;
        if (lift < 15) lift = 0;
      }
      velocity *= math.exp(-(height > 0 ? 1.1 : 3.2) * step);
      spin += step * 5;
      if (age >= GrenadeSpec.arm && contact(previous, position)) spent = true;
      if (age + 1e-8 >= GrenadeSpec.fuse) spent = true;
      left -= step;
    }
  }

  Map<String, dynamic> toJson() => {
    'x': position.dx,
    'y': position.dy,
    'vx': velocity.dx,
    'vy': velocity.dy,
    'age': age,
    'height': height,
    'lift': lift,
    'spin': spin,
  };
  factory GrenadeFlight.restore(Map<String, dynamic> data) {
    for (final key in ['x', 'y', 'vx', 'vy', 'age', 'height', 'lift', 'spin']) {
      if (data[key] is! num || !(data[key] as num).isFinite) {
        throw const FormatException('Invalid grenade flight');
      }
    }
    double n(String k) => (data[k] as num).toDouble();
    if (n('x').abs() > 10000 ||
        n('y').abs() > 10000 ||
        n('vx').abs() > 600 ||
        n('vy').abs() > 600 ||
        n('age') < 0 ||
        n('age') >= GrenadeSpec.fuse ||
        n('height') < 0 ||
        n('height') > 100 ||
        n('lift').abs() > 500) {
      throw const FormatException('Invalid grenade flight bounds');
    }
    return GrenadeFlight(Offset(n('x'), n('y')), Offset(n('vx'), n('vy')))
      ..age = n('age')
      ..height = n('height')
      ..lift = n('lift')
      ..spin = n('spin');
  }
}

/// One independent thumb gesture. Returning a deliberate drag to center cancels.
class GrenadeAim {
  int? pointer;
  Offset origin = Offset.zero, delta = Offset.zero;
  bool dragged = false;
  bool get active => pointer != null;
  bool get cancelled => dragged && delta.distance < 8;
  bool begin(int id, Offset point) {
    if (active) return false;
    pointer = id;
    origin = point;
    delta = Offset.zero;
    dragged = false;
    return true;
  }

  void move(int id, Offset point) {
    if (pointer != id) return;
    delta = point - origin;
    if (delta.distance >= 8) dragged = true;
  }

  Offset? get direction => delta.distance < 8 ? null : delta / delta.distance;
  double power(double radius) => direction == null
      ? 1
      : (.4 + .6 * ((delta.distance - 8) / radius).clamp(0, 1));
  void cancel() {
    pointer = null;
    delta = Offset.zero;
    dragged = false;
  }
}

class GrenadePreviewPoint {
  const GrenadePreviewPoint(this.ground, this.height);
  final Offset ground;
  final double height;
}

List<GrenadePreviewPoint> grenadePreview(
  GrenadeFlight flight, {
  required bool Function(Offset, Offset) blocked,
  required bool Function(Offset, Offset) contact,
}) {
  final points = <GrenadePreviewPoint>[
    GrenadePreviewPoint(flight.position, flight.height),
  ];
  for (var i = 0; i < 168 && !flight.spent; i++) {
    flight.advance(1 / 120, blocked: blocked, contact: contact);
    if (i % 4 == 0 || flight.spent) {
      points.add(GrenadePreviewPoint(flight.position, flight.height));
    }
  }
  return points;
}

bool grenadeSegmentContact(Offset a, Offset b, Offset point, double radius) {
  final d = b - a;
  final t = d.distanceSquared < 1e-9
      ? 0.0
      : (((point.dx - a.dx) * d.dx + (point.dy - a.dy) * d.dy) /
                d.distanceSquared)
            .clamp(0, 1);
  return (point - (a + d * t.toDouble())).distance <= radius;
}
