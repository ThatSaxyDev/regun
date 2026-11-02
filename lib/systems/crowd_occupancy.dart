import 'package:regun/systems/target_shape.dart';

import 'dart:math' as math;

import 'package:flame/components.dart';

/// Live body occupancy, separate from the immutable steering snapshot. Each
/// accepted move reserves space immediately for actors updated later this frame.
class CrowdOccupancy {
  static const _cellSize = 160.0;
  final _cells = <(int, int), Set<PositionComponent>>{};
  final _radii = <PositionComponent, double>{};
  final _compound = <PositionComponent, CompoundGroundActor>{};
  final _keys = <PositionComponent, (int, int)>{};
  double _maximumRadius = 0;

  (int, int) _key(Vector2 p) =>
      ((p.x / _cellSize).floor(), (p.y / _cellSize).floor());

  void clear() {
    _cells.clear();
    _radii.clear();
    _compound.clear();
    _keys.clear();
    _maximumRadius = 0;
  }

  void forget(PositionComponent actor) {
    _cells[_keys.remove(actor)]?.remove(actor);
    _radii.remove(actor);
    _compound.remove(actor);
  }

  void _index(PositionComponent actor) {
    final next = _key(actor.position);
    final previous = _keys[actor];
    if (previous == next) return;
    final old = _cells[previous];
    old?.remove(actor);
    if (old?.isEmpty ?? false) _cells.remove(previous);
    _keys[actor] = next;
    _cells.putIfAbsent(next, () => {}).add(actor);
  }

  void rebuild(
    Iterable<PositionComponent> actors,
    double Function(PositionComponent) radiusOf,
  ) {
    clear();
    for (final actor in actors) {
      if (actor.isRemoving || actor.isRemoved) continue;
      if (actor is CompoundGroundActor) {
        _compound[actor] = actor as CompoundGroundActor;
        continue;
      }
      _radii[actor] = radiusOf(actor);
      _maximumRadius = math.max(_maximumRadius, _radii[actor]!);
      _index(actor);
    }
  }

  Iterable<PositionComponent> _near(Vector2 point, [double radius = 0]) sync* {
    final (x, y) = _key(point);
    final reach = ((radius + _maximumRadius + 16) / _cellSize).ceil().clamp(
      1,
      16,
    );
    for (var dx = -reach; dx <= reach; dx++) {
      for (var dy = -reach; dy <= reach; dy++) {
        yield* _cells[(x + dx, y + dy)] ?? const <PositionComponent>{};
      }
    }
  }

  bool _free(PositionComponent actor, Vector2 point, double radius) {
    for (final entry in _compound.entries) {
      if (identical(entry.key, actor) ||
          entry.key.isRemoving ||
          entry.key.isRemoved) {
        continue;
      }
      if (entry.value.groundShape.any(
        (s) => s.distance(point.toOffset()) < radius + 4,
      )) {
        return false;
      }
    }
    for (final other in _near(point, radius)) {
      if (identical(actor, other) || other.isRemoving || other.isRemoved) {
        continue;
      }
      final gap = radius + _radii[other]! + 4;
      if (point.distanceToSquared(other.position) < gap * gap - .001) {
        return false;
      }
    }
    return true;
  }

  /// Bounded search for a free, wall-valid spawn, including pending arrivals.
  bool place(
    PositionComponent actor,
    double radius,
    void Function(Vector2) constrain, {
    bool Function(Vector2)? allowed,
  }) {
    if (_radii.containsKey(actor) &&
        _free(actor, actor.position, radius) &&
        (allowed == null || allowed(actor.position))) {
      _index(actor);
      return true;
    }
    final origin = actor.position.clone();
    for (var i = 0; i <= 512; i++) {
      final point = origin.clone();
      if (i > 0) {
        final angle = i * 2.399963229728653; // Golden-angle spiral.
        final distance = 28 * math.sqrt(i);
        point.add(Vector2(math.cos(angle), math.sin(angle)) * distance);
      }
      constrain(point);
      if (allowed != null && !allowed(point)) continue;
      if (!_free(actor, point, radius)) continue;
      actor.position.setFrom(point);
      _radii[actor] = radius;
      _maximumRadius = math.max(_maximumRadius, radius);
      _index(actor);
      return true;
    }
    return false;
  }

