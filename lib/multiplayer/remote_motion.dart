import 'dart:math' as math;
import 'dart:ui';

import 'movement_prediction.dart';

class _RemoteSample {
  const _RemoteSample(
    this.time,
    this.arrival,
    this.position,
    this.velocity,
    this.limit,
  );
  final double time, arrival, limit;
  final Offset position, velocity;
}

/// Presentation only: short adaptive interpolation with at most 80ms of
/// extrapolation. Server snapshots remain the only collision/damage authority.
class RemoteMotion {
  final List<_RemoteSample> _samples = [];
  String? _epoch;
  int _tick = -1;
  double _jitter = 0, _cursor = double.negativeInfinity;
  double interpolationDelay = .02;
  double extrapolatedSeconds = 0;
  int underRuns = 0;
  int get sampleCount => _samples.length;

  void clear() {
    _samples.clear();
    _epoch = null;
    _tick = -1;
    _jitter = 0;
    _cursor = double.negativeInfinity;
    interpolationDelay = .02;
    extrapolatedSeconds = 0;
    underRuns = 0;
  }

  void add({
    required String epoch,
    required int tick,
    required double serverTime,
    required double arrival,
    required Offset position,
    required bool moving,
    bool discontinuity = false,
    double maxSpeed = 1450,
    double extrapolationLimit = .08,
  }) {
    if (!serverTime.isFinite ||
        !arrival.isFinite ||
        !position.dx.isFinite ||
        !position.dy.isFinite) {
      return;
    }
    if (_epoch == epoch && tick <= _tick) return;
    if (_epoch != epoch ||
        discontinuity ||
        (_samples.isNotEmpty &&
            (position - _samples.last.position).distance > 300)) {
      clear();
      _epoch = epoch;
    }
    if (tick <= _tick) return;
    final previous = _samples.lastOrNull;
    if (previous != null && serverTime <= previous.time) return;
    var velocity = Offset.zero;
    if (previous != null) {
      final interval = serverTime - previous.time;
      final error = ((arrival - previous.arrival) - interval).abs();
      _jitter += (error - _jitter) * .15;
      final target = (.02 + _jitter * 1.5).clamp(.02, .07);
      interpolationDelay +=
          (target - interpolationDelay) *
          (target > interpolationDelay ? .5 : .1);
      if (moving && interval < .25) {
        velocity = (position - previous.position) / interval;
        if (velocity.distance > maxSpeed) {
          velocity *= maxSpeed / velocity.distance;
        }
      }
    }
    _tick = tick;
    _samples.add(
      _RemoteSample(
        serverTime,
        arrival,
        position,
        velocity,
        extrapolationLimit.clamp(0.0, .08),
      ),
    );
    while (_samples.length > 24 ||
        (_samples.length > 2 && serverTime - _samples.first.time > 1)) {
      _samples.removeAt(0);
    }
  }

  Offset? render(double now, MotionMap map, {bool reducedMotion = false}) {
    if (_samples.isEmpty) return null;
    final latest = _samples.last;
    // A recent minimum clock offset estimates the baseline delivery delay.
    // It does not claim to measure one-way latency or synchronize wall clocks.
    final offset = _samples.map((s) => s.arrival - s.time).reduce(math.min);
    final wanted = now - offset - interpolationDelay;
    _cursor = math.max(_cursor, wanted);
    extrapolatedSeconds = 0;
    if (_cursor <= _samples.first.time) return _samples.first.position;
    for (var i = 1; i < _samples.length; i++) {
      final b = _samples[i], a = _samples[i - 1];
      if (_cursor <= b.time) {
        final t = ((_cursor - a.time) / (b.time - a.time)).clamp(0.0, 1.0);
        // Use shared swept cover constraints for interpolated paths too.
        return map.move(a.position, (b.position - a.position) * t);
      }
    }
    final age = math.max(0.0, _cursor - latest.time);
    if (age > .08) underRuns++;
    extrapolatedSeconds = reducedMotion ? 0 : age.clamp(0.0, latest.limit);
    return map.move(latest.position, latest.velocity * extrapolatedSeconds);
  }
}
