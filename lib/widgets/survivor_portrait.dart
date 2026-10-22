import 'dart:math' as math;

import 'package:regun/services/local_preferences.dart';
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

class SurvivorPortrait extends StatefulWidget {
  const SurvivorPortrait({
    super.key,
    this.character = CharacterType.rook,
    this.style = 'standard',
    this.maxArtSize = 110,
    this.animated = false,
  });
  final CharacterType character;
  final String style;
  final double maxArtSize;
  final bool animated;
  @override
  State<SurvivorPortrait> createState() => _SurvivorPortraitState();
}

class _SurvivorPortraitState extends State<SurvivorPortrait>
    with SingleTickerProviderStateMixin {
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool get still =>
      !widget.animated ||
      LocalPreferences.shared.reducedMotion ||
      MediaQuery.disableAnimationsOf(context);
  void sync() {
    if (still) {
      clock.stop();
      clock.value = 0;
    } else if (!clock.isAnimating) {
      clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(SurvivorPortrait old) {
    super.didUpdateWidget(old);
    sync();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget portrait() => CustomPaint(
      painter: _Portrait(
        widget.character,
        widget.style,
        widget.maxArtSize,
        clock,
        still,
      ),
    );
    if (RegunArt.shared.contains('characters/${widget.character.name}')) {
      return portrait();
    }
    return FutureBuilder<void>(
      future: RegunArt.shared.load(),
      builder: (context, state) => state.connectionState == ConnectionState.done
          ? portrait()
          : const SizedBox.shrink(),
    );
  }
}

class _Portrait extends CustomPainter {
  _Portrait(this.character, this.style, this.maxArtSize, this.clock, this.still)
    : super(repaint: clock);
  final Animation<double> clock;
  final bool still;
  final CharacterType character;
  final String style;
  final double maxArtSize;
  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide.clamp(0.0, maxArtSize);
    canvas.save();
    canvas.translate((size.width - edge) / 2, (size.height - edge) / 2);
    if (!still) {
      canvas.translate(0, -(1 - math.cos(clock.value * math.pi * 2)) * 1.5);
    }
    final paint = Paint()..filterQuality = FilterQuality.none;
    final tint = survivorTint(style);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    RegunArt.shared
        .sprite(
          'characters/${character.name}',
          8 + (still || clock.value < .5 ? 0 : 1),
        )
        .render(canvas, size: Vector2(edge, edge), overridePaint: paint);
    const brass = Color(0xffD5BA75);
    if (style == 'queenTrophy') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            edge * .38 + i * edge * .08,
            edge * .06 - (i == 1 ? 3 : 0),
            edge * .06,
            edge * .08,
          ),
          Paint()..color = brass,
        );
      }
    }
    if ([
      'veteran',
      'scorpionCharm',
      'eliteHunter',
      'survivor',
    ].contains(style)) {
      canvas.drawRect(
        Rect.fromLTWH(edge * .4, edge * .52, edge * .07, edge * .08),
        Paint()..color = style == 'survivor' ? const Color(0xffAABDE0) : brass,
      );
    }
    if (style == 'endless') {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            edge * .15 + i * edge * .06,
            edge * .86,
            edge * .035,
            edge * .02,
          ),
          Paint()..color = brass.withValues(alpha: (i + 1) / 5),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Portrait old) =>
      old.character != character ||
      old.style != style ||
      old.maxArtSize != maxArtSize ||
      old.still != still;
}
