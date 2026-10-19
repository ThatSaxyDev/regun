import 'package:flutter/material.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';

Color? survivorTint(String style) => switch (style) {
      'copper' => const Color(0xffE9BD92),
      'moss' => const Color(0xffCAD8A3),
      'ivory' => const Color(0xffFFF4DC),
      'shadowPalette' => const Color(0xffD7B8EA),
      'emberPalette' => const Color(0xffF2B58C),
      'engineer' => const Color(0xffF2D28D),
      _ => null,
    };

class SurvivorPortrait extends StatelessWidget {
  const SurvivorPortrait(
      {super.key,
      this.character = CharacterType.rook,
      this.style = 'standard'});
  final CharacterType character;
  final String style;
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: RegunArt.shared.load(),
      builder: (context, state) => state.connectionState == ConnectionState.done
          ? CustomPaint(painter: _Portrait(character, style))
          : const SizedBox.shrink());
}

class _Portrait extends CustomPainter {
  const _Portrait(this.character, this.style);
  final CharacterType character;
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.height.clamp(0.0, 110.0);
    canvas.save();
    canvas.translate((size.width - edge) / 2, 0);
    final paint = Paint()..filterQuality = FilterQuality.none;
    final tint = survivorTint(style);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    RegunArt.shared
        .sprite('characters/${character.name}', 1 * 8)
        .render(canvas, size: Vector2(edge, edge), overridePaint: paint);
    const brass = Color(0xffD5BA75);
    if (style == 'queenTrophy') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
            Rect.fromLTWH(edge * .38 + i * edge * .08,
                edge * .06 - (i == 1 ? 3 : 0), edge * .06, edge * .08),
            Paint()..color = brass);
      }
    }
    if (['veteran', 'scorpionCharm', 'eliteHunter', 'survivor']
        .contains(style)) {
      canvas.drawRect(
          Rect.fromLTWH(edge * .4, edge * .52, edge * .07, edge * .08),
          Paint()
            ..color = style == 'survivor' ? const Color(0xffAABDE0) : brass);
    }
    if (style == 'endless') {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
            Rect.fromLTWH(edge * .15 + i * edge * .06, edge * .86, edge * .035,
                edge * .02),
            Paint()..color = brass.withValues(alpha: (i + 1) / 5));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Portrait old) =>
      old.character != character || old.style != style;
}