  _CrowdContact? _blocker(
    PositionComponent actor,
    Vector2 from,
    Vector2 to,
    double radius,
    bool Function(PositionComponent)? blocks,
  ) {
    _CrowdContact? best;
    void accept(PositionComponent other, Vector2 normal, double travel) {
      if (normal.isZero()) normal = Vector2(1, 0);
      normal.normalize();
      if (best == null || travel < best!.travel - .00001) {
        best = _CrowdContact(other, normal, travel);
      } else if ((travel - best!.travel).abs() < .00001 &&
          best!.normals.length < 8 &&
          !best!.normals.any((n) => n.dot(normal) > .999)) {
        best!.normals.add(normal);
      }
    }

    for (final entry in _compound.entries) {
      final other = entry.key;
      if (identical(actor, other) ||
          other.isRemoving ||
          other.isRemoved ||
          (blocks != null && !blocks(other))) {
        continue;
      }
      for (final shape in entry.value.groundShape) {
        final start = shape.signedDistance(from.toOffset());
        final delta = to.toOffset() - from.toOffset(),
            normal = shape.outwardAt(from.toOffset());
        if (start < radius + 4 &&
            shape.signedDistance(to.toOffset()) >= start &&
            delta.dx * normal.dx + delta.dy * normal.dy >= 0) {
          continue;
        }
        final contact = shape.contact(
          from.toOffset(),
          to.toOffset(),
          padding: radius + 4,
        );
        if (contact != null) {
          final delta = to - from;
          final at =
              from +
              (delta.isZero() ? Vector2.zero() : delta.normalized() * contact);
          final axis = shape.b - shape.a, p = at.toOffset() - shape.a;
          final t = axis.distanceSquared < 1e-9
              ? 0.0
              : ((p.dx * axis.dx + p.dy * axis.dy) / axis.distanceSquared)
                    .clamp(0.0, 1.0);
          final closest = shape.a + axis * t;
          var normal = at - Vector2(closest.dx, closest.dy);
          if (shape is ClippedTargetCapsule && shape.side(at.toOffset()) > 0) {
            normal = Vector2(shape.normal.dx, shape.normal.dy);
          }
          accept(other, normal, contact);
        }
      }
    }
    final delta = to - from;
    final length2 = delta.length2;
    for (final other in _near(from, radius)) {
      if (identical(actor, other) || other.isRemoving || other.isRemoved) {
        continue;
      }
      if (blocks != null && !blocks(other)) continue;
      final gap = radius + _radii[other]! + 4;
      final startDistance2 = from.distanceToSquared(other.position);
      // Old checkpoints or external repositioning can start with overlaps.
      // Permit escape, never deeper penetration or crossing through the body.
      if (startDistance2 < gap * gap - .001 &&
          delta.dot(from - other.position) >= 0) {
        continue;
      }
      final t = length2 == 0
          ? 0.0
          : ((other.position - from).dot(delta) / length2).clamp(0.0, 1.0);
      final nearest = from + delta * t;
      if (nearest.distanceToSquared(other.position) < gap * gap - .001) {
        final capsule = TargetCapsule(
          other.position.toOffset(),
          other.position.toOffset(),
          gap,
        );
        final travel = capsule.contact(from.toOffset(), to.toOffset()) ?? 0;
        final at =
            from +
            (delta.isZero() ? Vector2.zero() : delta.normalized() * travel);
        accept(other, at - other.position, travel);
      }
    }
    best?.normals.sort(
      (a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y),
    );
    return best;
  }

  /// Substeps prevent fast actors crossing a body. Committed attacks stop at
  /// occupied space; ordinary pursuit can slide along the blocking body.
  /// Airborne actors can filter blockers and release their ground reservation.
  void move(
    PositionComponent actor,
    Vector2 delta, {
    required double radius,
    required void Function(Vector2) constrain,
    bool slide = true,
    bool reserve = true,
    bool Function(PositionComponent)? blocks,
    double side = 1,
    void Function(Vector2 from, Vector2 to)? beforeStep,
  }) {
    if (!reserve) {
      forget(actor);
    } else if (!_radii.containsKey(actor) && !place(actor, radius, constrain)) {
      return;
    }
    final steps = (delta.length / 12).ceil().clamp(1, 256);
    final step = delta / steps.toDouble();
    // Bound catch-up travel after an extreme frame as well as the loop cost.
    if (step.length > 12) step.scale(12 / step.length);
    for (var i = 0; i < steps; i++) {
      final from = actor.position.clone();
      var next = from + step;
      constrain(next);
      beforeStep?.call(from, next);
      final blocker = _blocker(actor, from, next, radius, blocks);
      if (blocker != null) {
        if (!slide) break;
        var normal = blocker.normal.clone();
        if (normal.isZero()) normal = Vector2(side, 0);
        normal.normalize();
        var tangent = step.clone();
        for (var pass = 0; pass < 2; pass++) {
          for (final contact in blocker.normals) {
            tangent -= contact * math.min(0.0, tangent.dot(contact));
          }
        }
        if (tangent.length2 < step.length2 * .04) {
          tangent = Vector2(-normal.y, normal.x) * (step.length * side);
        }
        next = from + tangent;
        constrain(next);
        if (_blocker(actor, from, next, radius, blocks) != null ||
            next.distanceToSquared(from) < step.length2 * .04) {
          // A solid can close the preferred side of another body. The other
          // tangent still has to pass the same swept body/cover constraints.
          next = from - Vector2(-normal.y, normal.x) * (step.length * side);
          constrain(next);
          if (_blocker(actor, from, next, radius, blocks) != null) break;
        }
      }
      actor.position.setFrom(next);
    }
    if (reserve) _index(actor);
  }
}

class _CrowdContact {
  _CrowdContact(this.actor, Vector2 normal, this.travel) : normals = [normal];
  final PositionComponent actor;
  final List<Vector2> normals;
  Vector2 get normal => normals.first;
  final double travel;
}
