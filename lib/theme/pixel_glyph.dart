import 'dart:ui';

enum PixelGlyph {
  play,
  menu,
  reload,
  dash,
  fire,
  bolt,
  mine,
  bounce,
  round,
  drone,
  heart,
  shield,
  magnet,
  star,
  scatter,
  crosshair,
  cross,
  shards,
  link,
  back,
  settings
}

/// Small code-native pixel symbols, shared by Flutter and Flame controls.
void paintPixelGlyph(
    Canvas canvas, Rect bounds, PixelGlyph glyph, Color color) {
  final rows = switch (glyph) {
    PixelGlyph.settings => const [
        '00011000',
        '01011010',
        '11111111',
        '01100110',
        '01100110',
        '11111111',
        '01011010',
        '00011000'
      ],
    PixelGlyph.fire => const [
        '00010000',
        '00111000',
        '00111010',
        '01111110',
        '11111111',
        '11101111',
        '01101110',
        '00111100'
      ],
    PixelGlyph.bolt => const [
        '00011100',
        '00111000',
        '01110000',
        '11111110',
        '00011100',
        '00111000',
        '01110000',
        '01000000'
      ],
    PixelGlyph.mine => const [
        '00011000',
        '10011001',
        '01111110',
        '11100111',
        '11100111',
        '01111110',
        '10011001',
        '00011000'
      ],
    PixelGlyph.bounce => const [
        '00000000',
        '00000010',
        '00111110',
        '00100010',
        '00100000',
        '11100000',
        '01100000',
        '00100000'
      ],
    PixelGlyph.round => const [
        '00111000',
        '01111100',
        '01111100',
        '01111100',
        '01111100',
        '01111100',
        '00111000',
        '01111100'
      ],
    PixelGlyph.drone => const [
        '10000001',
        '11111111',
        '00111100',
        '01100110',
        '11111111',
        '00100100',
        '01100110',
        '01000010'
      ],
    PixelGlyph.heart => const [
        '01100110',
        '11111111',
        '11111111',
        '11111111',
        '01111110',
        '00111100',
        '00011000',
        '00000000'
      ],
    PixelGlyph.shield => const [
        '11111111',
        '11000011',
        '11000011',
        '11000011',
        '01100110',
        '01100110',
        '00111100',
        '00011000'
      ],
    PixelGlyph.magnet => const [
        '11000011',
        '11000011',
        '11000011',
        '11000011',
        '11000011',
        '01100110',
        '00111100',
        '00000000'
      ],
    PixelGlyph.star => const [
        '00011000',
        '00011000',
        '01111110',
        '11111111',
        '00111100',
        '01111110',
        '01100110',
        '01000010'
      ],
    PixelGlyph.scatter => const [
        '00000110',
        '00111100',
        '11000000',
        '00111111',
        '11000000',
        '00111100',
        '00000110',
        '00000000'
      ],
    PixelGlyph.crosshair => const [
        '00011000',
        '00100100',
        '01000010',
        '10011001',
        '10011001',
        '01000010',
        '00100100',
        '00011000'
      ],
    PixelGlyph.cross => const [
        '00111100',
        '00111100',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '00111100',
        '00111100'
      ],
    PixelGlyph.shards => const [
        '10000001',
        '01011010',
        '00111100',
        '11100111',
        '11100111',
        '00111100',
        '01011010',
        '10000001'
      ],
    PixelGlyph.link => const [
        '00111000',
        '01000100',
        '01000100',
        '00111000',
        '00011100',
        '00100010',
        '00100010',
        '00011100'
      ],
    PixelGlyph.back => const [
        '00010000',
        '00110000',
        '01100000',
        '11111111',
        '11111111',
        '01100000',
        '00110000',
        '00010000'
      ],
    PixelGlyph.play => const [
        '01000000',
        '01100000',
        '01110000',
        '01111000',
        '01111100',
        '01111000',
        '01110000',
        '01100000'
      ],
    PixelGlyph.menu => const [
        '00000000',
        '11111111',
        '11111111',
        '00000000',
        '11111111',
        '11111111',
        '00000000',
        '11111111'
      ],
    PixelGlyph.reload => const [
        '00111100',
        '01100110',
        '11000011',
        '11001111',
        '11000111',
        '01100000',
        '00111110',
        '00011100'
      ],
    PixelGlyph.dash => const [
        '10010000',
        '11011000',
        '01101100',
        '00110110',
        '00110110',
        '01101100',
        '11011000',
        '10010000'
      ],
  };
  final unit = bounds.shortestSide / 8;
  final paint = Paint()
    ..color = color
    ..isAntiAlias = false;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      if (rows[y][x] == '1') {
        canvas.drawRect(
            Rect.fromLTWH(
                bounds.left + x * unit, bounds.top + y * unit, unit, unit),
            paint);
      }
    }
  }
}

Path controlPlate(Rect rect, {double cut = 6}) => Path()
  ..moveTo(rect.left + cut, rect.top)
  ..lineTo(rect.right - cut, rect.top)
  ..lineTo(rect.right, rect.top + cut)
  ..lineTo(rect.right, rect.bottom - cut)
  ..lineTo(rect.right - cut, rect.bottom)
  ..lineTo(rect.left + cut, rect.bottom)
  ..lineTo(rect.left, rect.bottom - cut)
  ..lineTo(rect.left, rect.top + cut)
  ..close();
