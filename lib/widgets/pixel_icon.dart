import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';

class PixelIcon extends StatelessWidget {
  const PixelIcon(this.glyph,
      {super.key, this.size = 24, this.color = const Color(0xffE1BA78)});
  final PixelGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Painter(glyph, color));
}

class _Painter extends CustomPainter {
  const _Painter(this.glyph, this.color);
  final PixelGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      paintPixelGlyph(canvas, Offset.zero & size, glyph, color);
  @override
  bool shouldRepaint(_Painter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}
