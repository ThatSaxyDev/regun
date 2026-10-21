import 'dart:math';
import 'dart:ui';

import 'package:regun/systems/run_random.dart';

enum SupplyPhase { warning, falling, active, opened, breaking }

class SupplyDrop {
  SupplyDrop(this.position);
  final Offset position;
  SupplyPhase phase = SupplyPhase.warning;
  double elapsed = 0, capture = 0, life = 0;
  bool inside = false, claimed = false;
  static const radius = 260.0, impactRadius = 62.0;
  static const captureSeconds = 8.0, lifetime = 50.0;
}

/// One optional risk/reward objective at a time; only the game advances this
/// simulation clock. Save the phase, so restoring never repeats a landing hit
/// or a claimed reward. Separate RNG keeps drop scheduling reproducible.
class SupplyDrops {
  final _random = RunRandom(1);
  SupplyDrop? drop;
  Offset? previous;
  double nextIn = 26;

  void reset(int seed) {
    _random.state = seed;
    drop = null;
    previous = null;
    nextIn = 22 + _random.nextDouble() * 10;
  }

  void advance(
    double dt, {
    required Offset player,
    required Offset? Function() pickPosition,
    required void Function(Offset) onLand,
    required bool Function() onReward,
    required void Function(int) onCharge,
    required void Function() onWarning,
    required void Function() onBreak,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    var current = drop;
    if (current == null) {
      nextIn -= dt;
      if (nextIn > 0) return;
      final spot = pickPosition();
      if (spot == null) {
        nextIn = 3;
        return;
      }
      nextIn = 0;
      current = drop = SupplyDrop(spot);
      previous = spot;
      onWarning();
      return; // A slow frame must still show anticipation before the impact.
    }
    var remaining = dt;
    for (var i = 0; i < 8 && remaining > 0; i++) {
      final inside = (player - current.position).distance <= SupplyDrop.radius;
      final entering = inside && !current.inside;
      current.inside = inside;
      final duration = switch (current.phase) {
        SupplyPhase.warning => 1.8,
        SupplyPhase.falling => .65,
        SupplyPhase.active => SupplyDrop.lifetime,
        SupplyPhase.opened => 3.0,
        SupplyPhase.breaking => 1.3,
      };
      if (current.phase == SupplyPhase.active) {
        var step = min(remaining, SupplyDrop.lifetime - current.life);
        if (inside && current.capture < SupplyDrop.captureSeconds) {
          step = min(step, SupplyDrop.captureSeconds - current.capture);
        }
        final before = current.capture;
        current.life += step;
        current.elapsed += step;
        if (inside) {
          current.capture = min(SupplyDrop.captureSeconds, before + step);
        }
        remaining -= step;
        if (current.life + 1e-8 >= SupplyDrop.lifetime) {
          current.phase = SupplyPhase.breaking;
          current.elapsed = 0;
          onBreak();
        } else if (inside &&
            current.capture + 1e-8 >= SupplyDrop.captureSeconds &&
            onReward()) {
          current.phase = SupplyPhase.opened;
          current.claimed = true;
          current.elapsed = 0;
          return; // The reward picker freezes this objective immediately.
        } else {
          if (inside &&
              (entering || current.capture.floor() > before.floor())) {
            onCharge(current.capture.floor().clamp(0, 7));
          }
          if (step <= 0 || remaining <= 0) return;
        }
      } else {
        final step = min(remaining, max(0.0, duration - current.elapsed));
        current.elapsed += step;
        remaining -= step;
        if (current.elapsed + 1e-8 < duration) return;
        switch (current.phase) {
          case SupplyPhase.warning:
            current.phase = SupplyPhase.falling;
          case SupplyPhase.falling:
            current.phase = SupplyPhase.active;
            current.inside = false;
            // The small crush footprint is separate from the wide capture field.
            onLand(current.position);
          case SupplyPhase.opened:
            current.phase = SupplyPhase.breaking;
            onBreak();
          case SupplyPhase.breaking:
            drop = null;
            nextIn = 55 + _random.nextDouble() * 25;
            return;
          case SupplyPhase.active:
            break;
        }
        current.elapsed = 0;
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'random': _random.state,
    'nextIn': nextIn,
    if (previous != null) 'previous': [previous!.dx, previous!.dy],
    if (drop case final d?)
      'drop': {
        'position': [d.position.dx, d.position.dy],
        'phase': d.phase.name,
        'elapsed': d.elapsed,
        'capture': d.capture,
        'life': d.life,
        'claimed': d.claimed,
      },
  };

  void restore(Map<String, dynamic> json) {
    double number(Map map, String key, double maximum) {
      final v = map[key];
      if (v is! num || !v.isFinite || v < 0 || v > maximum) {
        throw const FormatException('Invalid supply clock');
      }
      return v.toDouble();
    }

    Offset point(dynamic raw) {
      if (raw is! List ||
          raw.length != 2 ||
          raw.any((n) => n is! num || !n.isFinite || n.abs() > 10000)) {
        throw const FormatException('Invalid supply position');
      }
      return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    }

    nextIn = number(json, 'nextIn', 100);
    _random.state = json['random'] as int;
    previous = json['previous'] == null ? null : point(json['previous']);
    drop = null;
    if (json['drop'] case final Map raw) {
      final d = SupplyDrop(point(raw['position']));
      d.phase = SupplyPhase.values.byName(raw['phase'] as String);
      d.claimed = raw['claimed'] == true;
      d.elapsed = number(raw, 'elapsed', SupplyDrop.lifetime);
      d.capture = number(raw, 'capture', SupplyDrop.captureSeconds);
      d.life = number(raw, 'life', SupplyDrop.lifetime);
      final maximum = switch (d.phase) {
        SupplyPhase.warning => 1.8,
        SupplyPhase.falling => .65,
        SupplyPhase.active => SupplyDrop.lifetime,
        SupplyPhase.opened => 3.0,
        SupplyPhase.breaking => 1.3,
      };
      if (d.elapsed > maximum ||
          (d.phase == SupplyPhase.opened && (!d.claimed || d.capture < 8)) ||
          (d.phase == SupplyPhase.active &&
              (d.claimed || (d.elapsed - d.life).abs() > .001))) {
        throw const FormatException('Invalid supply phase');
      }
      drop = d;
    }
  }
}
