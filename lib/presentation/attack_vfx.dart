import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';

/// World-space pixel masonry, glass and embers. Damage stays in the authored
/// shape; these bounded-cost strokes give that footprint physical material.
enum AttackMaterial { stone, glass, chain, ember, poison, shadow, laser }

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
    AttackMaterial.laser => const Color(0xffF49A75),
  };
  static void stroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
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
        ..isAntiAlias = false,
    );
  }

  static void chip(Canvas canvas, Offset point, double size, Color color) {
    final p = snap(point);
    canvas.drawRect(
      Rect.fromCenter(center: p, width: size, height: size),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  static int row(AttackMaterial material) => switch (material) {
    AttackMaterial.glass => 1,
    AttackMaterial.ember || AttackMaterial.poison => 3,
    _ => 0,
  };
  static void stamp(
    Canvas canvas,
    int frame,
    Offset point,
    double width, {
    double alpha = 1,
    double? height,
    ColorFilter? grading,
    AttackMaterial material = AttackMaterial.stone,
    Anchor anchor = Anchor.bottomCenter,
  }) {
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
        .48,
        .20,
        .03,
        0,
        0,
        .18,
        .48,
        .06,
        0,
        0,
        .06,
        .20,
        .25,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
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
        0,
      ]);
    }
    if (grading != null) paint.colorFilter = grading;
    sprite.render(
      canvas,
      position: Vector2(point.dx, point.dy),
      size: Vector2(
        width,
        height ?? width * sprite.srcSize.y / sprite.srcSize.x,
      ),
      anchor: anchor,
      overridePaint: paint,
    );
  }

  static void shard(
    Canvas canvas,
    Offset foot,
    double size,
    Color color, {
    double lean = 0,
  }) {
    stamp(canvas, 7, foot, size * 1.3);
  }

  static void disk(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    ColorFilter? ambient,
  }) {
    if (!canvas.getLocalClipBounds().inflate(radius).contains(center)) return;
    final p = progress.clamp(0.0, 1.0);
    // One planted floor footprint shares the authoritative circular radius.
    // Its irregular material edge replaces overlapping tall eruption stamps.
    final frame = warning
        ? (material == AttackMaterial.ember ? 2 : 0)
        : switch (material) {
            AttackMaterial.ember => 3,
            AttackMaterial.poison => 4,
            AttackMaterial.glass => 5,
            AttackMaterial.chain => 6,
            AttackMaterial.shadow => 7,
            _ => 1,
          };
    floorArea(
      canvas,
      frame,
      center,
      radius * 2,
      alpha: warning ? .60 + p * .28 : .78 * ((1 - p) / .22).clamp(0.0, 1.0),
      ambient: ambient,
    );
    if (warning &&
        material != AttackMaterial.stone &&
        material != AttackMaterial.ember) {
      floorArea(
        canvas,
        switch (material) {
          AttackMaterial.poison => 4,
          AttackMaterial.glass => 5,
          AttackMaterial.chain => 6,
          _ => 7,
        },
        center,
        radius * 1.8,
        alpha: .18 + p * .14,
        ambient: ambient,
      );
    }
  }

  static const floorGrade = ColorFilter.matrix([
    .81,
    .05,
    .02,
    0,
    0,
    .03,
    .85,
    .03,
    0,
    0,
    .02,
    .04,
    .78,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  static void floorArea(
    Canvas canvas,
    int frame,
    Offset center,
    double width, {
    double alpha = 1,
    ColorFilter? ambient,
  }) {
    if (!RegunArt.shared.contains('effects/grounded_areas')) return;
    RegunArt.shared
        .rawSprite('effects/grounded_areas', frame)
        .render(
          canvas,
          position: Vector2(center.dx, center.dy),
          size: Vector2.all(width),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ambient ?? floorGrade
            ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
        );
  }

  /// Shared grounded burst for mines and future death explosions. Reuses the
  /// grounded ordnance atlas; heat gives way to planted dust/char.
  static void explosion(
    Canvas canvas,
    Offset center,
    double radius, {
    required double progress,
    required ColorFilter ambient,
    bool reducedMotion = false,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final fade = (1 - p).clamp(0.0, 1.0);
    groundMaterial(
      canvas,
      1,
      center,
      radius * 2,
      height: radius * .94,
      alpha: .48 * fade,
      ambient: ambient,
    );
    final expansion = reducedMotion
        ? 1.0
        : .72 + .28 * (1 - math.pow(1 - p, 3));
    groundMaterial(
      canvas,
      0,
      center + Offset(0, -radius * .10),
      radius * 1.8 * expansion,
      height: radius * 1.02 * expansion,
      alpha: (reducedMotion ? .50 : .68) * fade,
      ambient: ambient,
    );
  }

  static void groundMaterial(
    Canvas canvas,
    int frame,
    Offset point,
    double width, {
    required double height,
    double alpha = 1,
    required ColorFilter ambient,
  }) {
    final art = RegunArt.shared;
    if (!art.contains('effects/grounded_ordnance')) return;
    art
        .rawSprite('effects/grounded_ordnance', frame)
        .render(
          canvas,
          position: Vector2(point.dx, point.dy),
          size: Vector2(width, height),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ambient
            ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
        );
  }

  static void sporePatch(
    Canvas canvas,
    Offset point,
    double radius, {
    required double progress,
    required ColorFilter ambient,
    bool reducedMotion = false,
    bool fullFootprint = false,
  }) {
    final p = progress.clamp(0.0, 1.0), fade = ((1 - p) / .25).clamp(0.0, 1.0);
    groundMaterial(
      canvas,
      3,
      point,
      radius * 2,
      height: radius * (fullFootprint ? 2 : 1.25),
      alpha: .62 * fade,
      ambient: ambient,
    );
    if (p < .16) {
      groundMaterial(
        canvas,
        2,
        point,
        radius * (reducedMotion ? 1.7 : 1.3 + p * 3),
        height: radius * .90,
        alpha: .48 * (1 - p / .16),
        ambient: ambient,
      );
    }
  }

  /// A short outward pressure wave, distinct from ember ordnance blasts.
  static void upgradePulse(
    Canvas canvas,
    Offset center,
    double radius, {
    required double progress,
    bool reducedMotion = false,
  }) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    final r = reducedMotion
        ? radius * .8
        : 36 + (radius - 36) * (1 - math.pow(1 - progress, 3));
    for (var i = 0; i < 40; i++) {
      final a = i * math.pi / 20,
          normal = Offset(math.cos(a), math.sin(a)),
          tangent = Offset(-normal.dy, normal.dx);
      final p = center + normal * r.toDouble();
      final points = [
        p - tangent * 10 - normal * 3,
        p,
        p + tangent * 10 - normal * 3,
      ];
      stroke(
        canvas,
        points,
        Color.fromRGBO(26, 48, 48, .72 * fade),
        reducedMotion ? 9 : 13,
      );
      stroke(
        canvas,
        points,
        Color.fromRGBO(166, 201, 187, (reducedMotion ? .65 : .92) * fade),
        reducedMotion ? 4 : 6,
      );
      if (!reducedMotion && i.isEven) {
        stroke(
          canvas,
          points.take(2).toList(),
          Color.fromRGBO(219, 228, 188, .75 * fade),
          2,
        );
      }
      if (i.isEven) {
        chip(
          canvas,
          p - normal * 13,
          4,
          Color.fromRGBO(197, 202, 171, .38 * fade),
        );
      }
    }
  }

  /// Matte ground scars belong to a creature's leap, not a gunshot lane.
  static void lungeWarning(
    Canvas canvas,
    Offset start,
    Offset end, {
    required double progress,
    required ColorFilter ambient,
  }) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final direction = delta / length;
    final p = progress.clamp(0.0, 1.0);
    // The complete committed route and landing are visible from the first frame.
    // Small stone notches match aimed weapon previews without a flashing arrow.
    for (var d = 44.0; d < length - 25; d += 24) {
      final point = start + direction * d;
      chip(canvas, point, 7, const Color(0xff292A25).withValues(alpha: .72));
      chip(
        canvas,
        point,
        4,
        const Color(0xffB5AB95).withValues(alpha: .70 + p * .16),
      );
    }
    floorArea(canvas, 0, end, 104, alpha: .78 + p * .12, ambient: ambient);
    for (final sign in [-1, 1]) {
      final side = Offset(-direction.dy, direction.dx) * sign.toDouble();
      final foot = end + side * 43;
      chip(canvas, foot, 7, const Color(0xff292A25));
      chip(canvas, foot, 3, const Color(0xffB5AB95).withValues(alpha: .80));
    }
  }

  static void groundStamp(
    Canvas canvas,
    int frame,
    Offset point,
    double width, {
    required double height,
    double alpha = 1,
    ColorFilter? ambient,
  }) {
    if (!RegunArt.shared.contains('effects/ground_motion')) return;
    RegunArt.shared
        .rawSprite('effects/ground_motion', frame)
        .render(
          canvas,
          position: Vector2(point.dx, point.dy),
          size: Vector2(width, height),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ambient
            ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
        );
  }

  static void dashDust(
    Canvas canvas,
    Offset foot,
    Offset direction, {
    required double progress,
    required ColorFilter ambient,
    bool reducedMotion = false,
  }) {
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    final p = progress.clamp(0.0, 1.0);
    groundStamp(
      canvas,
      p < .4 ? 2 : 3,
      Offset.zero,
      reducedMotion ? 52 : 54 + 22 * p,
      height: reducedMotion ? 19 : 20 + 7 * p,
      alpha: .65 * (1 - p),
      ambient: ambient,
    );
    canvas.restore();
  }

  /// Continuous hostile energy. One unbroken core, no repeated impact sprites.
  /// Width is the exact line-shape radius; outer glow is non-damaging light.
  static void laser(
    Canvas canvas,
    Offset start,
    Offset end,
    double width, {
    required bool warning,
    required double progress,
    bool reducedMotion = false,
  }) {
    final delta = end - start;
    final length = delta.distance;
    if (length < 1) return;
    canvas.save();
    canvas.translate(start.dx, start.dy);
    canvas.rotate(math.atan2(delta.dy, delta.dx));
    canvas.clipRect(Rect.fromLTWH(0, -width - 8, length, 2 * (width + 8)));
    void band(double halfWidth, Color color) => canvas.drawRect(
      Rect.fromLTWH(0, -halfWidth, length, halfWidth * 2),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
    if (warning) {
      band(width, const Color(0x163C1312));
      band(2, Color.fromRGBO(232, 117, 88, .45 + progress * .35));
      final paint = Paint()
        ..color = const Color(0xffCB9775)
        ..isAntiAlias = false;
      for (final side in [-1, 1]) {
        canvas.drawRect(
          Rect.fromLTWH(-6, side * (width + 5) - 2, 17, 4),
          paint,
        );
      }
    } else {
      final fade = ((1 - progress) / .18).clamp(.35, 1.0);
      band(width + 5, Color.fromRGBO(221, 67, 41, .10 * fade));
      band(width, Color.fromRGBO(239, 99, 51, .65 * fade));
      band(width * .58, Color.fromRGBO(255, 175, 103, .95 * fade));
      band(width * .20, Color.fromRGBO(255, 245, 212, fade));
      // A few square hot filaments give the beam material without breaking it.
      if (!reducedMotion) {
        final count = (length / 65).ceil().clamp(1, 32);
        for (var i = 0; i < count; i++) {
          final x = ((i / count + progress * .24) % 1) * length;
          canvas.drawRect(
            Rect.fromLTWH(x, (i.isEven ? -1 : 1) * width * .6, 16, 3),
            Paint()..color = Color.fromRGBO(255, 212, 143, .6 * fade),
          );
        }
      }
      canvas.drawRect(
        Rect.fromLTWH(0, -width * .35, 12, width * .7),
        Paint()..color = Color.fromRGBO(255, 238, 192, fade),
      );
    }
    canvas.restore();
  }

  static void ribbon(
    Canvas canvas,
    Offset start,
    Offset end,
    double width, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    bool spent = false,
  }) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final n = Offset(-delta.dy, delta.dx) / length;
    final count =
        (length /
                (material == AttackMaterial.chain
                    ? 16
                    : math.max(38, width * 1.4)))
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
        stamp(
          canvas,
          i.isEven ? 16 : 17,
          Offset.zero,
          warning ? 13 : 18,
          anchor: Anchor.center,
          alpha: warning ? .78 : 1,
        );
        canvas.restore();
      } else {
        if (warning) {
          groundStamp(
            canvas,
            0,
            p,
            math.max(42, width * 2),
            height: math.max(15, width * .65),
            alpha: .55 + progress * .22,
          );
          continue;
        }
        final base = row(material) * 6;
        final frame = warning
            ? 0
            : 1 + ((progress * 4).floor() + i % 2).clamp(0, 4);
        stamp(
          canvas,
          base + frame,
          p + Offset(0, width * .7),
          width * 2.1,
          height: width * (warning ? .55 : 1.1),
          alpha: spent
              ? .25
              : warning
              ? .48 + progress * .25
              : .88,
          material: material,
        );
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
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double arc, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    double innerRadius = 0,
  }) {
    final sector = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        arc,
        false,
      )
      ..close();
    final footprint = innerRadius > 0
        ? Path.combine(
            PathOperation.difference,
            sector,
            Path()
              ..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
          )
        : sector;
    canvas.save();
    canvas.clipPath(footprint);
    // Sparse low scuffs leave the arena visible through the committed sector.
    for (double r = math.max(45, innerRadius); r <= radius; r += 75) {
      final count = math.max(1, (arc.abs() * r / 90).ceil());
      for (var i = 0; i <= count; i++) {
        final a = angle + arc * i / count;
        final point = center + Offset(math.cos(a), math.sin(a)) * r;
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(a);
        groundStamp(
          canvas,
          0,
          Offset.zero,
          38,
          height: 11,
          alpha: warning ? .38 + progress * .18 : .65,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  static void wave(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double arc, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    double width = 18,
  }) {
    final count = (radius * arc.abs() / math.max(28, width * 1.5)).ceil().clamp(
      3,
      140,
    );
    final base = row(material) * 6;
    final clip = canvas.getLocalClipBounds().inflate(math.max(70, width * 4));
    for (var i = 0; i <= count; i++) {
      final a = angle + arc * i / count;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      if (!clip.contains(p)) continue;
      if (warning) {
        groundStamp(canvas, 0, p, 32, height: 14, alpha: .66 + progress * .16);
        continue;
      }
      stamp(
        canvas,
        base + (warning ? 0 : 1 + i % 3),
        p + Offset(0, width * .6),
        warning ? 28 : width * 2.1,
        height: warning ? 12 : width * 1.15,
        alpha: warning ? .62 : .9,
        material: material,
      );
    }
  }

  static void armour(
    Canvas canvas,
    Offset center,
    double radius, {
    double facing = 0,
    bool full = true,
  }) {
    for (var i = 0; i < (full ? 6 : 3); i++) {
      final a = full ? i * math.pi / 3 : facing + (i - 1) * .6;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a);
      stamp(
        canvas,
        12,
        Offset.zero,
        27,
        height: 32,
        anchor: Anchor.center,
        material: AttackMaterial.chain,
        alpha: .88,
      );
      canvas.restore();
    }
  }

  /// Companion support stays below the primary weapon's electrical accents.
  /// No pale core, forks or endpoint flash; fixed bends also suit Reduced Motion.
  static void companionLightning(
    Canvas canvas,
    Offset start,
    Offset end,
    double fade,
  ) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final normal = Offset(-delta.dy, delta.dx) / length;
    final count = (length / 48).ceil().clamp(2, 16);
    final points = [
      start,
      for (var i = 1; i < count; i++)
        start + delta * (i / count) + normal * (i.isEven ? -4 : 4),
      end,
    ];
    stroke(canvas, points, _dark.withValues(alpha: fade * .50), 4);
    stroke(
      canvas,
      points,
      const Color(0xff80998B).withValues(alpha: fade * .70),
      2,
    );
  }

  static void lightning(
    Canvas canvas,
    Offset start,
    Offset end,
    double fade, {
    bool heavy = false,
  }) {
    final delta = end - start, length = delta.distance;
    if (length < 1) return;
    final n = Offset(-delta.dy, delta.dx) / length;
    final count = (length / 22).ceil().clamp(3, 36);
    final points = [
      start,
      for (var i = 1; i < count; i++)
        start +
            delta * (i / count) +
            n * ((i.isEven ? -1 : 1) * (4 + (i * 17 % 13))),
      end,
    ];
    stroke(canvas, points, _dark.withValues(alpha: fade), heavy ? 11 : 8);
    stroke(
      canvas,
      points,
      const Color(0xff79AAA8).withValues(alpha: fade),
      heavy ? 7 : 5,
    );
    stroke(canvas, points, const Color(0xffE0E8CF).withValues(alpha: fade), 3);
    for (var i = 2; i < points.length; i += 4) {
      stroke(
        canvas,
        [points[i], points[i] + n * 16 + const Offset(8, 0)],
        const Color(0xffA8D5BC).withValues(alpha: fade),
        3,
      );
    }
    for (final p in [start, end]) {
      chip(
        canvas,
        p,
        heavy ? 9 : 6,
        const Color(0xffE7E9D5).withValues(alpha: fade),
      );
    }
  }
}
