import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rook's shelter, with local lamp/dust/steam motion over the painted plate.
/// This menu asset never acquires the combat atlases.
class HomeArtwork extends StatefulWidget {
  const HomeArtwork({super.key, this.reducedMotion = false});
  final bool reducedMotion;
  @override
  State<HomeArtwork> createState() => _HomeArtworkState();
}

class _HomeArtworkState extends State<HomeArtwork>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) _clock.repeat();
  }

  @override
  void didUpdateWidget(HomeArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion) {
      _clock.stop();
      _clock.value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: Image.asset(
        'assets/art/arenas/home_hideout_v2.png',
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        filterQuality: FilterQuality.none,
        frameBuilder: (context, child, frame, synchronous) => Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: child),
            if (frame != null || synchronous)
              RepaintBoundary(
                child: CustomPaint(painter: _ShelterAtmosphere(_clock)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ShelterAtmosphere extends CustomPainter {
  _ShelterAtmosphere(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    // Match Image's right-aligned cover transform, including portrait cropping.
    final scale = math.max(size.width / 1536, size.height / 1024);
    canvas.save();
    canvas.translate(
      size.width - 1536 * scale,
      (size.height - 1024 * scale) / 2,
    );
    canvas.scale(scale);
    final t = clock.value * math.pi * 2;
    final paint = Paint()..isAntiAlias = false;
    // Uneven filament flutter and occasional short dips. Only the work lamp
    // and its warm pool change; the cool shelter and all UI remain steady.
    final flutter =
        .74 +
        .13 * math.sin(t * 17) +
        .08 * math.sin(t * 31 + .7) +
        .05 * math.sin(t * 53);
    final dip = math.pow(math.max(0, math.sin(t * 11 + .4)), 12) * .38;
    final intensity = (flutter - dip).clamp(.25, 1.0);
    final shade = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.18, -.35),
        radius: .9,
        colors: [
          const Color(0xff160c12).withValues(alpha: (1 - intensity) * .38),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(685, 145, 600, 650));
    canvas.drawRect(const Rect.fromLTWH(685, 145, 600, 650), shade);
    final light = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffffbc69).withValues(alpha: .03 + intensity * .09),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(805, 230, 300, 300));
    canvas.drawRect(const Rect.fromLTWH(805, 230, 300, 300), light);
    // Follow the painted underside of the slanted shade, not a floating glow.
    canvas.drawPath(
      Path()..addPolygon(const [
        Offset(901, 354),
        Offset(950, 338),
        Offset(974, 350),
        Offset(922, 370),
      ], true),
      Paint()
        ..color = const Color(0xffffdda1)
            .withValues(alpha: .08 + intensity * .43),
    );
    final random = math.Random(91);
    for (var i = 0; i < 18; i++) {
      final progress = (random.nextDouble() + clock.value) % 1;
      final x = 755 + random.nextDouble() * 370 + math.sin(t + i) * 9;
      final y = 720 - progress * 440;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 2, 2),
        paint
          ..color = const Color(0xffe1bf87)
              .withValues(alpha: math.sin(progress * math.pi) * .22),
      );
    }
    // Stepped wisps from the enamel mug; silhouettes and props stay planted.
    for (var i = 0; i < 3; i++) {
      final progress = (clock.value * 3 + i / 3) % 1;
      final x = 851 + math.sin(progress * 6 + i) * 5;
      final y = 510 - progress * 58;
      final alpha = math.sin(progress * math.pi) * .13;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 3, 8),
        paint..color = const Color(0xffd5c6b1).withValues(alpha: alpha),
      );
      canvas.drawRect(Rect.fromLTWH(x + 3, y - 5, 3, 5), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShelterAtmosphere oldDelegate) =>
      oldDelegate.clock != clock;
}
