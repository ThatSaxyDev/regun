import 'dart:math' as math;
import 'dart:ui';

/// Distance-driven feet, with a separate living stance when pursuit is blocked.
/// Facing follows confirmed target intent, never individual collision corrections.
class MummyWalk {
  static const distancePerFrame = 9.0;
  double distance = 0, clock = 0;
  bool left = false, blocked = false;
  Offset? _position, _progressAnchor;
  double _progressTime = 0, _turnTime = 0, _signedTravel = 0;
  bool? _pendingLeft;
  bool _facingKnown = false;
  double? _sampleAge;
  int get frame => (distance / distancePerFrame).floor() % 8;

  void follow(
    Offset position, {
    required bool walking,
    double? facingX,
    double dt = 1 / 60,
  }) {
    final delta = _position == null ? Offset.zero : position - _position!;
    _position = position;
    if (dt <= 0) return; // Sample before movement without advancing any clocks.
    dt = dt.clamp(0.0, .1);
    clock += dt;
    final relocated = delta.distance >= 120;
    if (relocated) {
      _progressAnchor = position;
      _progressTime = 0;
      _signedTravel = 0;
      blocked = false;
    }
    if (walking && !relocated) {
      if (delta.distance > .001) {
        distance = (distance + delta.distance) % (distancePerFrame * 8);
      }
      _progressAnchor ??= position;
      _progressTime += dt;
      if (_progressTime >= .25) {
        blocked = (position - _progressAnchor!).distance < 3;
        _progressAnchor = position;
        _progressTime = 0;
      }
    } else if (!walking) {
      blocked = false;
      _progressAnchor = position;
      _progressTime = 0;
    }
    bool? desired = facingX == null ? _pendingLeft : null;
    if (facingX != null) {
      // World-space dead band: near-vertical targets cannot jitter the mirror.
      if (facingX.abs() >= 12) desired = facingX < 0;
    } else if (walking && !relocated && delta.dx.abs() > delta.dy.abs() * .2) {
      // Legacy/preview callers have no target: require net horizontal travel.
      _signedTravel += delta.dx;
      if (_signedTravel.abs() >= 8) {
        desired = _signedTravel < 0;
        _signedTravel = 0;
      }
    }
    if (desired == null || desired == left) {
      _pendingLeft = null;
      _turnTime = 0;
    } else if (!_facingKnown) {
      left = desired;
      _facingKnown = true;
    } else {
      if (_pendingLeft != desired) _turnTime = 0;
      _pendingLeft = desired;
      _turnTime += dt;
      if (_turnTime + 1e-8 >= .15) {
        left = desired;
        _pendingLeft = null;
        _turnTime = 0;
      }
    }
    if (desired != null) _facingKnown = true;
  }

  /// Network snapshots use authoritative age, so repeated or frozen snapshots
  /// cannot manufacture gait, breathing or facing confirmation time.
  void followSnapshot(
    Offset position, {
    required double age,
    required bool walking,
    double? facingX,
  }) {
    final previous = _sampleAge;
    _sampleAge = age;
    follow(
      position,
      walking: walking,
      facingX: facingX,
      dt: previous == null || age < previous ? 0 : age - previous,
    );
  }

  /// Existing strike receipt owns the release pose; no new damage clock.
  static int attackFrame(double sinceStrike, {required bool hasStruck}) =>
      hasStruck && sinceStrike < .14 ? 6 : 5;

  /// A slight torso compression with planted feet, not walking in place.
  double stanceScale({required bool reducedMotion}) => reducedMotion
      ? 1
      : 1 + .018 * (1 - math.cos(clock * math.pi * 2 / 1.8)) / 2;
}
