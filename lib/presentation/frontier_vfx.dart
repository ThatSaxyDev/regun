import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';

/// Bounded authored pixel geometry: tangible rockets, electrical core and cutter
/// links. No particle components, extra textures, bloom or camera movement.
class FrontierVfx {
  static void rocket(
    Canvas canvas,
    Offset at,
    Offset direction,
    double age,
    bool reduced,
    double motor,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    final ink = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(-10, -4, 15, 8),
      ink..color = const Color(0xff343C38),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-7, -3, 11, 5),
      ink..color = const Color(0xffC6C5A5),
    );
    canvas.drawRect(
      const Rect.fromLTWH(4, -2, 4, 4),
      ink..color = const Color(0xffA47454),
    );
    for (final y in [-6.0, 3.0]) {
      canvas.drawRect(
        Rect.fromLTWH(-11, y, 6, 3),
        ink..color = const Color(0xff788276),
      );
    }
    final tail = reduced
        ? 7.0
        : 6 + 18 * motor.clamp(0.0, 1.0) + (age * 36).floor() % 2 * 2.0;
    canvas.drawRect(
      Rect.fromLTWH(-10 - tail, -2, tail, 4),
      ink..color = const Color(0xffB77749),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-15, -1, 5, 2),
      ink..color = const Color(0xffF1D7A1),
    );
    canvas.restore();
  }

  static void orb(Canvas canvas, Offset at, double age, bool reduced) {
    final ink = Paint();
    // Overlapping stepped plates create an irregular compact plasma core.
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + (reduced ? 0 : (age * 8).floor() * .16);
      final offset = Offset(math.cos(angle), math.sin(angle)) * 13;
      canvas.drawRect(
        Rect.fromCenter(center: at + offset, width: 10, height: 9),
        ink..color = const Color(0xff426B66),
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: at, width: 23, height: 16),
      ink..color = const Color(0xff8FBFB1),
    );
    canvas.drawRect(
      Rect.fromCenter(center: at, width: 15, height: 24),
      ink..color = const Color(0xffA8D4C5),
    );
    canvas.drawRect(
      Rect.fromCenter(center: at + const Offset(-2, -1), width: 9, height: 11),
      ink..color = const Color(0xffE4EEE0),
    );
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + (reduced ? .3 : (age * 9).floor() * .31);
      final p = at + Offset(math.cos(a), math.sin(a)) * 23;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 5, height: 3),
        ink..color = const Color(0xffA8D4C5),
      );
    }
  }

  static void ring(
    Canvas canvas,
    Image image,
    Offset center,
    double radius,
    double thickness,
    double age,
    bool returning,
    bool reduced,
    bool Function(Offset) clear,
  ) {
    if (radius < 3) return;
    // One textured annulus mesh. Source alpha supplies the actual chipped teeth;
    // radial mapping keeps the configured cutting width independent of reach.
    final positions = <Offset>[], uv = <Offset>[];
    const segments = 96;
    final phase = reduced
        ? 0.0
        : (age * 24).floor() * (returning ? -.045 : .045);
    final band = math.min(thickness, radius * .45);
    final inner = math.max(0.0, radius - band / 2 - 2);
    final outer = radius + band / 2 + 4;
    Offset radial(double a, double r) => Offset(math.cos(a), math.sin(a)) * r;
    void vertex(double a, bool outside) {
      positions.add(center + radial(a, outside ? outer : inner));
      uv.add(
        Offset(image.width / 2, image.height / 2) +
            radial(a - phase, image.width * (outside ? .495 : .25)),
      );
    }

    for (var i = 0; i < segments; i++) {
      final a = i * math.pi * 2 / segments,
          b = (i + 1) * math.pi * 2 / segments;
      if (!clear(radial((a + b) / 2, 1))) continue;
      vertex(a, false);
      vertex(a, true);
      vertex(b, true);
      vertex(a, false);
      vertex(b, true);
      vertex(b, false);
    }
    if (positions.isEmpty) return;
    final shader = ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: FilterQuality.none,
    );
    final mesh = Vertices(
      VertexMode.triangles,
      positions,
      textureCoordinates: uv,
    );
    canvas.drawVertices(
      mesh,
      BlendMode.srcOver,
      Paint()
        ..shader = shader
        ..filterQuality = FilterQuality.none,
    );
    mesh.dispose();
    shader.dispose();
  }
}
