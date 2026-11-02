import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/systems/target_shape.dart';

/// Pure active-time policy mirrored in server/minion_navigation.ts. Rendering,
/// attack clocks, damage and final occupancy remain owned by their adapters.
class NavigationMotion {
  const NavigationMotion(this.end, this.delay, this.duration);
  final Offset end;
  final double delay, duration;
}

abstract interface class NavigationMotionSource {
  NavigationMotion? get navigationMotion;
}

class NavigationBody {
  const NavigationBody({
    required this.id,
    required this.position,
    required this.radius,
    this.velocity = Offset.zero,
    this.boss = false,
    this.shapes = const [],
    this.contact = false,
    this.motion,
  });
  final int id;
  final Offset position, velocity;
  final double radius;
  final bool boss, contact;
  final NavigationMotion? motion;
  Offset at(double t) {
    final m = motion;
    return m == null
        ? position + velocity * t
        : Offset.lerp(
            position,
            m.end,
            ((t - m.delay) / math.max(.001, m.duration)).clamp(0.0, 1.0),
          )!;
  }

  final List<TargetCapsule> shapes;
}

class NavigationMemory {
  Offset anchor = Offset.zero, velocity = Offset.zero, requested = Offset.zero;
  double progressAge = 0, remaining = 0, decisionAge = 0, waiting = 0;
  double side = 1;
  int blocker = -1;
  String mode = 'pursuit';
  Offset? approach, approachTarget;
  bool initialized = false;
  int pressure = -1;
  Map<String, dynamic> toJson() => {
    'v': 1,
    'side': side,
    'blocker': blocker,
    'remaining': remaining,
    'waiting': waiting,
    if (approach != null) 'goal': [approach!.dx, approach!.dy],
    'pressure': pressure,
  };
  static NavigationMemory? read(dynamic raw) {
    if (raw is! Map || raw['v'] != 1) return null;
    final side = raw['side'],
        hold = raw['remaining'],
        wait = raw['waiting'],
        blocker = raw['blocker'];
    if (side is! num ||
        (side != -1 && side != 1) ||
        hold is! num ||
        !hold.isFinite ||
        hold < 0 ||
        hold > 2 ||
        wait is! num ||
        !wait.isFinite ||
        wait < 0 ||
        wait > 4 ||
        blocker is! int ||
        blocker < -1 ||
        blocker > 0x7fffffff) {
      return null;
    }
    Offset? goal;
    final saved = raw['goal'];
    if (saved != null) {
      if (saved is! List ||
          saved.length != 2 ||
          saved.any((v) => v is! num || !v.isFinite || v.abs() > 10000)) {
        return null;
      }
      goal = Offset((saved[0] as num).toDouble(), (saved[1] as num).toDouble());
    }
    final pressure = raw['pressure'] ?? -1;
    if (pressure is! int || pressure < -1 || pressure > 0x7fffffff) return null;
    return NavigationMemory()
      ..approach = goal
      ..pressure = pressure
      ..side = side.toDouble()
      ..remaining = hold.toDouble()
      ..waiting = wait.toDouble()
      ..blocker = blocker;
  }
}

class MinionNavigation {
  static const horizon = .6, cellSize = 160.0;
  final memories = <int, NavigationMemory>{};
  final _cells = <(int, int), List<NavigationBody>>{};
  final _bodies = <int, NavigationBody>{};
  final _bosses = <NavigationBody>[];
  int checks = 0, candidates = 0;
  double _maxRadius = 0, _maxSpeed = 0;
  static int hash(int id) => ((id * 1103515245 + 12345) & 0x7fffffff);
  static double sideFor(int id) => hash(id) % 2 == 0 ? 1 : -1;
  static Offset unit(Offset p) =>
      p.distance < 1e-8 ? Offset.zero : p / p.distance;
  static Offset rotate(Offset p, double a) => Offset(
    p.dx * math.cos(a) - p.dy * math.sin(a),
    p.dx * math.sin(a) + p.dy * math.cos(a),
  );
  void clear() {
    memories.clear();
    _bodies.clear();
    _cells.clear();
    _bosses.clear();
  }

  void forget(int id) {
    memories.remove(id);
  }

