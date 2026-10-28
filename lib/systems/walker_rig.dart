import 'dart:math' as math;
import 'dart:ui';

/// Workshop-only rig. Ground motion can be supplied by the game's occupancy
/// resolver later; no combat/roster/checkpoint behavior is installed here.
class WalkerPoint {
  const WalkerPoint(this.x, this.y, this.z);
  final double x, y, z;
  WalkerPoint operator +(WalkerPoint b) =>
      WalkerPoint(x + b.x, y + b.y, z + b.z);
  WalkerPoint operator -(WalkerPoint b) =>
      WalkerPoint(x - b.x, y - b.y, z - b.z);
  WalkerPoint operator *(double k) => WalkerPoint(x * k, y * k, z * k);
  double dot(WalkerPoint b) => x * b.x + y * b.y + z * b.z;
  double get length => math.sqrt(dot(this));
  WalkerPoint get unit =>
      length < .000001 ? const WalkerPoint(0, 0, 1) : this * (1 / length);
  Offset get ground => Offset(x, y);
  Offset get projected => Offset(x, y - z * .7);
}

class WalkerLeg {
  WalkerLeg(this.index, this.mount, this.rest, Offset root)
    : foot = root + rest,
      from = root + rest,
      destination = root + rest,
      footYaw = math.atan2(rest.dy, rest.dx);
  final int index;
  final Offset mount, rest;
  Offset foot, from, destination;
  double swing = -1, lift = 0, footYaw;
  double fromYaw = 0, destinationYaw = 0, plantedFor = 1;
  int steps = 0;
  bool get planted => swing < 0;
}

class WalkerLegPose {
  const WalkerLegPose(this.hip, this.knee, this.ankle);
  final WalkerPoint hip, knee, ankle;
}

typedef WalkerMoveResolver = Offset Function(Offset current, Offset proposed);

class WalkerRig {
  WalkerRig({
    this.position = Offset.zero,
    this.moveResolver,
    this.maxSpeed = 120,
    this.acceleration = 240,
    this.turnSpeed = .95,
    this.agileGait = false,
    this.barrelLength = 104,
    this.bodyBounds = const Rect.fromLTRB(-480, -100, 480, 100),
    this.footBounds = floor,
    this.footResolver,
  }) {
    legs = [
      for (final x in [-1.0, 1.0])
        for (final y in [-1.0, 1.0])
          WalkerLeg(
            (x > 0 ? 2 : 0) + (y > 0 ? 1 : 0),
            Offset(x * 54, y * 36),
            Offset(x * 156, y * 116),
            position,
          ),
    ];
  }
  static const upperLength = 110.0, lowerLength = 130.0;
  static const tick = 1 / 120, stepDuration = .22;
  static const floor = Rect.fromLTRB(-730, -320, 730, 320);
  final WalkerMoveResolver? moveResolver;
  final WalkerMoveResolver? footResolver;
  final double maxSpeed, barrelLength, acceleration, turnSpeed;
  final bool agileGait;
  final Rect bodyBounds, footBounds;
  late final List<WalkerLeg> legs;
  Offset position, velocity = Offset.zero, command = Offset.zero;
  Offset target = const Offset(330, 80);
  double yaw = 0, desiredYaw = 0, turretYaw = 0, turretPitch = 0;
  double height = 88, elapsed = 0, _accumulator = 0;
  bool braced = false, paused = false, reducedMotion = false;
  bool folded = false, trackTurret = true;
  int get swingingFeet => legs.where((l) => !l.planted).length;

  static double difference(double a, double b) =>
      (a - b + math.pi) % (math.pi * 2) - math.pi;
  static double turn(double from, double to, double amount) =>
      from + difference(to, from).clamp(-amount, amount);
  static Offset rotate(Offset p, double angle) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  static Offset limit(Offset p, double maximum) =>
      p.distance > maximum ? p * (maximum / p.distance) : p;
  Offset ground(Offset local) => position + rotate(local, yaw);
  WalkerPoint point(Offset local, double z) {
    final p = ground(local);
    return WalkerPoint(p.dx, p.dy, z);
  }

  WalkerPoint get turretPivot => point(const Offset(-12, -43), height + 18);
  WalkerPoint get muzzle {
    final c = math.cos(turretPitch);
    return turretPivot +
        WalkerPoint(
              math.cos(turretYaw) * c,
              math.sin(turretYaw) * c,
              math.sin(turretPitch),
            ) *
            barrelLength;
  }

  /// Thruster travel deliberately carries retracted feet; walking never uses
  /// this path to conceal sliding planted supports.
  void carryTo(Offset next) {
    final delta = next - position;
    position = next;
    velocity = Offset.zero;
    for (final leg in legs) {
      leg.foot += delta;
      leg.from += delta;
      leg.destination += delta;
    }
  }

