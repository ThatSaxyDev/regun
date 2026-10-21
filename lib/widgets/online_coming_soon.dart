import 'package:flutter/material.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/click_button.dart';

Future<void> showOnlineComingSoon(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: CustomPaint(
          painter: const _ComingSoonFrame(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Co-op and versus are on the way. Stay tuned.',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xffB8AFA6),
                  ),
                ),
                const SizedBox(height: 24),
                ClickButton(
                  text: 'Got it',
                  height: 48,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

class _ComingSoonFrame extends CustomPainter {
  const _ComingSoonFrame();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1);
    final path = controlPlate(bounds);
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
      Paint()
        ..color = const Color(0xff51454C)
        ..strokeWidth = 1,
    );
    for (final x in [8.0, size.width - 10]) {
      canvas.drawRect(
        Rect.fromLTWH(x, size.height / 2, 2, 2),
        Paint()..color = const Color(0xffA5895B),
      );
    }
  }

  @override
  bool shouldRepaint(_ComingSoonFrame oldDelegate) => false;
}
