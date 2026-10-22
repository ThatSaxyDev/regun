import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

/// First-run briefing uses the same banner surface as release notices.
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
  @override
  Widget build(BuildContext context) => GameNotice(
    maxWidth: 480,
    eyebrow: 'FIELD BRIEFING',
    title: 'TRAINING MODE',
    leading: const CustomPaint(size: Size(16, 16), painter: _TrainingMark()),
    message: 'Learn to move, shoot, dash and reload. Skip straight to a real run whenever you’re ready.',
    actions: GameNoticeActions(
      primaryFirstWhenStacked: true,
      primary: ClickButton(
        text: 'Start training',
        glyph: PixelGlyph.play,
        height: 48,
        onTap: ready ? onStart : null,
      ),
      secondary: ClickButton(
        text: 'Skip training',
        height: 48,
        buttonColor: const Color(0xffA79AA9),
        onTap: ready ? onSkip : null,
      ),
    ),
  );
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
