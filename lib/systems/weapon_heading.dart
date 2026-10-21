import 'dart:math' as math;
import 'dart:ui';

/// Resting pose only: deliberate aim wins immediately, including during reload.
class WeaponHeading {
  double idle = 0;
  Offset advance(
    Offset current,
    Offset movement,
    Offset aim,
    double dt, {
    bool reducedMotion = false,
  }) {
    if (aim.distanceSquared > 1e-6) {
      idle = 0;
      return aim / aim.distance;
    }
    final before = idle;
    idle += dt;
    if (movement.distanceSquared < 1e-6 || idle <= .65) return current;
    if (reducedMotion) return movement / movement.distance;
    final a = math.atan2(current.dy, current.dx),
        b = math.atan2(movement.dy, movement.dx);
    final difference = math.atan2(math.sin(b - a), math.cos(b - a));
    final turn = 8 * (idle - math.max(.65, before));
    final angle = a + difference.clamp(-turn, turn);
    return Offset(math.cos(angle), math.sin(angle));
  }
}
