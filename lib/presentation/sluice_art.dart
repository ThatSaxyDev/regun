import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';

import 'package:regun/presentation/regun_art.dart';

/// Grounded water for the idle channel and the committed hazard. Combat uses
/// the authored hazard radius, independently of texture motion.
class SluiceArt {
  static const drainDuration = .95;
  static ImageShader _water(Rect area, double travel) {
    final texture = RegunArt.shared.image('arenas/sluice_water');
    return ImageShader(
      texture,
      TileMode.mirror,
      TileMode.mirror,
      Float64List(16)
        ..[0] = 310 / texture.width
        ..[5] = 310 / texture.height
        ..[10] = 1
        ..[12] = area.left
        ..[13] = area.top + travel
        ..[15] = 1,
    );
  }

  static void channel(Canvas canvas, Rect bed, {required double flowTime}) {
    canvas.drawRect(
      bed,
      Paint()
        ..shader = _water(bed, 0)
        ..filterQuality = FilterQuality.none
        ..colorFilter = const ColorFilter.mode(
          Color(0xff84918a),
          BlendMode.modulate,
        ),
    );
    canvas.drawRect(
      bed,
      Paint()
        ..shader = _water(bed, flowTime * 20)
        ..filterQuality = FilterQuality.none
        ..color = const Color(0x70ffffff),
    );
  }

  static void machineFlow(
    Canvas canvas,
    Rect bed, {
    required bool warning,
    required double progress,
    required double strength,
    required bool reducedMotion,
  }) {
    final flow = reducedMotion ? 0.0 : progress * (warning ? 45 : 700);
    final opacity = (warning ? .28 + .20 * progress : .83) * strength;
    final material = Paint()
      ..shader = _water(bed, flow)
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..colorFilter = ColorFilter.mode(
        warning ? const Color(0xffa6b7a5) : const Color(0xffd3e3d5),
        BlendMode.modulate,
      );
    canvas.drawRect(bed, material);
    canvas.save();
    canvas.clipRect(bed);
    final foam = Paint()..isAntiAlias = false;
    for (var row = 0; row < (bed.height / 87).ceil() + 1; row++) {
      final y = bed.top + (row * 87 + flow) % bed.height;
      for (var i = 0; i < 6; i++) {
        final x = bed.left + 11 + (row * 23 + i * 41) % (bed.width - 22);
        foam.color = const Color(0xffb6d9ca)
            .withValues(alpha: opacity * (.20 + .11 * (i % 3)));
        canvas.drawRect(
          Rect.fromLTWH(x, y + i % 3 * 4, 7 + i % 4 * 4, 3),
          foam,
        );
      }
    }
    canvas.restore();
  }

  static void surge(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool warning,
    required double progress,
    required bool reducedMotion,
    double drain = 0,
  }) {
    final opacity = 1 - drain;
    final spread = reducedMotion ? radius : radius * (1 - drain * .24);
    final bed = Rect.fromCircle(center: center, radius: spread);
    final travel = reducedMotion ? 0.0 : progress * 285;
    canvas.saveLayer(
      bed,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.drawRect(
      bed,
      Paint()
        ..shader = _water(bed, travel)
        ..filterQuality = FilterQuality.none,
    );
    // Diffuse spill, with the highest contrast inside the danger area.
    canvas.drawRect(
      bed,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = Gradient.radial(
          center,
          spread,
          warning
              ? const [Color(0xa0808080), Color(0x89808080), Color(0x00808080)]
              : const [Color(0xff808080), Color(0xed808080), Color(0x00808080)],
          const [0, .88, 1],
        ),
    );
    canvas.restore();

    if (warning) {
      // Two fixed lamps on the gate piers indicate pressure building.
      for (final side in [-1.0, 1.0]) {
        final lamp = center.translate(side * 128, -radius - 13);
        canvas.drawRect(
          Rect.fromCenter(center: lamp, width: 22, height: 12),
          Paint()..color = const Color(0x8aa86734),
        );
        canvas.drawRect(
          Rect.fromCenter(center: lamp, width: 10, height: 5),
          Paint()..color = const Color(0xffe5ad65),
        );
      }
    }

    // Irregular foam marks retain the outer extent in both motion modes.
    final foam = Paint()
      ..isAntiAlias = false
      ..color = (warning ? const Color(0xff92c2ac) : const Color(0xffb2d6c0))
          .withValues(alpha: opacity * (warning ? .67 : .83));
    for (var i = 0; i < 25; i++) {
      final angle = i * math.pi * 2 / 25 + (i % 4) * .021;
      final x = center.dx + math.cos(angle) * (spread - 5 - i % 3);
      final y = center.dy + math.sin(angle) * (spread - 5 - i % 3);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 13 + i % 9, height: 4),
        foam,
      );
    }
  }
}