  void rebuild(Iterable<NavigationBody> bodies) {
    _bodies.clear();
    _cells.clear();
    _bosses.clear();
    checks = candidates = 0;
    _maxRadius = _maxSpeed = 0;
    for (final b in bodies) {
      _bodies[b.id] = b;
      if (b.boss) {
        _bosses.add(b);
        continue;
      }
      _maxRadius = math.max(_maxRadius, b.radius);
      _maxSpeed = math.max(_maxSpeed, b.velocity.distance);
      final key = (
        (b.position.dx / cellSize).floor(),
        (b.position.dy / cellSize).floor(),
      );
      _cells.putIfAbsent(key, () => []).add(b);
    }
    for (final cell in _cells.values) {
      cell.sort((a, b) => a.id.compareTo(b.id));
    }
    _bosses.sort((a, b) => a.id.compareTo(b.id));
    memories.removeWhere((id, _) => !_bodies.containsKey(id));
  }

  List<NavigationBody> near(NavigationBody actor, double speed) {
    final reach =
        actor.radius + _maxRadius + (speed + _maxSpeed) * horizon + 90;
    final p = actor.position;
    final found = <NavigationBody>[];
    for (
      var x = ((p.dx - reach) / cellSize).floor();
      x <= ((p.dx + reach) / cellSize).floor();
      x++
    ) {
      for (
        var y = ((p.dy - reach) / cellSize).floor();
        y <= ((p.dy + reach) / cellSize).floor();
        y++
      ) {
        for (final b in _cells[(x, y)] ?? const <NavigationBody>[]) {
          if (b.id != actor.id && (b.position - p).distance <= reach) {
            found.add(b);
          }
        }
      }
    }
    found.addAll(_bosses.where((b) => b.id != actor.id));
    found.sort((a, b) => a.id.compareTo(b.id));
    return found;
  }

  static double closestDistance(
    Offset at,
    Offset velocity,
    NavigationBody b,
    double horizon,
  ) {
    final motion = b.motion;
    if (motion == null) {
      final rel = at - b.position, v = velocity - b.velocity;
      final t = v.distanceSquared < 1e-8
          ? 0.0
          : (-(rel.dx * v.dx + rel.dy * v.dy) / v.distanceSquared).clamp(
              0.0,
              horizon,
            );
      return (rel + v * t).distance;
    }
    final times = [
      0.0,
      motion.delay.clamp(0.0, horizon),
      (motion.delay + motion.duration).clamp(0.0, horizon),
      horizon,
    ]..sort();
    var minimum = double.infinity;
    for (var i = 1; i < times.length; i++) {
      final from = at + velocity * times[i - 1] - b.at(times[i - 1]);
      final to = at + velocity * times[i] - b.at(times[i]);
      minimum = math.min(
        minimum,
        TargetCapsule.distanceToSegment(Offset.zero, from, to),
      );
    }
    return minimum;
  }

