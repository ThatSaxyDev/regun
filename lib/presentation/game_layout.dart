import 'dart:math' as math;
import 'dart:ui';

/// Phones keep the approved framing exactly. Tablets reveal more arena instead
/// of cropping the phone view or stretching sprites into a letterboxed strip.
class GameLayout {
  static bool tablet(Size size) => size.shortestSide >= 600;
  static double uiScale(Size size) => tablet(size) ? 1.25 : 1;
  static Size world(Size canvas) {
    if (!tablet(canvas) || canvas.width <= 0 || canvas.height <= 0) {
      return const Size(1500, 700);
    }
    final ratio = canvas.width / canvas.height;
    return Size(math.max(1500, 700 * ratio), math.max(700, 1500 / ratio));
  }
}
