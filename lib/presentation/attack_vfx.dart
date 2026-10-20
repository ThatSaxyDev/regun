import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';

/// World-space pixel masonry, glass and embers. Damage stays in the authored
/// shape; these bounded-cost strokes give that footprint physical material.
enum AttackMaterial { stone, glass, chain, ember, poison, shadow }

class AttackVfx {
  static const _dark = Color(0xff17141C);
  static Offset snap(Offset p) =>
      Offset((p.dx / 3).round() * 3, (p.dy / 3).round() * 3);
  static Color tint(AttackMaterial material) => switch (material) {
        AttackMaterial.glass => const Color(0xffB1C9C9),
        AttackMaterial.chain => const Color(0xffB49A76),
        AttackMaterial.ember => const Color(0xffD69A67),
        AttackMaterial.poison => const Color(0xffA2AD72),
        AttackMaterial.shadow => const Color(0xffBB869E),
        AttackMaterial.stone => const Color(0xffD3A47F),
      };
  static void stroke(
      Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.length < 2) return;
    final path = Path()..moveTo(snap(points.first).dx, snap(points.first).dy);
    for (final p in points.skip(1)) {
      final q = snap(p);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..isAntiAlias = false);
  }

  static void chip(Canvas canvas, Offset point, double size, Color color) {
    final p = snap(point);
    canvas.drawRect(
        Rect.fromCenter(center: p, width: size, height: size),
        Paint()
          ..color = color
          ..isAntiAlias = false);
  }

  static int row(AttackMaterial material) => switch (material) {
        AttackMaterial.glass => 1,
        AttackMaterial.ember || AttackMaterial.poison => 3,
        _ => 0,
      };
  static void stamp(Canvas canvas, int frame, Offset point, double width,
      {double alpha = 1,
      double? height,
      AttackMaterial material = AttackMaterial.stone,
      Anchor anchor = Anchor.bottomCenter}) {
    if (!RegunArt.shared.contains('effects/combat_materials')) return;
    final sprite = RegunArt.shared.rawSprite('effects/combat_materials', frame);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      // Muted stone/iron/glass share the floor's ambient light. Emission stays
      // warm and readable in the furnace row and electrical effects.
      ..colorFilter = material == AttackMaterial.ember
          ? null
          : const ColorFilter.matrix([
              .84,
              .04,
              .02,
              0,
              0,
              .03,
              .86,
              .03,
              0,
              0,
              .02,
              .04,
              .81,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ])
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1));
    if (material == AttackMaterial.poison) {
      paint.colorFilter = const ColorFilter.matrix([
        .45,
        .7,
        0,
        0,
        0,
        .8,
        .25,
        0,
        0,
        0,
        .15,
        .5,
        .25,
        0,
        0,
        0,
        0,
        0,
        1,
        0
      ]);
    } else if (material == AttackMaterial.shadow) {
      paint.colorFilter = const ColorFilter.matrix([
        .75,
        0,
        .1,
        0,
        0,
        0,
        .55,
        0,
        0,
        0,
        .35,
        0,
        .65,
        0,
        0,
        0,
        0,
        0,
        1,
        0
      ]);
    }
    sprite.render(canvas,
        position: Vector2(point.dx, point.dy),
        size: Vector2(
            width, height ?? width * sprite.srcSize.y / sprite.srcSize.x),
        anchor: anchor,
        overridePaint: paint);
  }

  static void shard(Canvas canvas, Offset foot, double size, Color color,
      {double lean = 0}) {
    stamp(canvas, 7, foot, size * 1.3);
  }

  static void disk(Canvas canvas, Offset center, double radius,
      {required bool warning,
      required double progress,
      AttackMaterial material = AttackMaterial.stone}) {
    final base = row(material) * 6;
    // Overlapping textured fault plates mark the complete floor footprint.
    // The erupting sprite shares its footing with those plates, never a UI ring.
    for (final dy in [-.48, .48]) {
      stamp(
          canvas, base, center + Offset(0, radius * (dy + .35)), radius * 1.65,
          alpha: warning ? .68 + progress * .25 : .55, material: material);
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * .88;
      stamp(canvas, base + 5, p + Offset(0, radius * .1), radius * .36,
          alpha: warning ? .75 : .9, material: material);
    }
    if (!warning) {
      final frame = 1 + (progress * 5).floor().clamp(0, 4);
      stamp(
          canvas, base + frame, center + Offset(0, radius * .45), radius * 1.7,
          material: material);
    }
  }

  static void ribbon(Canvas canvas, Offset start, Offset end, double width,
      {required bool warning,
      required double progress,
      AttackMaterial material = AttackMaterial.stone,
      bool spent = false}) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final n = Offset(-delta.dy, delta.dx) / length;
    final count = (length /
            (material == AttackMaterial.chain ? 16 : math.max(38, width * 1.4)))
        .ceil()
        .clamp(1, 64);
    final clip = canvas.getLocalClipBounds().inflate(math.max(100, width * 4));
    for (var i = 0; i <= count; i++) {
      final p = start + delta * (i / count);
      if (!clip.contains(p)) continue;
      if (material == AttackMaterial.chain) {
        final slack = warning
            ? math.sin(i / count * math.pi) * (1 - progress) * width
            : 0.0;
        canvas.save();
        canvas.translate(p.dx + n.dx * slack, p.dy + n.dy * slack);
        canvas.rotate(math.atan2(delta.dy, delta.dx) - math.pi / 2);
        stamp(canvas, i.isEven ? 16 : 17, Offset.zero, warning ? 13 : 18,
            anchor: Anchor.center, alpha: warning ? .78 : 1);
        canvas.restore();
      } else {
        final base = row(material) * 6;
        final frame =
            warning ? 0 : 1 + ((progress * 4).floor() + i % 2).clamp(0, 4);
        stamp(canvas, base + frame, p + Offset(0, width * .7), width * 2.4,
            alpha: spent
                ? .25
                : warning
                    ? .6 + progress * .35
                    : 1,
            material: material);
      }
    }
    if (material == AttackMaterial.chain) {
      anchor(canvas, end, math.atan2(delta.dy, delta.dx), warning ? .85 : 1);
    }
  }

  static void anchor(Canvas canvas, Offset point, double angle, double scale) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle - math.pi / 2);
    stamp(canvas, 12, Offset.zero, 85 * scale, anchor: Anchor.center);
    canvas.restore();
  }

  static void fan(
      Canvas canvas, Offset center, double radius, double angle, double arc,
      {required bool warning,
      required double progress,
      AttackMaterial material = AttackMaterial.stone,
      double innerRadius = 0}) {
    final sector = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
          Rect.fromCircle(center: center, radius: radius), angle, arc, false)
      ..close();
    final footprint = innerRadius > 0
        ? Path.combine(
            PathOperation.difference,
            sector,
            Path()
              ..addOval(Rect.fromCircle(center: center, radius: innerRadius)))
        : sector;
    canvas.save();
    canvas.clipPath(footprint);
    disk(canvas, center, radius,
        warning: warning, progress: progress, material: material);
    canvas.restore();
  }

  static void wave(
      Canvas canvas, Offset center, double radius, double angle, double arc,
      {required bool warning,
      required double progress,
      AttackMaterial material = AttackMaterial.stone,
      double width = 18}) {
    final count =
        (radius * arc.abs() / math.max(28, width * 1.5)).ceil().clamp(3, 140);
    final base = row(material) * 6;
    final clip = canvas.getLocalClipBounds().inflate(math.max(70, width * 4));
    for (var i = 0; i <= count; i++) {
      final a = angle + arc * i / count;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      if (!clip.contains(p)) continue;
      stamp(canvas, base + (warning ? 0 : 1 + i % 3), p + Offset(0, width * .6),
          warning ? 30 : width * 2.7,
          alpha: warning ? .7 : 1, material: material);
    }
  }

  static void armour(Canvas canvas, Offset center, double radius,
      {double facing = 0, bool full = true}) {
    for (var i = 0; i < (full ? 6 : 3); i++) {
      final a = full ? i * math.pi / 3 : facing + (i - 1) * .6;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a);
      final plate = Path()
        ..addPolygon(const [
          Offset(-4, -10),
          Offset(3, -10),
          Offset(7, -4),
          Offset(7, 4),
          Offset(3, 10),
          Offset(-4, 10)
        ], true);
      canvas.drawPath(
          plate,
          Paint()
            ..color = const Color(0xff33454F)
            ..isAntiAlias = false);
      stroke(
          canvas,
          const [Offset(3, -9), Offset(6, -3), Offset(6, 4), Offset(3, 9)],
          const Color(0xffABC0BE),
          3);
      canvas.restore();
    }
  }

  static void lightning(Canvas canvas, Offset start, Offset end, double fade,
      {bool heavy = false}) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final n = Offset(-delta.dy, delta.dx) / length;
    final count = (length / 22).ceil().clamp(3, 36);
    final points = [
      start,
      for (var i = 1; i < count; i++)
        start +
            delta * (i / count) +
            n * ((i.isEven ? -1 : 1) * (7 + i % 3 * 3)),
      end
    ];
    stroke(canvas, points, _dark.withValues(alpha: fade), heavy ? 11 : 8);
    stroke(canvas, points, const Color(0xff79AAA8).withValues(alpha: fade),
        heavy ? 7 : 5);
    stroke(canvas, points, const Color(0xffE0E8CF).withValues(alpha: fade), 3);
    for (var i = 2; i < points.length; i += 4) {
      stroke(canvas, [points[i], points[i] + n * 16 + const Offset(8, 0)],
          const Color(0xffA8D5BC).withValues(alpha: fade), 3);
    }
    for (final p in [start, end]) {
      chip(canvas, p, heavy ? 9 : 6,
          const Color(0xffE7E9D5).withValues(alpha: fade));
    }
  }
}
