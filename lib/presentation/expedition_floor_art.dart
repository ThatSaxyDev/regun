import 'dart:ui';

/// Broken stencil paint leaves the arena texture visible through each mark.
abstract final class ExpeditionFloorArt {
  // Two narrow painted rails form the shaft and open into a split arrowhead.
  // The empty center lets the stone show through the full length of the mark.
  static final _deployment = Path()
    ..moveTo(-54, -26)
    ..lineTo(-5, -72)
    ..lineTo(-5, -58)
    ..lineTo(-32, -32)
    ..lineTo(-14, -32)
    ..lineTo(-14, 13)
    ..lineTo(-22, 20)
    ..lineTo(-22, -23)
    ..lineTo(-54, -23)
    ..close()
    ..moveTo(54, -26)
    ..lineTo(5, -72)
    ..lineTo(5, -58)
    ..lineTo(32, -32)
    ..lineTo(14, -32)
    ..lineTo(14, 13)
    ..lineTo(22, 20)
    ..lineTo(22, -23)
    ..lineTo(54, -23)
    ..close()
    ..moveTo(-22, 32)
    ..lineTo(-14, 24)
    ..lineTo(-14, 56)
    ..lineTo(-22, 56)
    ..close()
    ..moveTo(22, 32)
    ..lineTo(14, 24)
    ..lineTo(14, 56)
    ..lineTo(22, 56)
    ..close();

  static final _chevron = Path()
    ..moveTo(-22, 9)
    ..lineTo(0, -12)
    ..lineTo(22, 9)
    ..lineTo(13, 9)
    ..lineTo(0, -3)
    ..lineTo(-13, 9)
    ..close();

  static final _corner = Path()
    ..moveTo(-25, 15)
    ..lineTo(-25, -10)
    ..lineTo(-18, -17)
    ..lineTo(25, -17)
    ..lineTo(25, -11)
    ..lineTo(-15, -11)
    ..lineTo(-19, -7)
    ..lineTo(-19, 15)
    ..close();

  static final _wear = Path()
    ..addRect(const Rect.fromLTWH(-5, -24, 7, 2))
    ..addRect(const Rect.fromLTWH(5, -17, 5, 2))
    ..addRect(const Rect.fromLTWH(-19, -13, 8, 2))
    ..addRect(const Rect.fromLTWH(-3, -6, 5, 3))
    ..addRect(const Rect.fromLTWH(14, 5, 5, 2))
    ..addRect(const Rect.fromLTWH(-8, 12, 5, 2));

  static final _paintedDeployment = Path.combine(
    PathOperation.difference,
    _deployment,
    Path()
      ..addRect(const Rect.fromLTWH(-31, -51, 8, 3))
      ..addRect(const Rect.fromLTWH(26, -43, 8, 3))
      ..addRect(const Rect.fromLTWH(-45, -29, 7, 2))
      ..addRect(const Rect.fromLTWH(39, -28, 7, 3))
      ..addRect(const Rect.fromLTWH(-23, -6, 5, 4))
      ..addRect(const Rect.fromLTWH(18, 7, 7, 3))
      ..addRect(const Rect.fromLTWH(-20, 42, 6, 2))
      ..addRect(const Rect.fromLTWH(14, 48, 5, 3)),
  );
  static final _paintedChevron = Path.combine(
    PathOperation.difference,
    _chevron,
    _wear,
  );
  static final _paintedCorner = Path.combine(
    PathOperation.difference,
    _corner,
    _wear,
  );

  static void deployment(Canvas canvas, Offset at) =>
      _paint(canvas, _paintedDeployment, at, 0, 1, const Color(0xadc4b184));

  static void chevron(
    Canvas canvas,
    Offset at,
    double angle, {
    double scale = 1,
  }) => _paint(
    canvas,
    _paintedChevron,
    at,
    angle,
    scale,
    const Color(0x85bcab81),
  );

  static void corner(
    Canvas canvas,
    Offset at,
    double angle, {
    bool range = false,
  }) => _paint(
    canvas,
    _paintedCorner,
    at,
    angle,
    1,
    range ? const Color(0x9fbd9861) : const Color(0x8a939c86),
  );

  static void _paint(
    Canvas canvas,
    Path path,
    Offset at,
    double angle,
    double scale,
    Color color,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
    canvas.restore();
  }
}
