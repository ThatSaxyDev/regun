import 'dart:math' as math;
import 'dart:ui';

/// Shared gunship flight and independent roof weapon sockets.
/// Coordinates use +X forward; height/bank never change ground sockets.
class ArietExhaustPuff {
  ArietExhaustPuff(this.position, this.velocity, this.frame, this.strength);
  Offset position;
  final Offset velocity;
  final int frame;
  final double strength;
  double age = 0;
  static const lifetime = .95;
  double get progress => (age / lifetime).clamp(0, 1);
}

class ArietRig {
  ArietRig({this.position = Offset.zero, this.resolveMove});
  static const tick = 1 / 120;
  static const cruiseSpeed = 360.0, passSpeed = 820.0;
  static const acceleration = 1300.0, braking = 1800.0, turnRate = 2.8;
  static const podLimit = .30, hoverHeight = 34.0;
  static const navigationRadius = 230.0;
  static const podMounts = [Offset(-8, -142), Offset(-8, 142)];
  static const cargoMounts = [Offset(-77, 0), Offset(77, 0)];
  static const noseMounts = [Offset(-5, -52), Offset(-5, 52)];
  static const cannonMount = Offset(85, 0);
  static const flakMount = Offset(-65, 0), launcherMount = Offset(-140, 0);
  static const rotaryHeight = 80.0, cannonHeight = 60.0, flakHeight = 44.0;
  static const rotaryLength = 58.0, cannonLength = 91.0, flakLength = 49.0;
  static double rotaryZ(int index) => rotaryHeight + index * 16;
  // Receivers occupy z +/-8; their central support shaft has radius4.
  // Barrels use conservative 6/8-unit radii and staggered trunnion heights.
  static List<
    ({Offset at, double z, double reach, double radius, double receiver})
  >
  get roofStations => [
    (
      at: noseMounts[0],
      z: rotaryZ(0),
      reach: rotaryLength,
      radius: 6,
      receiver: 21.5,
    ),
    (
      at: noseMounts[1],
      z: rotaryZ(1),
      reach: rotaryLength,
      radius: 6,
      receiver: 21.5,
    ),
    (
      at: cannonMount,
      z: cannonHeight,
      reach: cannonLength,
      radius: 8,
      receiver: 27.5,
    ),
    (
      at: flakMount,
      z: flakHeight,
      reach: flakLength,
      radius: 6,
      receiver: 23.5,
    ),
  ];
  bool barrelClear(int station, double worldYaw, {double recoil = 0}) {
    final stations = roofStations, own = stations[station];
    final end = own.at + rotate(Offset(own.reach - recoil, 0), worldYaw - yaw);
    double separation(Offset p) {
      final d = end - own.at;
      final t = d.distanceSquared == 0
          ? 0.0
          : (((p - own.at).dx * d.dx + (p - own.at).dy * d.dy) /
                    d.distanceSquared)
                .clamp(0.0, 1.0);
      return (p - own.at - d * t).distance;
    }

    for (var i = 0; i < stations.length; i++) {
      if (i == station) continue;
      final other = stations[i], distance = separation(other.at);
      if ((own.z - other.z).abs() <= own.radius + 8 &&
          distance < other.receiver + own.radius) {
        return false;
      }
      if (own.z - own.radius < other.z - 8 && distance < 4 + own.radius) {
        return false;
      }
    }
    return true;
  }

