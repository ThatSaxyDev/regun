import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/target_shape.dart';

class LodestarPose {
  const LodestarPose(this.section, this.position, this.yaw);
  final LodestarSection section;
  final Offset position;
  final double yaw;
  Offset socket(Offset local) => position + LodestarRig.rotate(local, yaw);
  Offset get front => socket(const Offset(40.5, 0));
  Offset get rear => socket(const Offset(-40.5, 0));
  TargetCapsule footprint({bool broken = false}) => TargetCapsule(
    socket(broken ? const Offset(-42, 0) : const Offset(0, -12)),
    socket(broken ? const Offset(42, 0) : const Offset(0, 12)),
    broken ? 11 : 42,
  );
}

class LodestarCoupling {
  const LodestarCoupling(this.a, this.b);
  final Offset a, b;
  double get length => (b - a).distance;
  double get yaw => math.atan2((b - a).dy, (b - a).dx);
  TargetCapsule get footprint => TargetCapsule(a, b, 8);
}

/// Arc-length history owns the anatomy. No render-time positional oscillation.
/// Movement commits atomically only after the complete body's sweep is accepted.
class LodestarRig {
  LodestarRig({
    Offset head = Offset.zero,
    double heading = 0,
    this.acceptPose,
  }) {
    for (var s = -historyLength; s <= 0; s += 2) {
      _path.add((s: s, at: head + rotate(Offset(s, 0), heading)));
    }
    _yaw = heading;
    desiredHeading = heading;
    _poses = _solve(_path, 0, heading);
  }
  static const tick = 1 / 120;
  static const spacing = 104.0;
  static const turnRadius = 220.0;
  static const jointLimit = 28 * math.pi / 180;
  static const couplingReach = 32.0;
  static const historyLength = 2600.0;
  static const speedLimit = 260.0, acceleration = 900.0;
  double maximumSpeed = speedLimit, tailCurl = 0;
  double _curlValue = 0;
  final bool Function(List<LodestarPose> from, List<LodestarPose> to)?
  acceptPose;
  final _path = <({double s, Offset at})>[];
  late List<LodestarPose> _poses;
  List<LodestarPose> get poses => List.unmodifiable(_poses);
  double _cursor = 0, _yaw = 0, _remainder = 0, _speed = 0;
  double elapsed = 0, signedTravel = 0, rollerTravel = 0;
  double desiredHeading = 0, requestedSpeed = 0;
  bool paused = false;
  int rejectedSteps = 0;
  Offset velocity = Offset.zero;
  double get speed => velocity.distance;
  int get historySamples => _path.length;
  List<LodestarCoupling> get couplings => [
    for (var i = 0; i < 5; i++)
      LodestarCoupling(_poses[i + 1].front, _poses[i].rear),
  ];
  static Offset rotate(Offset p, double yaw) => Offset(
    p.dx * math.cos(yaw) - p.dy * math.sin(yaw),
    p.dx * math.sin(yaw) + p.dy * math.cos(yaw),
  );
  static double difference(double a, double b) =>
      (a - b + math.pi) % (2 * math.pi) - math.pi;

  Map<String, dynamic> checkpoint({bool history = true}) => {
    'poses': [
      for (final p in _poses) [p.position.dx, p.position.dy, p.yaw],
    ],
    if (history)
      'path': [
        for (final p in _path) [p.s, p.at.dx, p.at.dy],
      ],
    'cursor': _cursor,
    'yaw': _yaw,
    'speed': _speed,
    'curl': _curlValue,
    'travel': signedTravel,
    'roller': rollerTravel,
    'elapsed': elapsed,
    'desired': desiredHeading,
    'requested': requestedSpeed,
  };
  void restore(Map data) {
    final poses = data['poses'] as List;
    _poses = [
      for (var i = 0; i < 6; i++)
        LodestarPose(
          LodestarSection.values[i],
          Offset(
            (poses[i][0] as num).toDouble(),
            (poses[i][1] as num).toDouble(),
          ),
          (poses[i][2] as num).toDouble(),
        ),
    ];
    if (data['path'] case final List path) {
      _path
        ..clear()
        ..addAll([
          for (final p in path)
            (
              s: (p[0] as num).toDouble(),
              at: Offset((p[1] as num).toDouble(), (p[2] as num).toDouble()),
            ),
        ]);
    }
    double n(String key) => (data[key] as num?)?.toDouble() ?? 0;
    _cursor = n('cursor');
    _yaw = n('yaw');
    _speed = n('speed');
    _curlValue = n('curl');
    signedTravel = n('travel');
    rollerTravel = n('roller');
    elapsed = n('elapsed');
    desiredHeading = n('desired');
    requestedSpeed = n('requested');
  }

