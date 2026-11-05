import 'package:flutter/material.dart';
import 'package:regun/widgets/game_notice.dart';

/// Keeps the current route mounted while a portrait viewport blocks play.
class WebLandscapePrompt extends StatelessWidget {
  const WebLandscapePrompt({super.key, required this.child});

  final Widget child;

  static bool blocksPlay(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LandscapeState>()?.blocked ??
      false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      final blocked =
          viewport.maxWidth > 0 &&
          viewport.maxHeight > 0 &&
          viewport.maxWidth <= viewport.maxHeight;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: blocked,
            child: TickerMode(
              enabled: !blocked,
              child: ExcludeFocus(
                excluding: blocked,
                child: _LandscapeState(blocked: blocked, child: child),
              ),
            ),
          ),
          if (blocked)
            const ColoredBox(
              color: Color(0xff191a17),
              child: SafeArea(
                minimum: EdgeInsets.all(20),
                child: Center(
                  child: GameNotice(
                    eyebrow: 'REGUN / DISPLAY',
                    title: 'LANDSCAPE REQUIRED',
                    message: 'Widen the browser window or rotate your display to play.',
                    leading: Image(
                      image: AssetImage('assets/art/branding/rook_mark.png'),
                      width: 30,
                      height: 30,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                    actions: SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _LandscapeState extends InheritedWidget {
  const _LandscapeState({required this.blocked, required super.child});

  final bool blocked;

  @override
  bool updateShouldNotify(_LandscapeState oldWidget) =>
      blocked != oldWidget.blocked;
}