  void advance(double dt) {
    if (paused || !dt.isFinite || dt <= 0) return;
    _accumulator += dt;
    while (_accumulator + 1e-10 >= tick) {
      _accumulator -= tick;
      _step();
    }
  }

  void _step() {
    elapsed += tick;
    height += ((braced ? 42 : 88) - height).clamp(-65 * tick, 65 * tick);
    final nextYaw = turn(yaw, desiredYaw, turnSpeed * tick);
    // A supporting foot owns its ground position. Turn only as far as the
    // stance permits; the swing planner rotates the next foothold ahead.
    if (folded || _supports(position, nextYaw)) yaw = nextYaw;
    final want = braced || folded ? Offset.zero : limit(command, maxSpeed);
    final change = limit(want - velocity, acceleration * tick);
    velocity += change;
    var proposed = position + velocity * tick;
    proposed = Offset(
      proposed.dx.clamp(bodyBounds.left, bodyBounds.right),
      proposed.dy.clamp(bodyBounds.top, bodyBounds.bottom),
    );
    proposed = moveResolver?.call(position, proposed) ?? proposed;
    // A planted foot never slides to conceal an unreachable body displacement.
    if (!folded && !_supports(proposed, yaw)) proposed = position;
    velocity = (proposed - position) / tick;
    position = proposed;

    for (final leg in legs) {
      if (leg.planted) {
        leg.plantedFor += tick;
        continue;
      }
      leg.swing += tick / (agileGait ? .24 : stepDuration);
      final t = leg.swing.clamp(0.0, 1.0);
      final eased = t * t * t * (t * (t * 6 - 15) + 10);
      leg.foot = Offset.lerp(leg.from, leg.destination, eased)!;
      leg.footYaw =
          leg.fromYaw + difference(leg.destinationYaw, leg.fromYaw) * eased;
      final arc = math.sin(math.pi * t);
      leg.lift =
          arc *
          arc *
          (reducedMotion
              ? 5
              : agileGait
              ? 26
              : 18);
      if (t >= 1) {
        leg.foot = leg.destination;
        leg.lift = 0;
        leg.swing = -1;
        leg.plantedFor = 0;
        leg.steps++;
      }
    }
    if (!folded && swingingFeet == 0) {
      WalkerLeg? candidate;
      var error = agileGait ? 50.0 : 40.0;
      for (final leg in legs) {
        if (agileGait &&
            (leg.plantedFor < .10 || legs[3 - leg.index].plantedFor < .10)) {
          continue;
        }
        final d = (_foothold(leg) - leg.foot).distance;
        if (d > error) {
          error = d;
          candidate = leg;
        }
      }
      if (candidate != null) {
        _beginStep(candidate);
        // One deliberate diagonal support change, not two independent feet
        // chasing their error thresholds a few frames apart.
        if (agileGait) _beginStep(legs[3 - candidate.index]);
      }
    }
    final delta = target - turretPivot.ground;
    if (trackTurret && delta.distance > 1) {
      turretYaw = turn(turretYaw, math.atan2(delta.dy, delta.dx), 2.2 * tick);
      final desiredPitch = math
          .atan2(-turretPivot.z, delta.distance)
          .clamp(-.6, .05);
      turretPitch += (desiredPitch - turretPitch).clamp(-.8 * tick, .8 * tick);
    }
  }

  void _beginStep(WalkerLeg leg) {
    final next = _foothold(leg);
    final bounded = Offset(
      next.dx.clamp(footBounds.left + 20, footBounds.right - 20),
      next.dy.clamp(footBounds.top + 20, footBounds.bottom - 20),
    );
    final destination =
        footResolver?.call(ground(leg.mount), bounded) ?? bounded;
    // A clipped/settled foot must not lift for a negligible correction.
    if ((destination - leg.foot).distance < 24) return;
    leg.from = leg.foot;
    leg.destination = destination;
    leg.fromYaw = leg.footYaw;
    leg.destinationYaw =
        turn(yaw, desiredYaw, .3) + math.atan2(leg.rest.dy, leg.rest.dx);
    leg.swing = 0;
  }

  bool _supports(Offset root, double angle) {
    for (final leg in legs) {
      final local = rotate(leg.foot - root, -angle);
      // Keep each foot in its own chassis quadrant, not underneath a neighbour.
      if (local.dx * leg.rest.dx.sign < 48 ||
          local.dy * leg.rest.dy.sign < 42) {
        return false;
      }
      final hip = root + rotate(leg.mount, angle);
      final reach = math.sqrt(
        (hip - leg.foot).distanceSquared + height * height,
      );
      if (leg.planted && reach > upperLength + lowerLength - 15) return false;
    }
    return true;
  }