  static Offset _sample(List<({double s, Offset at})> path, double s) {
    var lo = 0, hi = path.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) ~/ 2;
      if (path[mid].s <= s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = path[lo], b = path[hi];
    return Offset.lerp(a.at, b.at, ((s - a.s) / (b.s - a.s)).clamp(0, 1))!;
  }

  static List<LodestarPose> _solve(
    List<({double s, Offset at})> path,
    double cursor,
    double headYaw,
  ) => [
    for (final s in LodestarSection.values)
      LodestarPose(
        s,
        _sample(path, cursor - s.index * spacing),
        s.index == 0
            ? headYaw
            : () {
                final at = cursor - s.index * spacing;
                final axis = _sample(path, at + 3) - _sample(path, at - 3);
                return math.atan2(axis.dy, axis.dx);
              }(),
      ),
  ];

  LodestarRig copy({bool validate = true}) {
    final r = LodestarRig(acceptPose: validate ? acceptPose : null);
    r._path
      ..clear()
      ..addAll(_path);
    r._poses = [..._poses];
    r._cursor = _cursor;
    r._yaw = _yaw;
    r._speed = _speed;
    r._remainder = _remainder;
    r.elapsed = elapsed;
    r.signedTravel = signedTravel;
    r.rollerTravel = rollerTravel;
    r.desiredHeading = desiredHeading;
    r.requestedSpeed = requestedSpeed;
    r.maximumSpeed = maximumSpeed;
    r.tailCurl = tailCurl;
    r._curlValue = _curlValue;
    return r;
  }

  List<LodestarPose> _curl(List<LodestarPose> poses) {
    if (_curlValue.abs() < 1e-9) return poses;
    final result = [...poses];
    for (var i = 4; i < 6; i++) {
      final parent = result[i - 1];
      final base = difference(poses[i].yaw, parent.yaw);
      final yaw =
          parent.yaw +
          (base + _curlValue.clamp(-.30, .30)).clamp(-jointLimit, jointLimit);
      final jointYaw = parent.yaw + difference(yaw, parent.yaw) / 2;
      final front = parent.rear - rotate(const Offset(23, 0), jointYaw);
      result[i] = LodestarPose(
        poses[i].section,
        front - rotate(const Offset(40.5, 0), yaw),
        yaw,
      );
    }
    return result;
  }

  static bool connected(List<LodestarPose> poses) {
    if (poses.length != 6) return false;
    for (var i = 0; i < 5; i++) {
      if (difference(poses[i].yaw, poses[i + 1].yaw).abs() >
              jointLimit + 1e-6 ||
          (poses[i].rear - poses[i + 1].front).distance > couplingReach) {
        return false;
      }
    }
    // Non-neighbours cannot close through the body. Coupling spines are checked
    // too; empty bends remain empty instead of becoming a giant enclosing disk.
    final bodies = [for (final p in poses) p.footprint()];
    for (var i = 0; i < bodies.length; i++) {
      for (var j = i + 2; j < bodies.length; j++) {
        if (overlap(bodies[i], bodies[j])) return false;
      }
    }
    for (var i = 0; i < 5; i++) {
      final link = TargetCapsule(poses[i].rear, poses[i + 1].front, 8);
      for (var j = 0; j < 6; j++) {
        if (j != i && j != i + 1 && overlap(link, bodies[j])) return false;
      }
    }
    return true;
  }

  static bool overlap(TargetCapsule a, TargetCapsule b) =>
      a.contact(b.a, b.b, padding: b.radius) != null;

  void advance(double dt, {void Function(double time)? beforeStep}) {
    if (paused || !dt.isFinite || dt <= 0) return;
    // Do not fast-forward a suspended app. Caller must also gate lifecycle.
    _remainder += math.min(dt, .25);
    while (_remainder + 1e-10 >= tick) {
      _remainder -= tick;
      beforeStep?.call(elapsed);
      _step();
    }
  }

