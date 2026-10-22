import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';

/// The planted gun hand is the pivot; the barrel and beam share its heading.
/// Coordinates are measured from the Marshal's separated planted aiming pose.
class MarshalAim {
  static Offset grip(Offset center, double size, bool left) =>
      center + Offset((left ? -1 : 1) * size * .354, 70 - size * .543);
  static Offset direction(Offset center, Offset aim, double size, bool left) {
    final delta = aim - grip(center, size, left);
    return delta.distance < .001
        ? Offset(left ? -1 : 1, 0)
        : delta / delta.distance;
  }

  static Offset muzzle(Offset center, Offset aim, double size, bool left) =>
      grip(center, size, left) +
      direction(center, aim, size, left) * (size * .35);

  static bool facingLeft(
    Offset center,
    Offset source,
    Offset aim,
    double size,
  ) =>
      (muzzle(center, aim, size, true) - source).distanceSquared <
      (muzzle(center, aim, size, false) - source).distanceSquared;

  static void paint(
    Canvas canvas,
    Offset center,
    Offset aim,
    double size, {
    required bool left,
    required ColorFilter ambient,
  }) {
    final art = RegunArt.shared;
    if (!art.contains('effects/marshal_aim')) return;
    final body = art.rawSprite('effects/marshal_aim', 0);
    final gun = art.rawSprite('effects/marshal_aim', 1);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ambient;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (left) canvas.scale(-1, 1);
    body.render(
      canvas,
      position: Vector2(0, 70),
      size: body.srcSize * (size * .8 / body.srcSize.y),
      anchor: Anchor.bottomCenter,
      overridePaint: paint,
    );
    canvas.restore();
    final hand = grip(center, size, left),
        heading = direction(center, aim, size, left);
    final width = size * .35 / .83;
    final height = width * gun.srcSize.y / gun.srcSize.x;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(math.atan2(heading.dy, heading.dx));
    if (left) canvas.scale(1, -1);
    gun.render(
      canvas,
      position: Vector2(-width * .17, -height * .32),
      size: Vector2(width, height),
      overridePaint: paint,
    );
    canvas.restore();
  }
}
