import 'dart:ui';

/// Contact points of the cropped pod artwork at its planted bottom-center anchor.
/// The two front feet end at y=0; the rear outriggers touch twelve units behind.
class SupplyPodArt {
  static const width = 116.0;
  static const feet = [
    Offset(-24, -1),
    Offset(24, -1),
    Offset(-48, -12),
    Offset(48, -12),
  ];

  static void ground(
    Canvas canvas,
    Offset position, {
    required bool landed,
    double opacity = 1,
  }) {
    final ink = Paint()..isAntiAlias = false;
    // Compact occlusion stays under the chassis rather than below the object.
    canvas.drawOval(
      Rect.fromCenter(
        center: position + const Offset(0, -10),
        width: 100,
        height: 26,
      ),
      ink..color = Color.fromRGBO(9, 12, 10, .32 * opacity),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: position + const Offset(0, -8),
        width: 82,
        height: 17,
      ),
      ink..color = Color.fromRGBO(7, 9, 8, .44 * opacity),
    );
    if (!landed) return;
    for (var i = 0; i < feet.length; i++) {
      final foot = position + feet[i];
      final size = i < 2 ? 22.0 : 18.0;
      canvas.drawRect(
        Rect.fromCenter(center: foot, width: size, height: 6),
        ink..color = Color.fromRGBO(6, 8, 7, .72 * opacity),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: foot + const Offset(0, -1),
          width: size - 6,
          height: 4,
        ),
        ink..color = Color.fromRGBO(4, 6, 5, .8 * opacity),
      );
    }
  }
}
