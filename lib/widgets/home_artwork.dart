import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:regun/presentation/regun_art.dart';

/// Static menu illustration. No game loop or animated sprite ticker.
class HomeArtwork extends StatelessWidget {
  const HomeArtwork({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: RegunArt.shared.load(),
      builder: (context, snapshot) => RepaintBoundary(
          child: Semantics(
              label: 'Three survivors standing together',
              image: true,
              child: CustomPaint(
                  painter: snapshot.connectionState == ConnectionState.done
                      ? const _SurvivorArtwork()
                      : null))));
}

class _SurvivorArtwork extends CustomPainter {
  const _SurvivorArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 280, size.height / 280);
    final glow = Paint()
      ..shader = const RadialGradient(
              colors: [Color(0x35457F81), Color(0x1279825E), Color(0x00141117)])
          .createShader(const Rect.fromLTWH(0, 12, 280, 250));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 280, 280), glow);
    // Quiet shafts of light and a shared ground plane unify the silhouettes.
    final light = Paint()..color = const Color(0x0DD5BA75);
    canvas.drawPath(
        Path()
          ..moveTo(210, 25)
          ..lineTo(88, 230)
          ..lineTo(151, 230)
          ..close(),
        light);
    canvas.drawOval(const Rect.fromLTWH(25, 213, 230, 26),
        Paint()..color = const Color(0x6507080B));
    final art = RegunArt.shared;
    final ink = Paint()..filterQuality = FilterQuality.none;
    art.sprite('characters/warden', 8).render(canvas,
        position: Vector2(131, 70), size: Vector2.all(160), overridePaint: ink);
    art.sprite('characters/scrapper', 8).render(canvas,
        position: Vector2(0, 85), size: Vector2.all(157), overridePaint: ink);
    art.sprite('characters/rook', 8).render(canvas,
        position: Vector2(53, 75), size: Vector2.all(185), overridePaint: ink);
    canvas.drawLine(
        const Offset(73, 243),
        const Offset(207, 243),
        Paint()
          ..color = const Color(0x65B69457)
          ..strokeWidth = 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SurvivorArtwork oldDelegate) => false;
}
