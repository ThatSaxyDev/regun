import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';

/// A continuous stepped rim makes the focused control easy to identify.
void paintMenuFocus(Canvas canvas, Rect plate) {
  canvas.drawPath(
    controlPlate(plate.deflate(2), cut: 5),
    Paint()
      ..color = const Color(0xfff4dfaf)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = false,
  );
}

class MenuFocusPainter extends CustomPainter {
  const MenuFocusPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      paintMenuFocus(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(MenuFocusPainter oldDelegate) => false;
}
