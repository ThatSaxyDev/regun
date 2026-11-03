import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/systems/arena_geometry.dart';

/// The director's active clock also makes a continued run resume at the same
/// point on the track. Stops at either end give the player a crossing window.
class FoundryRail {
  const FoundryRail(this.track, {this.offset = 0});

  final Rect track;
  final double offset;
  static const width = 118.0;
  static const length = 178.0;
  static const _stop = 3.2;
  static const _travel = 2.9;
  static const _leg = _stop + _travel;

  static const stagger = _leg / 2;
  static const _startupHold = 1.25;

  double _clock(double time) =>
      (time + offset - _startupHold).clamp(0.0, double.infinity);
  double _phase(double time) => _clock(time) % _leg;
  bool _southbound(double time) => (_clock(time) ~/ _leg).isEven;

  bool moving(double time) => _phase(time) >= _stop;
  bool southbound(double time) => _southbound(time);

  bool warning(double time) =>
      _phase(time) >= _stop - 1.25 && _phase(time) < _stop;

  Rect bodyAt(double time) {
    final progress = ((_phase(time) - _stop) / _travel).clamp(0.0, 1.0);
    final y = lerpDouble(
      track.top + length / 2,
      track.bottom - length / 2,
      _southbound(time) ? progress : 1 - progress,
    )!;
    return Rect.fromCenter(
      center: Offset(track.center.dx, y),
      width: width,
      height: length,
    );
  }

  /// Evaluate actor motion relative to the cart across the same frame.
  static bool strikes(
    Rect before,
    Rect after,
    Vector2 actorBefore,
    Vector2 actorAfter,
    double radius,
  ) {
    if (before == after) return false;
    final motion = after.center - before.center;
    return ArenaGeometry.crosses(
      actorBefore,
      actorAfter - Vector2(motion.dx, motion.dy),
      before.inflate(radius),
    );
  }
}
