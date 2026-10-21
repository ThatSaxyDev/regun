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
                child: CustomPaint(
                  painter: _ShelterAtmosphere(_clock, widget.reducedMotion),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ShelterAtmosphere extends CustomPainter {
  _ShelterAtmosphere(this.clock, this.reducedMotion) : super(repaint: clock);
  final bool reducedMotion;
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
    // Keep the ruined surroundings underexposed. Preserve the lamp's warm
    // working area instead of laying a uniform dark wash over the painting.
    const shelter = Rect.fromLTWH(0, 0, 1536, 1024);
    canvas.drawRect(
      shelter,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.28, -.08),
          radius: .8,
          stops: [0, .38, 1],
          colors: [Color(0x14080910), Color(0x38080910), Color(0x85080910)],
        ).createShader(shelter),
    );
    // Long, uneven brownouts with a staggered recovery, rather than a
    // periodic breathing glow. All reflected light shares the same voltage.
    final intensity = reducedMotion ? .85 : ShelterVoltage.at(clock.value * 24);
    final shade = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -.12),
        radius: .78,
        colors: [
          const Color(0xff100f16).withValues(alpha: (1 - intensity) * .84),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(630, 120, 850, 810));
    canvas.drawRect(const Rect.fromLTWH(630, 120, 850, 810), shade);
    final light = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffffbc69).withValues(alpha: .015 + intensity * .18),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(770, 220, 410, 430));
    canvas.drawRect(const Rect.fromLTWH(770, 220, 410, 430), light);
    // Feather into the painted bulb: an opaque polygon here reads as a
    // gray card when power falls. Leave the original pixel texture visible.
    canvas.save();
    canvas.translate(937, 354);
    canvas.rotate(-.28);
    canvas.scale(1, .36);
    const bulb = Rect.fromLTWH(-62, -62, 124, 124);
    canvas.drawCircle(
      Offset.zero,
      62,
      Paint()
        ..shader = RadialGradient(
          stops: const [0, .45, 1],
          colors: [
            const Color(0xff09080c).withValues(alpha: (1 - intensity) * .9),
            const Color(0xff09080c).withValues(alpha: (1 - intensity) * .7),
            Colors.transparent,
          ],
        ).createShader(bulb),
    );
    canvas.restore();
    final random = math.Random(91);
    for (var i = 0; i < 54; i++) {
      final progress = (random.nextDouble() + clock.value) % 1;
      final x = 320 + random.nextDouble() * 1130 + math.sin(t + i) * 14;
      final y = 910 - progress * 760;
      canvas.drawRect(
        Rect.fromLTWH(x, y, i % 5 == 0 ? 3 : 2, 2),
        paint
          ..color = const Color(0xffe1bf87).withValues(
            alpha:
                math.sin(progress * math.pi) *
                (x > 760 && x < 1120 ? .38 : .20),
          ),
      );
    }
    // A few falling hot flecks from the damaged cable at the upper right.
    // Short, separated events, never a shower across the survivor or controls.
    if (!reducedMotion) {
      for (final start in const [
        .9,
        3.1,
        5.8,
        8.5,
        11.2,
        14.6,
        17.3,
        20.4,
        23.1,
      ]) {
        final age = (clock.value * 24 - start) % 24;
        if (age > .7) continue;
        for (var j = 0; j < 3; j++) {
          final life = (age - j * .075) / .5;
          if (life < 0 || life > 1) continue;
          final x = 1390 + (j - 1) * life * 24;
          final y = 270 + life * 32 + life * life * 48;
          canvas.drawRect(
            Rect.fromLTWH(x, y, 2, 3),
            paint
              ..color = const Color(0xffffcb83)
                  .withValues(alpha: (1 - life) * .72),
          );
        }
      }
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
      oldDelegate.clock != clock || oldDelegate.reducedMotion != reducedMotion;
}

/// Voltage envelopes are continuous at the loop boundary and between holds.
/// Dips last long enough to read as failing power rather than rapid flashing.
class ShelterVoltage {
  static const _knots = <(double, double)>[
    (0, .88),
    (.22, .9),
    (.40, .14),
    (.68, .12),
    (.86, .58),
    (1.08, .36),
    (1.4, .94),
    (2.0, .91),
    (2.22, .49),
    (2.46, .72),
    (2.7, .58),
    (3.0, .93),
    (3.5, .91),
    (3.75, .22),
    (3.98, .25),
    (4.2, .55),
    (4.8, .63),
    (5.15, .92),
    (6.0, .91),
    (6.24, .4),
    (6.5, .68),
    (6.82, .92),
    (8.1, .86),
    (8.3, .09),
    (8.78, .08),
    (9.05, .42),
    (9.32, .26),
    (9.7, .96),
    (10.8, .91),
    (11.05, .35),
    (11.35, .55),
    (11.65, .92),
    (13.4, .89),
    (13.75, .48),
    (14.5, .7),
    (15.0, .93),
    (16.1, .91),
    (16.34, .3),
    (16.68, .65),
    (16.95, .93),
    (18.0, .89),
    (18.25, .47),
    (18.55, .91),
    (19.1, .88),
    (19.36, .18),
    (19.7, .13),
    (20.05, .65),
    (20.4, .46),
    (20.85, .92),
    (21.8, .91),
    (22.05, .38),
    (22.35, .6),
    (22.7, .93),
    (24, .88),
  ];

  static double at(double seconds) {
    final time = seconds % 24;
    for (var i = 1; i < _knots.length; i++) {
      final (end, high) = _knots[i];
      if (time > end) continue;
      final (start, low) = _knots[i - 1];
      final u = (time - start) / (end - start);
      final eased = u * u * (3 - 2 * u);
      return low + (high - low) * eased;
    }
    return .88;
  }
}