  void _step() {
    elapsed += tick;
    if (!requestedSpeed.isFinite || !desiredHeading.isFinite) {
      velocity = Offset.zero;
      _speed = 0;
      return;
    }
    final target = requestedSpeed.clamp(-maximumSpeed, maximumSpeed);
    _speed += (target - _speed).clamp(
      -acceleration * tick,
      acceleration * tick,
    );
    final travel = _speed * tick;
    velocity = Offset.zero;
    if (travel.abs() < 1e-9) return;
    var nextCursor = _cursor + travel, nextYaw = _yaw;
    // Temporary append is rolled back on rejection; history never records an
    // illegal head path for followers to inherit later.
    final oldLength = _path.length;
    final abandoned = travel > 0 && _cursor < _path.last.s - 1e-8
        ? [..._path]
        : null;
    if (travel < 0) {
      if (nextCursor - 5 * spacing - 4 < _path.first.s) {
        _speed = 0;
        return;
      }
      final d = _sample(_path, nextCursor) - _sample(_path, nextCursor - 3);
      nextYaw = math.atan2(d.dy, d.dx);
    } else {
      // Reverse retraces accepted ground. A new forward turn branches from the
      // current head while retaining the whole follower path behind it.
      if (abandoned != null) {
        _path.removeWhere((point) => point.s > _cursor);
        if (_path.last.s < _cursor - 1e-8) {
          _path.add((s: _cursor, at: _poses.first.position));
        }
      }
      final turn = difference(
        desiredHeading,
        _yaw,
      ).clamp(-travel / turnRadius, travel / turnRadius);
      nextYaw += turn;
      _path.add((
        s: nextCursor,
        at: _poses.first.position + rotate(Offset(travel, 0), _yaw + turn / 2),
      ));
    }

    final previousCurl = _curlValue;
    _curlValue += (tailCurl - _curlValue).clamp(-1.8 * tick, 1.8 * tick);
    final next = _curl(_solve(_path, nextCursor, nextYaw));
    if (!connected(next) || !(acceptPose?.call(_poses, next) ?? true)) {
      if (abandoned != null) {
        _path
          ..clear()
          ..addAll(abandoned);
      } else {
        _path.length = oldLength;
      }
      _curlValue = previousCurl;
      _speed = 0;
      rejectedSteps++;
      return;
    }
    velocity = (next.first.position - _poses.first.position) / tick;
    _cursor = nextCursor;
    _yaw = nextYaw;
    signedTravel += travel;
    rollerTravel += travel;
    _poses = next;
    while (_path.length > 2 && _path[1].s < _cursor - historyLength) {
      _path.removeAt(0);
    }
  }
}

/// Workshop narrow-phase adapter. Production CrowdOccupancy admission is later:
/// no invisible enclosing circle or registration as six independent enemies.
class LodestarSpace {
  LodestarSpace({
    required this.bounds,
    this.solids = const [],
    this.bodies = const [],
    this.broken,
  });
  final Rect bounds;
  final List<TargetCapsule> solids, bodies;
  final bool Function(LodestarSection)? broken;
  bool accepts(List<LodestarPose> from, List<LodestarPose> to) {
    if (from.length != 6 || to.length != 6) return false;
    // Conservative substeps bound translation + rotation of every outer point
    // to <=1 unit. Half-unit inflation closes gaps between sweep samples.
    var distance = 0.0;
    for (var i = 0; i < 6; i++) {
      distance = math.max(
        distance,
        (to[i].position - from[i].position).distance +
            LodestarRig.difference(to[i].yaw, from[i].yaw).abs() * 54,
      );
    }
    final steps = math.max(1, (distance / 1).ceil());
    if (steps > 128) return false;
    for (var n = 0; n <= steps; n++) {
      final t = n / steps;
      final pose = [
        for (var i = 0; i < 6; i++)
          LodestarPose(
            to[i].section,
            Offset.lerp(from[i].position, to[i].position, t)!,
            from[i].yaw + LodestarRig.difference(to[i].yaw, from[i].yaw) * t,
          ),
      ];
      final shapes = [
        for (final p in pose)
          p.footprint(broken: broken?.call(p.section) ?? false),
        for (var i = 0; i < 5; i++)
          TargetCapsule(pose[i].rear, pose[i + 1].front, 8),
      ];
      for (final shape in shapes) {
        final r = shape.radius + .5;
        final legal = bounds.deflate(r);
        if (!legal.contains(shape.a) || !legal.contains(shape.b)) return false;
        for (final other in [...solids, ...bodies]) {
          if (shape.contact(other.a, other.b, padding: other.radius + .5) !=
              null) {
            return false;
          }
        }
      }
    }
    return true;
  }
}
