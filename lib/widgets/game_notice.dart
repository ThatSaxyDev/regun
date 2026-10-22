import 'package:flutter/material.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

/// Shared banner surface, extracted from the approved update notice.
class GameNotice extends StatelessWidget {
  const GameNotice({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.actions,
    this.detail,
    this.leading,
    this.maxWidth = 500,
  });
  final String eyebrow, title, message;
  final Widget actions;
  final Widget? detail, leading;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    label: title,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: CustomPaint(
            painter: const GameNoticeFrame(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          eyebrow,
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 10,
                            letterSpacing: 1.3,
                            height: 1.5,
                            color: Color(0xffE1BA78),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 16,
                      height: 1.5,
                      color: Color(0xffE5DDD1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 13,
                      height: 1.65,
                      color: Color(0xffE5DDD1),
                    ),
                  ),
                  if (detail != null) ...[const SizedBox(height: 12), detail!],
                  const SizedBox(height: 24),
                  actions,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GameNoticeActions extends StatelessWidget {
  const GameNoticeActions({
    super.key,
    required this.primary,
    this.secondary,
    this.primaryFirstWhenStacked = false,
  });
  final Widget primary;
  final Widget? secondary;
  final bool primaryFirstWhenStacked;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (secondary == null) return primary;
      if (box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primaryFirstWhenStacked ? primary : secondary!,
            const SizedBox(height: 8),
            primaryFirstWhenStacked ? secondary! : primary,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: secondary!),
          const SizedBox(width: 12),
          Expanded(child: primary),
        ],
      );
    },
  );
}

class GameNoticeFrame extends CustomPainter {
  const GameNoticeFrame();
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
      Paint()
        ..color = const Color(0xff51454C)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(GameNoticeFrame oldDelegate) => false;
}

/// Compact notification uses the same material without becoming a modal prompt.
class GameNoticeStrip extends StatelessWidget {
  const GameNoticeStrip({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: CustomPaint(
      painter: const GameNoticeFrame(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          message,
          style: const TextStyle(
            inherit: false,
            decoration: TextDecoration.none,
            fontFamily: FontFam.orbitron,
            fontSize: 12,
            height: 1.5,
            color: Color(0xffE5DDD1),
          ),
        ),
      ),
    ),
  );
}