  final rotaryYaw = [0.0, 0.0];
  double flakYaw = 0;
  final Offset Function(Offset from, Offset to)? resolveMove;
  Offset position, velocity = Offset.zero, command = Offset.zero;
  Offset actualAcceleration = Offset.zero;
  double yaw = 0, desiredYaw = 0, bank = 0, pitch = 0;
  double hoverElevation = hoverHeight;
  bool hoverMotion = false;
  Offset hoverOffset = Offset.zero;
  double get hoverLift => hoverMotion && enginesRunning && !reducedMotion
      ? math.sin(elapsed * 1.9) * 5 + math.sin(elapsed * 3.17) * 2
      : 0;
  // Travel stays on the nozzle axis. Thermal flow animates without swinging it.
  double jetFlow(int index, int packet) =>
      (elapsed * (reducedMotion ? 1.4 : 4.5) +
          index * .23 +
          packet / (reducedMotion ? 2 : 4)) %
      1;
  double height = hoverHeight, elapsed = 0, _remainder = 0;
  double podAngle = 0, thrust = .18;
  double cannonYaw = math.pi / 2;
  bool paused = false, reducedMotion = false, trackCannon = true;
  double speedLimit = cruiseSpeed;
  double thrustBoost = 0;
  bool enginesRunning = true;
  final exhaustPuffs = <ArietExhaustPuff>[];
  double _exhaustClock = 0;
  int _exhaustSequence = 0;
  static const exhaustLimit = 18;
  Offset engineNozzle(int index) =>
      projectOnPod(index, const Offset(-114, 0), z: -12);
  Offset engineDirection(int index) {
    final delta =
        projectOnPod(index, const Offset(-145, 0), z: -12) -
        engineNozzle(index);
    return delta.distance < .01
        ? rotate(const Offset(-1, 0), yaw)
        : delta / delta.distance;
  }

  void _advanceExhaust() {
    if (reducedMotion) {
      exhaustPuffs.clear();
      _exhaustClock = 0;
      return;
    }
    for (final puff in exhaustPuffs) {
      puff.age += tick;
      puff.position += puff.velocity * tick;
    }
    exhaustPuffs.removeWhere((puff) => puff.age >= ArietExhaustPuff.lifetime);
    if (!enginesRunning) return;
    _exhaustClock += tick;
    if (_exhaustClock < .10) return;
    _exhaustClock -= .10;
    for (var i = 0; i < 2; i++) {
      if (exhaustPuffs.length >= exhaustLimit) break;
      final d = engineDirection(i), strength = .55 + thrust * .45;
      exhaustPuffs.add(
        ArietExhaustPuff(
          engineNozzle(i) + d * (80 + thrust * 55),
          d * (45 + thrust * 45) + const Offset(0, -8),
          2 + (_exhaustSequence++ % 2),
          strength,
        ),
      );
    }
  }

  static double difference(double to, double from) =>
      (to - from + math.pi) % (2 * math.pi) - math.pi;
  static double turn(double from, double to, double amount) =>
      from + difference(to, from).clamp(-amount, amount);
  static Offset rotate(Offset p, double angle) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  static Offset limit(Offset p, double maximum) =>
      p.distance > maximum ? p * (maximum / p.distance) : p;
  Offset ground(Offset local) => position + rotate(local, yaw);
  // Presentation projection is deliberately separate from authoritative sockets.
  Offset project(Offset local, {double z = 0}) {
    final tilt = reducedMotion
        ? local
        : Offset(local.dx * math.cos(pitch), local.dy * math.cos(bank));
    final lift = reducedMotion
        ? 0.0
        : local.dx * math.sin(pitch) + local.dy * math.sin(bank);
    return ground(tilt) + hoverOffset - Offset(0, (height + z + lift) * .7);
  }

  /// Same basis as the painted pitched pod; exhaust stays on its nozzle.
  Offset projectOnPod(int index, Offset local, {double z = 0}) {
    final p = reducedMotion ? 0.0 : podAngle + pitch;
    final b = reducedMotion ? 0.0 : bank;
    final x = Offset(
      math.cos(yaw) * math.cos(p),
      math.sin(yaw) * math.cos(p) - .7 * math.sin(p),
    );
    final y = Offset(
      -math.sin(yaw) * math.cos(b),
      math.cos(yaw) * math.cos(b) - .7 * math.sin(b),
    );
    return project(podMounts[index]) +
        x * local.dx +
        y * local.dy -
        Offset(0, z * .7);
  }

