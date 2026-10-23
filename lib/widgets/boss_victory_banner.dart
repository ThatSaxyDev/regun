import 'package:flutter/material.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

/// Brief, nonmodal victory stamp. No timers, gameplay gates or pointer capture.
class BossVictoryBanner extends StatelessWidget {
  const BossVictoryBanner({super.key, required this.kind});
  final BossKind kind;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      liveRegion: true,
      label: '${kind.title} vanquished. Two health gained.',
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: CustomPaint(
              painter: _VictoryPlate(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kind.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Color(0xffDDD3BF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'VANQUISHED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 15,
                        color: Color(0xffE1BA78),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      '+2 HEALTH',
                      style: TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xffB4C29B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _VictoryPlate extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = controlPlate((Offset.zero & size).deflate(1), cut: 9);
    canvas.drawPath(path, Paint()..color = const Color(0xee1D211D));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff8E7952)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final right in [false, true]) {
      final x = right ? size.width - 12 : 8.0;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height / 2 - 3, 4, 6),
        Paint()..color = const Color(0xffE1BA78),
      );
    }
  }

  @override
  bool shouldRepaint(_VictoryPlate oldDelegate) => false;
}
