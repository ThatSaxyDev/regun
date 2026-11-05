import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/game.dart';

mixin TouchControlVisibility on PositionComponent {
  bool get showTouchControl =>
      (findGame() as RegunGame?)?.usingDesktopInput != true;

  @override
  void renderTree(Canvas canvas) {
    if (showTouchControl) super.renderTree(canvas);
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      showTouchControl && super.containsLocalPoint(point);
}
