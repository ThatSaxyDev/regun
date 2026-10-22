import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// First-run briefing, shown over the paused practice arena.
class TrainingNotice extends StatelessWidget {
  const TrainingNotice({
    super.key,
    required this.onStart,
    required this.onSkip,
    this.ready = true,
  });

  final VoidCallback onStart, onSkip;
  final bool ready;
  static const _brass = Color(0xffE1BA78);
  static const _paper = Color(0xffE5DDD1);

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    label: 'Training mode',
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: CustomPaint(
            painter: const _TrainingFrame(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CustomPaint(size: Size(16, 16), painter: _TrainingMark()),
                      SizedBox(width: 10),
                      Text(
                        'FIELD BRIEFING',
                        style: TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: _brass,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TRAINING MODE',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 17,
                      height: 1.5,
                      color: _paper,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Learn to move, shoot, dash and reload. '
                    'Skip straight to a real run whenever you’re ready.',
                    style: TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 13,
                      height: 1.65,
                      color: _paper,
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final start = ClickButton(
                        text: 'Start training',
                        glyph: PixelGlyph.play,
                        height: 48,
                        onTap: ready ? onStart : null,
                      );
                      final skip = ClickButton(
                        text: 'Skip training',
                        height: 48,
                        buttonColor: const Color(0xffA79AA9),
                        onTap: ready ? onSkip : null,
                      );
                      if (constraints.maxWidth < 340 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [start, const SizedBox(height: 8), skip],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: skip),
                          const SizedBox(width: 12),
                          Expanded(child: start),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrainingFrame extends CustomPainter {
  const _TrainingFrame();
  @override
  void paint(Canvas canvas, Size size) {
    final path = controlPlate((Offset.zero & size).deflate(1));
    canvas.drawPath(path, Paint()..color = const Color(0xff211B26));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff8D7651)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      const Offset(16, 7),
      Offset(size.width - 16, 7),
      Paint()..color = const Color(0xff51454C),
    );
  }

  @override
  bool shouldRepaint(_TrainingFrame oldDelegate) => false;
}

class _TrainingMark extends CustomPainter {
  const _TrainingMark();
  @override
  void paint(Canvas canvas, Size size) => paintPixelGlyph(
    canvas,
    Offset.zero & size,
    PixelGlyph.crosshair,
    TrainingNotice._brass,
  );
  @override
  bool shouldRepaint(_TrainingMark oldDelegate) => false;
}
