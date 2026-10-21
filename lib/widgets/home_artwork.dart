import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A painted iron breach: static architecture is isolated from the ash ticker.
/// No textures, game loop or combat assets are loaded by the home screen.
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _BreachArchitecture()),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _BreachAtmosphere(_clock)),
          ),
        ],
      ),
    ),
  );
}

void _scene(Canvas canvas, Size size) {
  // Cover the canvas, anchored on the breach rather than stretching the iron.
  final scale = math.max(size.width / 720, size.height / 600);
  canvas.translate(size.width - 720 * scale, (size.height - 600 * scale) / 2);
  canvas.scale(scale);
}

const _ink = Color(0xff101a1c);
const _iron = Color(0xff293738);
const _brass = Color(0xffbc9361);

class _BreachArchitecture extends CustomPainter {
  const _BreachArchitecture();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scene(canvas, size);
    final paint = Paint()..isAntiAlias = true;
    void rect(double x, double y, double w, double h, Color color) =>
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    void path(List<Offset> points, Color color) =>
        canvas.drawPath(Path()..addPolygon(points, true), paint..color = color);
    rect(0, 0, 720, 600, const Color(0xff152022));
    // Receding buttresses and masonry, with a deliberately asymmetric roofline.
    for (var i = 0; i < 9; i++) {
      final x = i * 92.0 - 20;
      final top = 35.0 + (i * 47 % 95);
      rect(x, top, 78, 460, i.isEven ? _ink : const Color(0xff192629));
      rect(x + 4, top, 3, 430, const Color(0xff304044));
      for (var j = 0; j < 6; j++) {
        rect(x + 8, top + j * 67, 63, 2, const Color(0xff0e181a));
      }
    }
    path(const [
      Offset(270, 0),
      Offset(370, 0),
      Offset(219, 474),
      Offset(160, 474),
    ], const Color(0x0dabc4b3));
    // Foundation and the stair approach.
    rect(0, 474, 720, 126, const Color(0xff10191b));
    for (var i = 0; i < 6; i++) {
      final y = 458.0 + i * 22;
      final spread = i * 24.0;
      path([
        Offset(343 - spread, y),
        Offset(608 + spread, y),
        Offset(632 + spread, y + 17),
        Offset(319 - spread, y + 17),
      ], const Color(0xff253032));
      rect(319 - spread, y + 17, 313 + spread * 2, 5, const Color(0xff0b1416));
    }
    // Heavy stepped housing. Its silhouette is readable even without motion.
    path(const [
      Offset(302, 463),
      Offset(302, 191),
      Offset(333, 191),
      Offset(333, 144),
      Offset(382, 144),
      Offset(382, 116),
      Offset(550, 116),
      Offset(550, 144),
      Offset(599, 144),
      Offset(599, 191),
      Offset(630, 191),
      Offset(630, 463),
    ], const Color(0xff080f12));
    path(const [
      Offset(317, 457),
      Offset(317, 201),
      Offset(348, 201),
      Offset(348, 158),
      Offset(393, 158),
      Offset(393, 132),
      Offset(540, 132),
      Offset(540, 158),
      Offset(583, 158),
      Offset(583, 201),
      Offset(614, 201),
      Offset(614, 457),
    ], _iron);
    rect(329, 215, 8, 232, const Color(0xff425052));
    rect(595, 215, 9, 232, const Color(0xff192527));
    const center = Offset(466, 299);
    canvas.drawCircle(center, 133, paint..color = const Color(0xff0a1215));
    canvas.drawCircle(center, 125, paint..color = const Color(0xff46504c));
    canvas.drawCircle(center, 119, paint..color = const Color(0xff1c292c));
    // Twelve individually seated radial locks, aged metal rather than neon.
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 6);
      path(const [
        Offset(-13, -122),
        Offset(12, -122),
        Offset(17, -97),
        Offset(-17, -97),
      ], i < 5 ? const Color(0xff717267) : const Color(0xff424c48));
      rect(-7, -119, 14, 3, _brass);
      rect(-3, -110, 6, 5, const Color(0xff152024));
      canvas.restore();
    }
    canvas.drawCircle(center, 98, paint..color = const Color(0xff080f12));
    // Split door leaves with a narrow, irregular furnace seam.
    path(const [
      Offset(456, 207),
      Offset(456, 266),
      Offset(446, 285),
      Offset(453, 309),
      Offset(443, 333),
      Offset(454, 391),
      Offset(480, 391),
      Offset(489, 333),
      Offset(477, 305),
      Offset(486, 279),
      Offset(475, 260),
      Offset(477, 207),
    ], const Color(0xffaa572f));
    path(const [
      Offset(463, 208),
      Offset(464, 270),
      Offset(457, 288),
      Offset(465, 311),
      Offset(454, 334),
      Offset(463, 391),
      Offset(472, 391),
      Offset(478, 333),
      Offset(468, 307),
      Offset(476, 279),
      Offset(468, 260),
      Offset(470, 208),
    ], const Color(0xffffc17c));
    for (final side in [-1, 1]) {
      canvas.save();
      canvas.translate(466, 299);
      canvas.scale(side.toDouble(), 1);
      path(const [
        Offset(15, -86),
        Offset(63, -61),
        Offset(86, -19),
        Offset(85, 32),
        Offset(55, 75),
        Offset(13, 90),
        Offset(22, 38),
        Offset(12, 10),
        Offset(25, -19),
      ], _iron);
      path(const [
        Offset(29, -62),
        Offset(52, -48),
        Offset(67, -14),
        Offset(66, 25),
        Offset(45, 53),
        Offset(31, 60),
        Offset(39, 25),
        Offset(27, 8),
        Offset(38, -19),
      ], const Color(0xff354345));
      rect(44, -21, 9, 41, const Color(0xff0a1417));
      rect(43, -21, 3, 37, const Color(0xff7b7967));
      canvas.restore();
    }
    // Lintels, inspection plate and warm ground reflection.
    rect(393, 143, 146, 10, const Color(0xff56605a));
    rect(422, 158, 89, 17, const Color(0xff121c1f));
    for (var i = 0; i < 5; i++) {
      rect(438 + i * 12, 163, 5, 7, i == 2 ? _brass : _iron);
    }
    for (var i = 0; i < 4; i++) {
      rect(
        450 - i * 10,
        462 + i * 22,
        34 + i * 20,
        2,
        Color.lerp(const Color(0xffad7248), _iron, i / 4)!,
      );
    }
    // Weathering is seeded so rebuilding never changes the illustration.
    final random = math.Random(24);
    for (var i = 0; i < 280; i++) {
      final x = 310 + random.nextDouble() * 300;
      final y = 135 + random.nextDouble() * 316;
      rect(
        x,
        y,
        1 + random.nextDouble() * 4,
        1,
        i.isEven ? const Color(0x245e7471) : const Color(0x55080e11),
      );
    }
    // Foreground fallen slabs frame the entry, leaving the menu side quiet.
    path(const [
      Offset(607, 516),
      Offset(677, 470),
      Offset(720, 487),
      Offset(720, 600),
      Offset(580, 600),
    ], const Color(0xff0b1416));
    path(const [
      Offset(626, 516),
      Offset(679, 484),
      Offset(720, 498),
      Offset(679, 535),
    ], const Color(0xff2d3939));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BreachArchitecture oldDelegate) => false;
}

