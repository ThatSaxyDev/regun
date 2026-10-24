import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/systems/arena_geometry.dart';

/// Small, committed corner routes around registered temporary solids. Ordinary
/// pursuit uses this before occupancy movement; committed attacks never do.
class ObstacleRouter {
  final _routes = Expando<_CornerRoute>();

  Vector2 steer(
    PositionComponent actor,
    Vector2 desired,
    Vector2 target,
    ArenaGeometry geometry, {
    required double radius,
    required double side,
  }) {
    if (desired.isZero() || desired.dot(target - actor.position) <= 0) {
      return desired;
    }
    // Treat exact contact as traversable when moving away from a face.
    // The route corners themselves keep an additional fourteen units of room.
    final obstacles = geometry.solids.toList(growable: false);
    final solids = [for (final r in obstacles) r.inflate(radius - .01)];
    final destination = target.clone();
    geometry.constrain(destination, radius + 2);
    bool clear(Vector2 a, Vector2 b) =>
        !solids.any((r) => ArenaGeometry.crosses(a, b, r));
    final ahead = actor.position + desired.normalized() * (radius * 2 + 14);
    if (clear(actor.position, destination) && clear(actor.position, ahead)) {
      _routes[actor] = null;
      return desired;
    }
    var route = _routes[actor];
    if (route == null ||
        !_sameObstacles(route.obstacles, obstacles) ||
        route.points.last.distanceTo(destination) > radius ||
        !clear(actor.position, route.points[route.index])) {
      route = _plan(
        actor.position,
        destination,
        obstacles,
        geometry,
        radius,
        side,
        clear,
      );
      _routes[actor] = route;
    }
    if (route == null) return desired;
    // Skip completed corners only when the next segment has body clearance.
    for (var i = route.points.length - 1; i > route.index; i--) {
      if (clear(actor.position, route.points[i])) {
        route.index = i;
        break;
      }
    }
    final delta = route.points[route.index] - actor.position;
    return delta.length < .001 ? desired : delta.normalized() * desired.length;
  }

  _CornerRoute? _plan(
    Vector2 start,
    Vector2 target,
    List<Rect> obstacles,
    ArenaGeometry geometry,
    double radius,
    double side,
    bool Function(Vector2, Vector2) clear,
  ) {
    // Clearance beyond the collision expansion lets an actor round a corner
    // without repeatedly rubbing the same face. Include other registered
    // solids, so adjacent cover cannot invalidate every single-prop detour.
    final corners = [
      for (final obstacle in obstacles) ...[
        Vector2(obstacle.left - radius - 14, obstacle.top - radius - 14),
        Vector2(obstacle.right + radius + 14, obstacle.top - radius - 14),
        Vector2(obstacle.right + radius + 14, obstacle.bottom + radius + 14),
        Vector2(obstacle.left - radius - 14, obstacle.bottom + radius + 14),
      ],
    ];
    if (side < 0) {
      final reversed = corners.reversed.toList();
      corners.setAll(0, reversed);
    }
    final nodes = [start, target, ...corners];
    final allowed = geometry.bounds.interior.deflate(radius + 2);
    bool within(Vector2 point) =>
        point.x >= allowed.left &&
        point.x <= allowed.right &&
        point.y >= allowed.top &&
        point.y <= allowed.bottom;
    final distance = List<double>.filled(nodes.length, double.infinity)
      ..[0] = 0;
    final previous = List<int>.filled(nodes.length, -1);
    final visited = List<bool>.filled(nodes.length, false);
    for (var step = 0; step < nodes.length; step++) {
      var current = -1;
      for (var i = 0; i < nodes.length; i++) {
        if (!visited[i] &&
            distance[i].isFinite &&
            (current < 0 || distance[i] < distance[current])) {
          current = i;
        }
      }
      if (current < 0) break;
      if (current == 1) {
        final points = <Vector2>[];
        for (var i = 1; i > 0; i = previous[i]) {
          points.insert(0, nodes[i].clone());
        }
        return _CornerRoute(obstacles, points);
      }
      visited[current] = true;
      for (var next = 1; next < nodes.length; next++) {
        if (visited[next] ||
            !within(nodes[next]) ||
            !clear(nodes[current], nodes[next])) {
          continue;
        }
        final cost = distance[current] + nodes[current].distanceTo(nodes[next]);
        if (cost < distance[next]) {
          distance[next] = cost;
          previous[next] = current;
        }
      }
    }
    return null;
  }

  bool _sameObstacles(List<Rect> a, List<Rect> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}

class _CornerRoute {
  _CornerRoute(this.obstacles, this.points);
  final List<Rect> obstacles;
  final List<Vector2> points;
  int index = 0;
}
