import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/attack_vfx.dart';

/// Layered existing pixel materials. These are short, bounded local cues, not
/// gameplay geometry, particle entities, bloom or a camera effect.
class EndgameVfx {
  static void contact(
    Canvas canvas,
    WeaponType weapon,
    Offset direction,
    double progress,
    ColorFilter grade,
    bool reducedMotion,
  ) {
    final t = progress.clamp(0.0, 1.0), fade = 1 - t;
    final size = weapon == WeaponType.cycloneBreacher
        ? 72.0
        : weapon == WeaponType.flakRegent
        ? 64.0
        : 52.0;
    canvas.save();
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    AttackVfx.groundMaterial(
      canvas,
      2,
      const Offset(10, -2),
      size,
      height: size * .55,
      alpha: fade * .85,
      ambient: grade,
    );
    for (final side in [-1, 1]) {
      final reach = reducedMotion ? 16.0 : 9 + t * 24;
      AttackVfx.floorArea(
        canvas,
        6,
        Offset(reach, side * reach * .45),
        20,
        alpha: fade * .8,
        ambient: grade,
      );
    }
    canvas.restore();
  }

  static void crossburst(
    Canvas canvas,
    Offset direction,
    double progress,
    ColorFilter grade,
    bool reducedMotion,
  ) {
    final t = progress.clamp(0.0, 1.0), fade = 1 - t;
    canvas.save();
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    AttackVfx.groundMaterial(
      canvas,
      0,
      Offset.zero,
      110,
      height: 65,
      alpha: fade * .9,
      ambient: grade,
    );
    for (final side in [-1, 1]) {
      for (var i = 0; i < 5; i++) {
        final d = reducedMotion
            ? 35 + i * 27.0
            : 15 + (i * 30 + 160 * t).clamp(0.0, 215.0);
        AttackVfx.floorArea(
          canvas,
          6,
          Offset(d, side * d * .24),
          28 - i * 2.0,
          alpha: fade * .82,
          ambient: grade,
        );
      }
    }
    canvas.restore();
  }

  static void pressure(
    Canvas canvas,
    Offset origin,
    Offset direction,
    double range,
    double progress,
    ColorFilter grade,
    bool reducedMotion,
    bool Function(Offset, Offset) clear, {
    bool echo = false,
    double coneDegrees = 35,
  }) {
    final p = progress.clamp(0.0, 1.0);
    if (p >= 1) return;
    final fade = math.pow(1 - p, .65).toDouble();
    // The delayed echo is a settling resonance of the first compression front,
    // rather than another projectile starting at the muzzle.
    final reach =
        range *
        (reducedMotion
            ? .82
            : echo
            ? .68 + .28 * p
            : .16 + .80 * (1 - math.pow(1 - p, 2)));
    final angle = math.atan2(direction.dy, direction.dx);
    final halfAngle = coneDegrees * math.pi / 180;
    final count = (reach * halfAngle * 2 / 5).ceil().clamp(12, 110);
    Offset point(double a, double radius) {
      final raw = origin + Offset(math.cos(a), math.sin(a)) * radius;
      return Offset((raw.dx / 3).round() * 3, (raw.dy / 3).round() * 3);
    }

    canvas.save();
    final sector = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(
        Rect.fromCircle(center: origin, radius: range),
        angle - halfAngle,
        halfAngle * 2,
        false,
      )
      ..close();
    canvas.clipPath(sector);
    // Adjacent stepped facets form a solid crescent. No confetti, radial
    // arrow tails or isolated white sparks compete with the wave silhouette.
    for (var band = 0; band < 2; band++) {
      final radius = reach - band * 18;
      if (radius < 10) continue;
      final strength = fade * (echo ? .55 : .82) * (band == 0 ? 1 : .22);
      final width = band == 0 ? (echo ? 7.0 : 11.0) : 5.0;
      for (var i = 0; i < count; i++) {
        final a = angle - halfAngle + i / count * halfAngle * 2;
        final b = angle - halfAngle + (i + 1) / count * halfAngle * 2;
        final middle =
            origin +
            Offset(math.cos((a + b) / 2), math.sin((a + b) / 2)) * radius;
        if (!clear(origin, middle)) continue;
        void facet(double outer, double inner, Color color) {
          final shape = Path()
            ..addPolygon([
              point(a, outer),
              point(b, outer),
              point(b, inner),
              point(a, inner),
            ], true);
          canvas.drawPath(shape, Paint()..color = color);
        }

        facet(
          radius + 4,
          radius - width - 4,
          Color.fromRGBO(24, 30, 26, strength * .8),
        );
        facet(radius, radius - width, Color.fromRGBO(191, 169, 122, strength));
        facet(
          radius - 2,
          radius - 5,
          Color.fromRGBO(226, 207, 162, strength * .72),
        );
      }
    }
    canvas.restore();
  }

  static void fracture(
    Canvas canvas,
    Offset from,
    Offset to,
    double progress,
    ColorFilter grade,
    bool reducedMotion, {double radius = 42}
  ) {
    final delta = to - from,
        length = delta.distance,
        p = progress.clamp(0.0, 1.0);
    if (length < 1 || p >= 1) return;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(math.atan2(delta.dy, delta.dx));
    canvas.clipRect(Rect.fromLTRB(-1, -radius, length + 1, radius));
    for (var i = 0; i < 5; i++) {
      final x = length * (i + .5) / 5;
      final lift = reducedMotion ? 0.0 : math.sin(p * math.pi) * 12;
      AttackVfx.groundMaterial(
        canvas,
        1,
        Offset(x, 0),
        length / 4.4,
        height: 74 * radius / 42,
        alpha: (1 - p) * .8,
        ambient: grade,
      );
      AttackVfx.groundMaterial(
        canvas,
        0,
        Offset(x, -lift),
        length / 4.0,
        height: 66 * radius / 42,
        alpha: (1 - p) * .86,
        ambient: grade,
      );
    }
    canvas.restore();
  }
}