  Offset podSocket(int index) => ground(podMounts[index]);
  Offset cargoSocket(int index) => ground(cargoMounts[index]);

  /// Ground navigation and airborne combat/render coordinates are separate.
  /// Stable altitude is preserved in Reduced Motion; only bank/pitch is omitted.
  Offset get bodyPosition => air(Offset.zero);
  Offset air(Offset local, {double z = 0}) =>
      ground(local) + hoverOffset - Offset(0, (height + z) * .7);
  Offset cargoReleaseSocket(int index) => air(cargoMounts[index], z: -28);
  Offset roofSocket(Offset local, double z) => air(local, z: z);
  Offset noseSocket(int index) => roofSocket(noseMounts[index], rotaryZ(index));
  Offset get cannonSocket => roofSocket(cannonMount, cannonHeight);
  Offset get flakSocket => roofSocket(flakMount, flakHeight);
  Offset get launcherSocket => roofSocket(launcherMount, 24);

  /// Caller supplies intent at each fixed tick so render frequency never changes
  /// navigation decisions. Invalid/stalled frames do not fast-forward the study.
  void advance(double dt, {void Function(double time)? beforeStep}) {
    if (paused || !dt.isFinite || dt <= 0) return;
    _remainder += dt;
    while (_remainder + 1e-10 >= tick) {
      _remainder -= tick;
      beforeStep?.call(elapsed);
      _step();
    }
  }

  void _step() {
    elapsed += tick;
    yaw = turn(yaw, desiredYaw, turnRate * tick);
    final wanted = limit(command, speedLimit);
    final slowing =
        wanted.distance < velocity.distance ||
        wanted.dx * velocity.dx + wanted.dy * velocity.dy < 0;
    final change = limit(
      wanted - velocity,
      (slowing ? braking : acceleration) * tick,
    );
    // Pods lead the decision rather than following tiny player-position changes.
    final intent = rotate(change / tick, -yaw);
    final podTarget = (intent.dx / acceleration * podLimit).clamp(
      -podLimit,
      podLimit,
    );
    podAngle += (podTarget - podAngle).clamp(-1.0 * tick, 1.0 * tick);
    final previous = velocity;
    final proposed = position + (velocity + change) * tick;
    final next = resolveMove?.call(position, proposed) ?? proposed;
    velocity = (next - position) / tick;
    actualAcceleration = (velocity - previous) / tick;
    position = next;
    final local = rotate(velocity, -yaw);
    final wantBank = reducedMotion
        ? 0.0
        : (-local.dy / passSpeed * .13).clamp(-.13, .13);
    final wantPitch = reducedMotion
        ? 0.0
        : (-intent.dx / acceleration * .055).clamp(-.055, .055);
    bank += (wantBank - bank).clamp(-.32 * tick, .32 * tick);
    pitch += (wantPitch - pitch).clamp(-.24 * tick, .24 * tick);
    if (reducedMotion) {
      bank = 0;
      pitch = 0;
    }
    // Active station-keeping is presentation lift/sway, never navigation drift.
    // Floor warnings remain planted and Reduced Motion keeps a steady airframe.
    hoverOffset = hoverMotion && enginesRunning && !reducedMotion
        ? Offset(
            math.sin(elapsed * 1.37) * 3 + math.sin(elapsed * 2.23) * 1.5,
            0,
          )
        : Offset.zero;
    height = hoverElevation + hoverLift;
    final wantThrust =
        .18 +
        .65 * thrustBoost +
        .55 * velocity.distance / passSpeed +
        .2 * change.distance / (acceleration * tick);
    thrust += (wantThrust.clamp(.18, 1.0) - thrust).clamp(
      -1.5 * tick,
      1.5 * tick,
    );
    if (trackCannon) cannonYaw = turn(cannonYaw, yaw + math.pi / 2, 1.8 * tick);
    _advanceExhaust();
  }
}
