import 'package:flutter/material.dart';

/// Full-window margins and contrast for screens that sit over the arena.
class DesktopFieldFrame extends StatelessWidget {
  const DesktopFieldFrame({
    super.key,
    required this.child,
    this.openCenter = false,
  });

  final Widget child;
  final bool openCenter;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: openCenter
          ? const LinearGradient(
              colors: [
                Color(0xff181a15),
                Color(0xe8181a15),
                Color(0x29181a15),
                Color(0x47181a15),
                Color(0xf0181a15),
              ],
              stops: [0, .22, .45, .67, 1],
            )
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xee181a15), Color(0x88181a15), Color(0xf2181a15)],
            ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (box.maxWidth * .05).clamp(16, 112),
            vertical: (box.maxHeight * .045).clamp(12, 56),
          ),
          child: child,
        ),
      ),
    ),
  );
}
