import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/systems/arena_bounds.dart';

class ArenaGeometry {
  ArenaGeometry(this.bounds, {required this.obstacles});
  final ArenaBounds bounds;
  final List<Rect> obstacles;

  void constrain(Vector2 point, double radius) {
    bounds.constrainPlayer(point, radius);
    for (final obstacle in obstacles) {
      final expanded = obstacle.inflate(radius);
      if (!expanded.contains(point.toOffset())) continue;
      final edges = [
        point.x - expanded.left,
        expanded.right - point.x,
        point.y - expanded.top,
        expanded.bottom - point.y,
      ];
      var nearest = 0;
      for (var i = 1; i < 4; i++) {
        if (edges[i] < edges[nearest]) nearest = i;
      }
      switch (nearest) {
        case 0:
          point.x = expanded.left;
        case 1:
          point.x = expanded.right;
        case 2:
          point.y = expanded.top;
        case 3:
          point.y = expanded.bottom;
      }
    }
  }

  void move(Vector2 point, Vector2 delta, double radius) {
    final steps = (delta.length / (radius * 0.6).clamp(8, 50)).ceil().clamp(
      1,
      256,
    );
    for (var i = 0; i < steps; i++) {
      point.addScaled(delta, 1 / steps);
      constrain(point, radius);
    }
  }

  bool blocked(Vector2 start, Vector2 end) =>
      obstacles.any((rect) => crosses(start, end, rect));

  static bool crosses(Vector2 start, Vector2 end, Rect rect) {
    var t0 = 0.0, t1 = 1.0;
    final dx = end.x - start.x, dy = end.y - start.y;
    final p = [-dx, dx, -dy, dy];
    final q = [
      start.x - rect.left,
      rect.right - start.x,
      start.y - rect.top,
      rect.bottom - start.y,
    ];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return false;
        continue;
      }
      final t = q[i] / p[i];
      if (p[i] < 0) {
        if (t > t1) return false;
        if (t > t0) t0 = t;
      } else {
        if (t < t0) return false;
        if (t < t1) t1 = t;
      }
    }
    return t0 <= t1;
  }
}
