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
  }) {
    final p = progress.clamp(0.0, 1.0), fade = math.pow(1 - p, .65).toDouble();
    if (p >= 1) return;
    final reach =
        range * (reducedMotion ? .78 : .12 + .86 * (1 - math.pow(1 - p, 2)));
    final angle = math.atan2(direction.dy, direction.dx);
    final sector = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(
        Rect.fromCircle(center: origin, radius: range),
        angle - 35 * math.pi / 180,
        70 * math.pi / 180,
        false,
      )
      ..close();
    canvas.save();
    canvas.clipPath(sector);
    // Authored stepped pressure contour: dark edge, muted body, sparse warm
    // compression pixels. It is constructed at world-pixel scale, not a clean
    // vector ring or an atlas stretched into a circle.
    final count = (reach * 70 * math.pi / 180 / 6).ceil().clamp(12, 80);
    for (var i = 0; i <= count; i++) {
      final a = angle - 35 * math.pi / 180 + i / count * 70 * math.pi / 180;
      final d = Offset(math.cos(a), math.sin(a));
      final radius = reach + ((i * 7) % 5 - 2) * 1.5;
      final at = origin + d * radius;
      if (!clear(origin, at)) continue;
      final point = Offset((at.dx / 3).round() * 3, (at.dy / 3).round() * 3);
      canvas.drawRect(
        Rect.fromCenter(
          center: point + const Offset(0, 2),
          width: 9,
          height: 9,
        ),
        Paint()..color = Color.fromRGBO(24, 30, 26, fade * .75),
      );
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 6, height: 6),
        Paint()
          ..color = Color.fromRGBO(
            echo ? 212 : 242,
            echo ? 230 : 215,
            echo ? 218 : 163,
            fade * .95,
          ),
      );
      if (i % 4 == 0) {
        canvas.drawRect(
          Rect.fromCenter(center: point - d * 3, width: 3, height: 3),
          Paint()..color = Color.fromRGBO(255, 245, 216, fade * .95),
        );
      }
    }
    // Airborne pixel wake: short compression shards, not floor rubble or
    // persistent area paint. The bright face belongs to a weapon discharge.
    for (var i = -5; i <= 5; i++) {
      if ((i + 5) % 3 == 2) continue;
      final a = angle + i * math.pi / 30;
      final d = Offset(math.cos(a), math.sin(a));
      final desired = origin + d * reach;
      if (!clear(origin, desired)) continue;
      canvas.save();
      canvas.translate(desired.dx, desired.dy);
      canvas.rotate(a);
      final length =
          (echo ? 52.0 : 65.0) * (1 - p * .4) * (.60 + ((i + 5) * 7 % 6) * .09);
      final tail = Path()
        ..addPolygon([
          const Offset(3, -3),
          const Offset(-12, -3),
          const Offset(-12, -5),
          Offset(-length * .65, -5),
          Offset(-length * .65, -2),
          Offset(-length, -2),
          Offset(-length, 2),
          Offset(-length * .65, 2),
          Offset(-length * .65, 5),
          const Offset(-12, 5),
          const Offset(-12, 3),
          const Offset(3, 3),
        ], true);
      canvas.drawPath(
        tail,
        Paint()
          ..color = Color.fromRGBO(
            echo ? 198 : 231,
            echo ? 220 : 205,
            echo ? 211 : 150,
            fade * .46,
          ),
      );
      canvas.drawRect(
        Rect.fromLTWH(-length * .65, -1.5, length * .65, 3),
        Paint()..color = Color.fromRGBO(255, 242, 208, fade * .8),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  static void fracture(
    Canvas canvas,
    Offset from,
    Offset to,
    double progress,
    ColorFilter grade,
    bool reducedMotion,
  ) {
    final delta = to - from,
        length = delta.distance,
        p = progress.clamp(0.0, 1.0);
    if (length < 1 || p >= 1) return;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(math.atan2(delta.dy, delta.dx));
    canvas.clipRect(Rect.fromLTRB(-1, -42, length + 1, 42));
    for (var i = 0; i < 5; i++) {
      final x = length * (i + .5) / 5;
      final lift = reducedMotion ? 0.0 : math.sin(p * math.pi) * 12;
      AttackVfx.groundMaterial(
        canvas,
        1,
        Offset(x, 0),
        length / 4.4,
        height: 74,
        alpha: (1 - p) * .8,
        ambient: grade,
      );
      AttackVfx.groundMaterial(
        canvas,
        0,
        Offset(x, -lift),
        length / 4.0,
        height: 66,
        alpha: (1 - p) * .86,
        ambient: grade,
      );
    }
    canvas.restore();
  }
}
