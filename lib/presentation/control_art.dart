import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

/// One authored skin used by both Flame components and online widget controls.
class ControlArt {
  static void stickRing(Canvas canvas, double radius, double opacity) {
    final center = Offset(radius, radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Color.fromRGBO(35, 29, 40, .15 * opacity),
    );
    final line = Paint()
      ..color = Color.fromRGBO(126, 114, 123, .4 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, line);
    canvas.drawCircle(
      center,
      radius - 10,
      line..color = const Color(0x187E727B),
    );
    final tick = Paint()
      ..color = const Color(0x808E827F)
      ..strokeWidth = 3;
    for (final direction in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ]) {
      canvas.drawLine(
        center + direction * (radius - 6),
        center + direction * (radius - 16),
        tick,
      );
    }
  }

  static Color _tone(int value, double opacity) {
    final color = Color(value);
    return color.withValues(alpha: color.a * opacity);
  }

  static void stickKnob(Canvas canvas, Size size, double opacity) {
    Color tone(int v) => _tone(v, opacity);
    final rect = Offset.zero & size;
    canvas.drawPath(controlPlate(rect), Paint()..color = tone(0xC82B252F));
    canvas.drawPath(
      controlPlate(rect.deflate(1)),
      Paint()
        ..color = tone(0xA0B1A18E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      controlPlate(rect.deflate(7), cut: 3),
      Paint()
        ..color = tone(0x405E515D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromCenter(center: rect.center, width: 4, height: 4),
      Paint()..color = tone(0xffB6A893),
    );
  }

  /// Coordinates match the original 112-unit Flame action component exactly.
  static void action(
    Canvas canvas, {
    required PixelGlyph glyph,
    required String label,
    required double opacity,
    bool active = false,
    double cooldown = 0,
  }) {
    Color tone(int v) => _tone(v, opacity);
    final ink = active ? tone(0xffF1C77C) : tone(0xffD6CAB9);
    final rect = Rect.fromLTWH(12, active ? 5 : 2, 88, 84);
    canvas.drawPath(
      controlPlate(rect.shift(const Offset(0, 3))),
      Paint()..color = tone(0x99130F18),
    );
    canvas.drawPath(
      controlPlate(rect),
      Paint()..color = active ? tone(0xE346342C) : tone(0xB9221D27),
    );
    canvas.drawPath(
      controlPlate(rect.deflate(1)),
      Paint()
        ..color = active ? ink : tone(0x99796D73)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    paintPixelGlyph(
      canvas,
      Rect.fromLTWH(36, active ? 27 : 24, 40, 40),
      glyph,
      ink,
    );
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: FontFam.pressStart,
          fontSize: 17,
          height: 1,
          color: ink,
        ),
      ),
    )..layout();
    text.paint(canvas, Offset((112 - text.width) / 2, 96));
    if (glyph == PixelGlyph.dash && cooldown > 0) {
      canvas.drawRect(
        Rect.fromLTWH(18, 81, 76 * (1 - cooldown.clamp(0, 1)), 4),
        Paint()..color = tone(0xffE1BA78),
      );
    }
  }
}

class OnlineStickSkin extends CustomPainter {
  const OnlineStickSkin({required this.delta, required this.opacity});
  final Offset delta;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180);
    ControlArt.stickRing(canvas, 90, opacity);
    // Flame JoystickComponent has 90 - 32 = 58 units of knob travel.
    canvas.translate(58 + delta.dx * 58, 58 + delta.dy * 58);
    ControlArt.stickKnob(canvas, const Size.square(64), opacity);
    canvas.restore();
  }

  @override
  bool shouldRepaint(OnlineStickSkin old) =>
      delta != old.delta || opacity != old.opacity;
}

class OnlineActionSkin extends CustomPainter {
  const OnlineActionSkin({
    required this.glyph,
    required this.label,
    required this.opacity,
    this.active = false,
    this.cooldown = 0,
  });
  final PixelGlyph glyph;
  final String label;
  final double opacity, cooldown;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 112);
    ControlArt.action(
      canvas,
      glyph: glyph,
      label: label,
      opacity: opacity,
      active: active,
      cooldown: cooldown,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(OnlineActionSkin old) =>
      glyph != old.glyph ||
      label != old.label ||
      opacity != old.opacity ||
      active != old.active ||
      cooldown != old.cooldown;
}