  /// Describe once from an immutable frame; final movement must still sweep
  /// against live occupancy. No random consumption or render-order dependencies.
  Offset steer(
    int id,
    Offset at,
    Offset desired,
    double speed,
    double dt, {
    bool Function(Offset from, Offset to, double radius)? clear,
    Offset? target,
  }) {
    if (speed <= 0 || dt <= 0 || desired.distance < 1e-8) return desired * 0;
    final actor = _bodies[id];
    if (actor == null) return desired;
    final memory = memories.putIfAbsent(
      id,
      () => NavigationMemory()
        ..anchor = at
        ..side = sideFor(id),
    );
    if (!memory.initialized) {
      memory.anchor = at;
      memory.initialized = true;
    }
    final step = dt.clamp(0.0, .1);
    memory.remaining = math.max(0, memory.remaining - step);
    memory.decisionAge -= step;
    memory.progressAge += step;
    final neighbors = near(actor, speed);
    final forward = unit(desired);
    // Measure useful progress rather than resetting on lateral collision shuffle.
    if (memory.progressAge >= .6) {
      final travel = at - memory.anchor;
      memory.waiting =
          travel.dx * forward.dx + travel.dy * forward.dy < speed * .6 * .22
          ? math.min(4, memory.waiting + .6)
          : math.max(0, memory.waiting - .6);
      memory.anchor = at;
      memory.progressAge = 0;
    }
    var preferred = desired;
    NavigationBody? obstruction;
    var closest = double.infinity;
    for (final b in neighbors) {
      final relative = b.position - at;
      final ahead = relative.dx * forward.dx + relative.dy * forward.dy;
      final lateral = (relative.dx * forward.dy - relative.dy * forward.dx)
          .abs();
      final gap = actor.radius + b.radius + 4;
      if (b.shapes.isEmpty &&
          ahead > 0 &&
          ahead < gap + speed * .9 &&
          lateral < gap + 12 &&
          ahead < closest &&
          (b.boss ||
              b.velocity.distance < speed * .85 ||
              memory.waiting >= .6)) {
        obstruction = b;
        closest = ahead;
      }
    }
    if (obstruction != null) {
      if (memory.blocker != obstruction.id || memory.remaining <= 0) {
        final rel = obstruction.position - at;
        final cross = forward.dx * rel.dy - forward.dy * rel.dx;
        memory.side = cross.abs() > 12 ? -cross.sign : sideFor(id);
        memory.blocker = obstruction.id;
        memory.remaining = 1.2;
      }
    }
    final blocker = _bodies[memory.blocker];
    if (memory.remaining > 0 && blocker != null && blocker.shapes.isEmpty) {
      final relative = blocker.position - at;
      final ahead = relative.dx * forward.dx + relative.dy * forward.dy;
      if (ahead > -actor.radius && relative.distance < 380) {
        final tangent = Offset(-forward.dy, forward.dx) * memory.side;
        final goal =
            blocker.position +
            tangent * (actor.radius + blocker.radius + 36) +
            forward * (actor.radius + blocker.radius + 30);
        if (clear == null || clear(at, goal, actor.radius)) {
          preferred = unit(goal - at) * desired.distance;
          memory.mode = blocker.boss ? 'boss-yield' : 'bypass';
        }
      } else {
        memory.remaining = 0;
      }
    } else {
      memory.mode = 'pursuit';
    }
    // Escape a genuinely congested core toward the less occupied side. This is
    // an intermediate route, never a permanent ring/slot around the player.
    if (memory.waiting >= .6 && obstruction == null) {
      final pressure = neighbors
          .where((b) => !b.boss && (b.position - at).distance < 210)
          .fold(Offset.zero, (Offset sum, b) => sum + unit(at - b.position));
      if (pressure.distance > .05) {
        final outward = unit(pressure);
        final goal = at + outward * 170 + forward * 100;
        if (clear == null || clear(at, goal, actor.radius)) {
          preferred = unit(goal - at);
          memory.mode = 'bypass';
        }
      }
    }
    // Only one large body can actually fit inside a mummy's 36-unit reach.
    // Rear actors must seek a free approach instead of squeezing the front
    // attacker out of reach. These are temporary, irregular free-space goals.
    if (target != null && actor.contact) {
      if (memory.approach != null && memory.approachTarget != null) {
        memory.approach = memory.approach! + target - memory.approachTarget!;
      }
      memory.approachTarget = target;
      NavigationBody? pressure;
      var pressureDistance = 60.0;
      for (final b in [actor, ...neighbors]) {
        if (!b.contact) continue;
        final distance = (b.position - target).distance;
        if (distance < pressureDistance - .01 ||
            ((distance - pressureDistance).abs() < .01 &&
                (pressure == null || b.id < pressure.id))) {
          pressure = b;
          pressureDistance = distance;
        }
      }
      if (pressure != null &&
          pressure.id != id &&
          (at - target).distance < 520) {
        if (memory.approach == null ||
            memory.pressure != pressure.id ||
            (at - memory.approach!).distance < 15 ||
            memory.remaining <= 0) {
          final radial = unit(at - target);
          Offset? goal;
          var best = double.infinity;
          final range = 125.0 + hash(id) % 275;
          for (final turn in [
            0.0,
            .4 * memory.side,
            -.4 * memory.side,
            .8 * memory.side,
            -.8 * memory.side,
            1.2 * memory.side,
            -1.2 * memory.side,
            1.8 * memory.side,
            -1.8 * memory.side,
            2.4 * memory.side,
            -2.4 * memory.side,
          ]) {
            final p = target + rotate(radial, turn) * range;
            if (clear != null &&
                (!clear(at, p, actor.radius) ||
                    !clear(p, target, actor.radius))) {
              continue;
            }
            var score = (p - at).distance * .05 + turn.abs() * 5;
            for (final other in neighbors) {
              if (other.boss) continue;
              final gap = actor.radius + other.radius + 36;
              score +=
                  40 *
                  (1 - (p - other.position).distance / gap).clamp(0.0, 1.0);
            }
            if (score < best) {
              best = score;
              goal = p;
            }
          }
          memory.approach = goal;
          memory.pressure = pressure.id;
          memory.remaining = 1.2;
        }
        final goal = memory.approach;
        if (goal != null) {
          final radial = at - target, goalRadial = goal - target;
          final turn = math.atan2(
            radial.dx * goalRadial.dy - radial.dy * goalRadial.dx,
            radial.dx * goalRadial.dx + radial.dy * goalRadial.dy,
          );
          final waypoint = turn.abs() > .45 && radial.distance > 70
              ? target +
                    rotate(unit(radial), turn.clamp(-.45, .45)) *
                        math.max(125, radial.distance)
              : goal;
          preferred = (goal - at).distance < 18
              ? Offset.zero
              : unit(waypoint - at);
          memory.mode = (goal - at).distance < 18
              ? 'approach-hold'
              : 'approach';
          if (memory.mode == 'approach-hold') {
            memory.waiting = 0;
            memory.progressAge = 0;
            memory.anchor = at;
          }
        }
      } else {
        memory.approach = null;
        memory.pressure = -1;
      }
    }
    // Stagger expensive solves to 7–10Hz. Revalidate intent, cover and imminent
    // contact every movement step; final live occupancy always remains active.
    final axis = unit(preferred), magnitude = desired.distance.clamp(0.0, 1.0);
    var reuse =
        memory.decisionAge > 0 &&
        (axis - memory.requested).distance < .08 &&
        memory.velocity.distance <= speed * magnitude + .001;
    final shortEnd = at + memory.velocity * .12;
    if (reuse && clear != null && !clear(at, shortEnd, actor.radius)) {
      reuse = false;
    }
    if (reuse) {
      for (final b in neighbors) {
        if (b.shapes.isNotEmpty) {
          final end = shortEnd - b.velocity * .12;
          if (b.shapes.any(
            (shape) =>
                shape.contact(at, end, padding: actor.radius + 4) != null &&
                shape.signedDistance(end) < shape.signedDistance(at) - .00001,
          )) {
            reuse = false;
            break;
          }
        } else {
          final rel = at - b.position;
          final distance = closestDistance(at, memory.velocity, b, .12);
          if (distance < actor.radius + b.radius + 4 - .00001 &&
              distance < rel.distance - .00001) {
            reuse = false;
            break;
          }
        }
      }
    }
    if (reuse) return memory.velocity / speed;
    memory.requested = axis;
    memory.decisionAge = .1 + (hash(id) % 3) * .02;
    var best = Offset.zero, bestScore = double.infinity;
    final angles = [
      0.0,
      .3 * memory.side,
      -.3 * memory.side,
      .6 * memory.side,
      -.6 * memory.side,
      1.0 * memory.side,
      -1.0 * memory.side,
      1.45 * memory.side,
      -1.45 * memory.side,
      2.1 * memory.side,
      -2.1 * memory.side,
      math.pi,
    ];
    final velocities = <Offset>[
      Offset.zero,
      for (final scale in [1.0, .5])
        for (final angle in angles)
          rotate(axis, angle) * (speed * magnitude * scale),
    ];
    for (final velocity in velocities) {
      candidates++;
      final end = at + velocity * horizon;
      if (clear != null && !clear(at, end, actor.radius)) continue;
      var score = -3 * (velocity.dx * axis.dx + velocity.dy * axis.dy) / speed;
      score += (velocity - memory.velocity).distance / speed * .12;
      for (final b in neighbors) {
        checks++;
        if (b.shapes.isNotEmpty) {
          final endRelative = end - b.velocity * horizon;
          for (final shape in b.shapes) {
            final start = shape.signedDistance(at),
                finish = shape.signedDistance(endRelative);
            final delta = endRelative - at, outward = shape.outwardAt(at);
            if (start < actor.radius + 4 &&
                finish >= start &&
                delta.dx * outward.dx + delta.dy * outward.dy >= 0) {
              continue;
            }
            if (shape.contact(at, endRelative, padding: actor.radius + 4) !=
                null) {
              score +=
                  100 +
                  20 * (1 - (finish / (actor.radius + 4)).clamp(0.0, 1.0));
            } else {
              score += 2 * (1 - finish / (actor.radius + 45)).clamp(0.0, 1.0);
            }
          }
          continue;
        }
        final rel = at - b.position;
        final minimum = closestDistance(at, velocity, b, horizon),
            gap = actor.radius + b.radius + 4;
        final start = rel.distance;
        if (minimum < gap - .00001 && minimum < start - .00001) {
          score += 100 + 20 * (gap - minimum) / gap;
        }
        final future = (end - b.at(horizon)).distance;
        score += (b.boss ? 3 : 1.3) * (1 - future / (gap + 30)).clamp(0.0, 1.0);
      }
      // Deterministic ties retain the earlier candidate/committed side.
      if (score < bestScore - 1e-8) {
        bestScore = score;
        best = velocity;
      }
    }
    memory.velocity = best;
    if (best.distance < speed * .05 && memory.mode == 'pursuit') {
      memory.mode = 'density-wait';
    }
    return best / speed;
  }
}
