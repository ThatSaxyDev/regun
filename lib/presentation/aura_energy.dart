import 'dart:math' as math;
import 'dart:ui';

/// Etched sixfold seal and stepped induction currents. All animation uses the
/// field's simulation clock; no extra images, particles, timers or damage areas.
class AuraEnergy {
  static Offset point(double angle, double radius) =>
      Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  static Offset pixel(Offset p) =>
      Offset((p.dx / 2).round() * 2.0, (p.dy / 2).round() * 2.0);
  static void segment(Path path, Offset a, Offset b) {
    a = pixel(a);
    b = pixel(b);
    path.moveTo(a.dx, a.dy);
    path.lineTo(b.dx, b.dy);
  }

  static void paint(
    Canvas canvas,
    double radius,
    double time,
    double alpha, {
    required bool reducedMotion,
  }) {
    final seal = Path(), currents = Path(), tips = <Offset>[];
    final phase = reducedMotion ? 0 : (time * 10).floor();
    // Interlaced, chipped triangles leave the survivor's central footprint clear.
    for (var i = 0; i < 6; i++) {
      final a = point(i * math.pi / 3 - math.pi / 2, radius * .60);
      final b = point((i + 2) * math.pi / 3 - math.pi / 2, radius * .60);
      segment(seal, a + (b - a) * .08, a + (b - a) * .44);
      segment(seal, a + (b - a) * .52, a + (b - a) * .92);
      // Individual three-stroke sigils, rather than a continuous bright outline.
      final heading = i * math.pi / 3;
      final center = point(heading, radius * .81);
      final radial = point(heading, 1),
          tangent = point(heading + math.pi / 2, 1);
      segment(seal, center - radial * 7, center + radial * 7);
      segment(seal, center - tangent * 5 - radial * 3, center + radial * 3);
      segment(seal, center + radial * 3, center + tangent * 5 + radial * 6);
    }
    // Three restrained crackles advance through the seal at ten stepped poses/s.
    for (var ray = 0; ray < 3; ray++) {
      final sector = (phase ~/ 3 + ray * 2) % 6;
      final heading = sector * math.pi / 3 + .22;
      final progress = reducedMotion ? .6 : ((phase + ray * 3) % 9) / 9;
      final start = radius * (.29 + progress * .16);
      var previous = point(heading, start);
      for (var j = 1; j <= 6; j++) {
        final wobble = (((phase * 13 + ray * 7 + j * 11) % 7) - 3) * .025;
        final next = point(heading + wobble, start + j * radius * .065);
        segment(currents, previous, next);
        previous = next;
      }
      tips.add(pixel(previous));
    }
    void stroke(Path path, Color color, double width, double opacity) {
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..strokeWidth = width
          ..color = color.withValues(alpha: alpha * opacity),
      );
    }

    stroke(seal, const Color(0xff111F19), 6, .60);
    stroke(seal, const Color(0xff7B9D81), 2, .36);
    stroke(currents, const Color(0xff172B21), 7, .72);
    stroke(currents, const Color(0xff719B75), 4, reducedMotion ? .32 : .62);
    stroke(currents, const Color(0xffD1DAB0), 2, reducedMotion ? .26 : .76);
    for (var i = 0; i < tips.length; i++) {
      final p = tips[i];
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 7, height: 7),
        Paint()..color = const Color(0xff63886A).withValues(alpha: alpha * .35),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 3, height: 3),
        Paint()
          ..color = const Color(0xffE0DDB3)
              .withValues(alpha: alpha * (reducedMotion ? .35 : .8)),
      );
      if (!reducedMotion) {
        final chip = p + point(i * 2.1 + phase * .31, 5 + (phase % 4) * 2.0);
        canvas.drawRect(
          Rect.fromCenter(center: pixel(chip), width: 2, height: 2),
          Paint()
            ..color = const Color(0xffB2C499).withValues(alpha: alpha * .58),
        );
      }
    }
  }
}
