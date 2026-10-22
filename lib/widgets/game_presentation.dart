import 'package:flutter/material.dart';
import 'package:regun/presentation/game_layout.dart';

/// Tablet type scales independently of world art and the player's accessibility
/// preference. Phone MediaQuery and text metrics pass through unchanged.
class GamePresentation extends StatelessWidget {
  const GamePresentation({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context),
        factor = GameLayout.uiScale(MediaQuery.sizeOf(context));
    if (factor == 1) return child;
    return MediaQuery(
      data: data.copyWith(textScaler: _TabletText(data.textScaler, factor)),
      child: child,
    );
  }
}

class _TabletText extends TextScaler {
  const _TabletText(this.parent, this.factor);
  final TextScaler parent;
  final double factor;
  @override
  double scale(double fontSize) => parent.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is _TabletText && other.parent == parent && other.factor == factor;
  @override
  int get hashCode => Object.hash(parent, factor);
}
