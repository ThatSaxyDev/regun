import 'package:flutter/material.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

const bossDefeatVerbs = [
  'VANQUISHED',
  'DEFEATED',
  'SLAIN',
  'OVERTHROWN',
  'CONQUERED',
  'BROKEN',
  'FELLED',
  'CRUSHED',
];

/// Compact, nonmodal HUD strip, never a central card or input blocker.
class BossVictoryBanner extends StatelessWidget {
  const BossVictoryBanner({
    super.key,
    required this.kind,
    this.verb = 'VANQUISHED',
  });
  final BossKind kind;
  final String verb;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      liveRegion: true,
      label: '${kind.title} $verb. Two health gained.',
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: CustomPaint(
              painter: _VictoryPlate(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 9,
                  runSpacing: 4,
                  children: [
                    Text(
                      kind.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 10,
                        color: Color(0xffDDD3BF),
                      ),
                    ),
                    Text(
                      verb,
                      style: const TextStyle(
                        fontFamily: FontFam.pressStart,
                        fontSize: 9,
                        color: Color(0xffE1BA78),
                      ),
                    ),
                    const Text(
                      '+2 HP',
                      style: TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 10,
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