class _BreachAtmosphere extends CustomPainter {
  _BreachAtmosphere(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scene(canvas, size);
    final t = clock.value * math.pi * 2;
    final paint = Paint()..isAntiAlias = false;
    // The lock's small index teeth move slowly; the door remains planted.
    canvas.save();
    canvas.translate(466, 299);
    canvas.rotate(t);
    for (var i = 0; i < 3; i++) {
      canvas.rotate(math.pi * 2 / 3);
      canvas.drawRect(
        const Rect.fromLTWH(-2, -135, 4, 9),
        paint..color = const Color(0xffb39468),
      );
    }
    canvas.restore();
    final random = math.Random(91);
    for (var i = 0; i < 32; i++) {
      final start = random.nextDouble();
      final progress = (start + clock.value * (i.isEven ? 1 : 2)) % 1;
      final x = 280 + random.nextDouble() * 400 + math.sin(t + i) * 7;
      final y = 550 - progress * 490;
      final alpha = math.sin(progress * math.pi) * .45;
      canvas.drawRect(
        Rect.fromLTWH(x, y, i % 3 == 0 ? 3 : 1.5, 2),
        paint..color = const Color(0xffd5ab76).withValues(alpha: alpha),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BreachAtmosphere oldDelegate) =>
      oldDelegate.clock != clock;
}
