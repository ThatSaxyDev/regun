import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

class ActionControlSkin extends PositionComponent
    with HasGameReference<RegunGame> {
  ActionControlSkin(
      {required this.glyph, required this.label, this.pressed = false})
      : super(size: Vector2.all(112));

  final PixelGlyph glyph;
  final String label;
  final bool pressed;

  @override
  void render(Canvas canvas) {
    Color tone(int value) {
      final c = Color(value);
      return c.withValues(alpha: c.a * game.controls.opacity);
    }

    final active = pressed ||
        (glyph == PixelGlyph.reload
            ? game.gameState.reloading
            : game.boostButtonComponent.tapped);
    final ink = active ? tone(0xffF1C77C) : tone(0xffD6CAB9);
    final rect = Rect.fromLTWH(12, active ? 5 : 2, 88, 84);
    canvas.drawPath(controlPlate(rect.shift(const Offset(0, 3))),
        Paint()..color = tone(0x99130F18));
    canvas.drawPath(controlPlate(rect),
        Paint()..color = active ? tone(0xE346342C) : tone(0xB9221D27));
    canvas.drawPath(
        controlPlate(rect.deflate(1)),
        Paint()
          ..color = active ? ink : tone(0x99796D73)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    paintPixelGlyph(
        canvas, Rect.fromLTWH(36, active ? 27 : 24, 40, 40), glyph, ink);
    final text = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: 17,
              height: 1,
              color: ink),
        ))
      ..layout();
    text.paint(canvas, Offset((size.x - text.width) / 2, 96));
    if (glyph == PixelGlyph.dash &&
        game.boostButtonComponent.cooldownFraction > 0) {
      canvas.drawRect(
          Rect.fromLTWH(
              18, 81, 76 * (1 - game.boostButtonComponent.cooldownFraction), 4),
          Paint()..color = tone(0xffE1BA78));
    }
  }
}
