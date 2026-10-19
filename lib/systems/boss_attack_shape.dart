import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:regun/components/weapons/bullet_component.dart';

enum BossShapeKind { circle, line, ring, sweep, trace }

/// Render and damage consume this exact immutable committed geometry.
class BossAttackShape {
  BossAttackShape.circle(Vector2 center, this.radius)
      : kind = BossShapeKind.circle,
        points = [center.clone()],
        width = 14,
        angle = 0,
        arc = math.pi * 2;
  BossAttackShape.line(List<Vector2> path, {this.width = 18})
      : kind = BossShapeKind.line,
        points = path.map((p) => p.clone()).toList(),
        radius = 0,
        angle = 0,
        arc = 0;
  BossAttackShape.trace(List<Vector2> path, {this.width = 22})
      : kind = BossShapeKind.trace,
        points = path.map((p) => p.clone()).toList(),
        radius = 0,
        angle = 0,
        arc = 0;
  BossAttackShape.ring(Vector2 center, this.radius,
      {required this.angle, this.arc = 1.25, this.width = 18})
      : kind = BossShapeKind.ring,
        points = [center.clone()];
  BossAttackShape.sweep(Vector2 center, this.radius,
      {required this.angle, required this.arc, this.width = 22})
      : kind = BossShapeKind.sweep,
        points = [center.clone()];

  final BossShapeKind kind;
  final List<Vector2> points;
  final double radius, width, angle, arc;

  static double angularDifference(double a, double b) =>
      (a - b + math.pi) % (math.pi * 2) - math.pi;

  bool hits(Vector2 point, double progress,
      {double previous = 0, double body = 30}) {
    if (kind == BossShapeKind.circle) {
      return point.distanceTo(points.first) <= radius + body;
    }
    if (kind == BossShapeKind.line || kind == BossShapeKind.trace) {
      for (var i = 0; i + 1 < points.length; i++) {
        if (kind == BossShapeKind.trace) {
          final count = points.length - 1;
          if ((i + 1) / count < previous || i / count > progress) continue;
        }
        if (BulletComponent.segmentDistanceSquared(
                point, points[i], points[i + 1]) <=
            (width + body) * (width + body)) {
          return true;
        }
      }
      return false;
    }
    final delta = point - points.first;
    final distance = delta.length;
    final heading = math.atan2(delta.y, delta.x);
    if (kind == BossShapeKind.ring) {
      final gapMargin =
          math.asin((body / math.max(distance, body)).clamp(0.0, 1.0));
      if (angularDifference(heading, angle).abs() < arc / 2 - gapMargin) {
        return false;
      }
      return distance >= radius * previous - width - body &&
          distance <= radius * progress + width + body;
    }
    if (distance <= width + body) return true;
    if (distance > radius + width + body) return false;
    final midpoint = angle + arc * (previous + progress) / 2;
    final halfSweep = (arc * (progress - previous)).abs() / 2;
    final margin = math.asin(((width + body) / distance).clamp(0.0, 1.0));
    return angularDifference(heading, midpoint).abs() <= halfSweep + margin;
  }

  void render(Canvas canvas,
      {required bool warning, required double progress, required Color color}) {
    final ink = Paint()
      ..color = color.withValues(alpha: warning ? .85 : 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = warning ? 2 : 5;
    final fill = Paint()..color = color.withValues(alpha: warning ? .08 : .20);
    final center = points.first.toOffset();
    if (kind == BossShapeKind.circle) {
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, ink);
      canvas.drawLine(
          center - const Offset(9, 0), center + const Offset(9, 0), ink);
      canvas.drawLine(
          center - const Offset(0, 9), center + const Offset(0, 9), ink);
    } else if (kind == BossShapeKind.ring) {
      final r = warning ? radius : math.max(1.0, radius * progress);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r),
          angle + arc / 2, math.pi * 2 - arc, false, ink);
      // Gap borders are visible before the wave moves.
      for (final edge in [angle - arc / 2, angle + arc / 2]) {
        final v = Offset(math.cos(edge), math.sin(edge));
        canvas.drawLine(
            center + v * 70, center + v * radius, ink..strokeWidth = 2);
      }
    } else if (kind == BossShapeKind.sweep) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, math.min(angle, angle + arc), arc.abs(), false, ink);
      final heading = warning ? angle : angle + arc * progress;
      final end =
          center + Offset(math.cos(heading), math.sin(heading)) * radius;
      canvas.drawLine(center, end, ink..strokeWidth = warning ? 2 : 7);
    } else {
      for (var i = 0; i + 1 < points.length; i++) {
        final active = kind != BossShapeKind.trace ||
            (progress >= i / (points.length - 1) &&
                progress <= (i + 1) / (points.length - 1));
        final start = points[i].toOffset(), end = points[i + 1].toOffset();
        final segmentInk = Paint()
          ..color = color.withValues(alpha: warning || !active ? .5 : 1)
          ..strokeWidth = warning || !active ? 2 : width * 2;
        canvas.drawLine(start, end, segmentInk);
        canvas.drawCircle(end, 9, ink);
      }
    }
  }
}