  Offset _foothold(WalkerLeg leg) {
    final stepYaw = turn(yaw, desiredYaw, .3);
    final lead = rotate(velocity * .25, -stepYaw);
    // A long sideways stride must not put a foot across the body centreline.
    final local = Offset(leg.rest.dx + lead.dx, leg.rest.dy + lead.dy);
    final safe = Offset(
      leg.rest.dx.sign * math.max(90, local.dx * leg.rest.dx.sign),
      leg.rest.dy.sign * math.max(75, local.dy * leg.rest.dy.sign),
    );
    return position + rotate(safe, stepYaw);
  }

  Map<String, dynamic> toJson() => {
    'position': [position.dx, position.dy],
    'velocity': [velocity.dx, velocity.dy],
    'command': [command.dx, command.dy],
    'target': [target.dx, target.dy],
    'yaw': yaw,
    'desiredYaw': desiredYaw,
    'turretYaw': turretYaw,
    'turretPitch': turretPitch,
    'height': height,
    'elapsed': elapsed,
    'accumulator': _accumulator,
    'braced': braced,
    'folded': folded,
    'legs': [
      for (final l in legs)
        {
          'foot': [l.foot.dx, l.foot.dy],
          'from': [l.from.dx, l.from.dy],
          'destination': [l.destination.dx, l.destination.dy],
          'swing': l.swing,
          'lift': l.lift,
          'footYaw': l.footYaw,
          'fromYaw': l.fromYaw,
          'destinationYaw': l.destinationYaw,
          'plantedFor': l.plantedFor,
          'steps': l.steps,
        },
    ],
  };

  void restore(Map<String, dynamic> data) {
    double n(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 1e9) {
        throw const FormatException('Invalid Walker rig');
      }
      return value.toDouble();
    }

    Offset point(dynamic value) {
      final p = value as List;
      if (p.length != 2) throw const FormatException('Invalid Walker point');
      return Offset(n(p[0]), n(p[1]));
    }

    position = point(data['position']);
    velocity = point(data['velocity']);
    command = point(data['command']);
    target = point(data['target']);
    yaw = n(data['yaw']);
    desiredYaw = n(data['desiredYaw']);
    turretYaw = n(data['turretYaw']);
    turretPitch = n(data['turretPitch']);
    height = n(data['height']);
    elapsed = n(data['elapsed']);
    _accumulator = n(data['accumulator']);
    braced = data['braced'] == true;
    folded = data['folded'] == true;
    final saved = data['legs'] as List;
    if (saved.length != 4) throw const FormatException('Invalid Walker stance');
    for (var i = 0; i < 4; i++) {
      final v = saved[i] as Map, l = legs[i];
      l.foot = point(v['foot']);
      l.from = point(v['from']);
      l.destination = point(v['destination']);
      l.swing = n(v['swing']);
      l.lift = n(v['lift']);
      l.footYaw = n(v['footYaw']);
      l.fromYaw = n(v['fromYaw']);
      l.destinationYaw = n(v['destinationYaw']);
      l.plantedFor = n(v['plantedFor']);
      l.steps = n(v['steps']).toInt();
      if (l.swing < -1 ||
          l.swing > 1 ||
          l.lift < 0 ||
          l.lift > 40 ||
          l.plantedFor < 0) {
        throw const FormatException('Invalid Walker leg');
      }
    }
  }

  WalkerLegPose pose(WalkerLeg leg) {
    final hip = point(leg.mount, height);
    final carried = folded ? ground(leg.rest * .72) : leg.foot;
    final ankle = WalkerPoint(carried.dx, carried.dy, folded ? 24 : leg.lift);
    final chord = ankle - hip;
    final distance = chord.length.clamp(.001, upperLength + lowerLength - .001);
    final direction = chord.unit;
    // Use a stable up-vector knee pole. A body-relative outward pole becomes
    // almost parallel to the leg chord during turns and flips the knee plane.
    const pole = WalkerPoint(0, 0, 1);
    var bend = pole - direction * pole.dot(direction);
    if (bend.length < .001) {
      final outward = rotate(leg.rest, yaw);
      bend = WalkerPoint(outward.dx, outward.dy, 0);
    }
    final along =
        (upperLength * upperLength -
            lowerLength * lowerLength +
            distance * distance) /
        (2 * distance);
    final perpendicular = math.sqrt(
      math.max(0.0, upperLength * upperLength - along * along),
    );
    final knee = hip + direction * along + bend.unit * perpendicular;
    return WalkerLegPose(hip, knee, ankle);
  }
}
