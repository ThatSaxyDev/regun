import 'dart:math' as math;
import 'dart:ui';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/components.dart';
import 'package:regun/components/weapons/bullet_component.dart';

enum BossShapeKind { circle, line, ring, sweep, trace }

/// Render and damage consume this exact immutable committed geometry.
class BossAttackShape {
  BossAttackShape.circle(Vector2 center, this.radius)
      : kind = BossShapeKind.circle,
        points = [center.clone()],
        innerRadius = 0,
        width = 14,
        angle = 0,
        arc = math.pi * 2;
  BossAttackShape.line(List<Vector2> path, {this.width = 18})
      : kind = BossShapeKind.line,
        points = path.map((p) => p.clone()).toList(),
        innerRadius = 0,
        radius = 0,
        angle = 0,
        arc = 0;
  BossAttackShape.trace(List<Vector2> path, {this.width = 22})
      : kind = BossShapeKind.trace,
        points = path.map((p) => p.clone()).toList(),
        innerRadius = 0,
        radius = 0,
        angle = 0,
        arc = 0;
  BossAttackShape.ring(Vector2 center, this.radius,
      {required this.angle, this.arc = 1.25, this.width = 18})
      : kind = BossShapeKind.ring,
        points = [center.clone()],
        innerRadius = 0;
  BossAttackShape.sweep(Vector2 center, this.radius,
      {required this.angle,
      required this.arc,
      this.width = 22,
      this.innerRadius = 0})
      : kind = BossShapeKind.sweep,
        points = [center.clone()];

  final BossShapeKind kind;
  final List<Vector2> points;
  final double radius, width, angle, arc, innerRadius;

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
    if (distance + body < innerRadius) return false;
    if (distance <= width + body) return true;
    if (distance > radius + width + body) return false;
    final midpoint = angle + arc * (previous + progress) / 2;
    final halfSweep = (arc * (progress - previous)).abs() / 2;
    final margin = math.asin(((width + body) / distance).clamp(0.0, 1.0));
    return angularDifference(heading, midpoint).abs() <= halfSweep + margin;
  }

  void render(Canvas canvas,
      {required bool warning,
      required double progress,
      required Color color,
      double warningProgress = 0,
      bool reducedMotion = false,
      Vector2? warningFocus,
      AttackMaterial material = AttackMaterial.stone}) {
    final center = points.first.toOffset();
    final textureProgress = reducedMotion && !warning ? .35 : progress;
    if (kind == BossShapeKind.circle) {
      AttackVfx.disk(canvas, center, radius,
          warning: warning,
          progress: warning ? warningProgress : textureProgress,
          material: material);
    } else if (kind == BossShapeKind.ring) {
      final r = warning
          ? (warningFocus?.distanceTo(points.first) ?? radius)
              .clamp(120.0, radius)
          : math.max(1.0, radius * progress);
      AttackVfx.wave(canvas, center, r, angle + arc / 2, math.pi * 2 - arc,
          warning: warning,
          progress: textureProgress,
          material: material,
          width: width);
      for (final edge in [angle - arc / 2, angle + arc / 2]) {
        final v = Offset(math.cos(edge), math.sin(edge));
        AttackVfx.chip(canvas, center + v * r, 12, const Color(0xffD8CBA4));
      }
    } else if (kind == BossShapeKind.sweep) {
      if (warning) {
        AttackVfx.wave(canvas, center, radius, angle, arc,
            warning: true, progress: warningProgress, material: material);
        AttackVfx.fan(canvas, center, radius, angle, arc,
            warning: true,
            progress: warningProgress,
            material: material,
            innerRadius: innerRadius);
        for (final edge in [angle, angle + arc]) {
          final end = center + Offset(math.cos(edge), math.sin(edge)) * radius;
          AttackVfx.ribbon(
              canvas,
              center + Offset(math.cos(edge), math.sin(edge)) * innerRadius,
              end,
              material == AttackMaterial.chain && edge == angle ? width : 10,
              warning: true,
              progress: warningProgress,
              material: material == AttackMaterial.chain && edge == angle
                  ? material
                  : AttackMaterial.stone);
        }
      } else {
        final heading = angle + arc * progress;
        final end =
            center + Offset(math.cos(heading), math.sin(heading)) * radius;
        AttackVfx.ribbon(
            canvas,
            center + Offset(math.cos(heading), math.sin(heading)) * innerRadius,
            end,
            width,
            warning: false,
            progress: textureProgress,
            material: material);
        AttackVfx.wave(canvas, center, radius, heading - .13, .26,
            warning: false,
            progress: textureProgress,
            material: material,
            width: width);
      }
    } else {
      for (var i = 0; i + 1 < points.length; i++) {
        final active = kind != BossShapeKind.trace ||
            (progress >= i / (points.length - 1) &&
                progress <= (i + 1) / (points.length - 1));
        AttackVfx.ribbon(
            canvas, points[i].toOffset(), points[i + 1].toOffset(), width,
            spent: !warning &&
                kind == BossShapeKind.trace &&
                progress > (i + 1) / (points.length - 1),
            warning: warning || !active,
            progress: warning ? warningProgress : textureProgress,
            material: material);
      }
    }
  }
}
