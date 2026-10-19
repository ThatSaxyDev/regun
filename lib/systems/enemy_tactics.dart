import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:regun/data/enemies.dart';

/// Local steering only. Attack phases own their committed directions/timing.
class EnemyTactics {
  Expando<int> _ids = Expando<int>();
  int _nextId = 0;
  final _cells = <(int, int), List<_Neighbor>>{};
  final _samples = <PositionComponent, _Neighbor>{};
  int neighborChecks = 0;
  int id(PositionComponent actor) => _ids[actor] ??= _nextId++;
  double side(PositionComponent actor) => id(actor).isEven ? 1 : -1;

  void clear() {
    _cells.clear();
    _samples.clear();
    _ids = Expando<int>();
    _nextId = 0;
  }

  /// One immutable position snapshot per frame, queried through nine local cells.
  void rebuild(Iterable<PositionComponent> enemies) {
    _cells.clear();
    _samples.clear();
    neighborChecks = 0;
    for (final actor in enemies) {
      final sample = _Neighbor(actor, actor.position.clone(), id(actor));
      _samples[actor] = sample;
      // Use floor below too: negative world coordinates need equal-width cells.
      final cell = (
        (sample.position.x / 128).floor(),
        (sample.position.y / 128).floor()
      );
      _cells.putIfAbsent(cell, () => []).add(sample);
    }
  }

  Vector2 spaced(PositionComponent actor, Vector2 desired) {
    final sample = _samples[actor];
    if (sample == null || desired.isZero()) return desired;
    final p = sample.position;
    final cx = (p.x / 128).floor(), cy = (p.y / 128).floor();
    final repel = Vector2.zero();
    for (var x = cx - 1; x <= cx + 1; x++) {
      for (var y = cy - 1; y <= cy + 1; y++) {
        for (final other in _cells[(x, y)] ?? const <_Neighbor>[]) {
          if (identical(other.actor, actor)) continue;
          neighborChecks++;
          final delta = p - other.position;
          final distance = delta.length;
          final gap =
              ((actor.size.x + other.actor.size.x) * .34).clamp(42.0, 80.0);
          if (distance >= gap) continue;
          if (distance < .001) {
            // Deterministic, opposite forces even for exactly coincident spawns.
            final low = math.min(sample.id, other.id);
            final high = math.max(sample.id, other.id);
            final angle = ((low * 73 + high * 37) % 360) * math.pi / 180;
            final sign = sample.id < other.id ? 1.0 : -1.0;
            delta.setValues(math.cos(angle) * sign, math.sin(angle) * sign);
          } else {
            delta.scale(1 / distance);
          }
          repel.addScaled(delta, 1 - distance / gap);
        }
      }
    }
    if (repel.length > 1.6) repel.scale(1.6 / repel.length);
    final result = desired + repel * 1.25;
    return result.length > 1 ? result.normalized() : result;
  }

  static Vector2 intent(EnemyKind kind, Vector2 position, Vector2 target,
      Vector2 targetVelocity, double side) {
    final delta = target - position;
    final distance = delta.length;
    if (distance < .001) return Vector2.zero();
    final toward = delta / distance;
    final tangent = Vector2(-toward.y, toward.x) * side;
    Vector2 lead(double seconds) {
      final offset = targetVelocity * seconds;
      if (offset.length > 120) offset.scale(120 / offset.length);
      return target + offset - position;
    }

    final result = switch (kind) {
      EnemyKind.scorpion =>
        toward + tangent * (.65 * ((distance - 110) / 220).clamp(0.0, 1.0)),
      EnemyKind.mummy => lead(.5),
      EnemyKind.runner =>
        toward + tangent * (.85 * ((distance - 150) / 180).clamp(0.0, 1.0)),
      EnemyKind.burster => lead(.35),
      EnemyKind.ranged =>
        toward * ((distance - 355) / 100).clamp(-1.0, 1.0) + tangent * .6,
      EnemyKind.nest || EnemyKind.sentinel => Vector2.zero(),
      _ => toward,
    };
    return result.length > 1 ? result.normalized() : result;
  }
}

class _Neighbor {
  _Neighbor(this.actor, this.position, this.id);
  final PositionComponent actor;
  final Vector2 position;
  final int id;
}
