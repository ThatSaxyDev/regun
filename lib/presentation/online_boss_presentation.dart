import 'dart:ui';

import 'package:regun/multiplayer/combat_state.dart';

/// Local interpolation of a bounded server-owned hold. Never holds combat itself.
class OnlineBossPresentation {
  String? _scope;
  int? _serial;
  double elapsed = 0, duration = 2.65, zoom = 1;
  double _remaining = -1, _sampleAge = 0;
  bool holding = false;
  List<OnlineEntity> actors = [];
  Offset? _from;

  void sync(
    String scope,
    OnlineMatch? match,
    List<OnlineEntity> scene,
    double dt, {
    required bool reducedMotion,
  }) {
    if (_scope != scope) {
      _scope = scope;
      _serial = null;
      zoom = 1;
      _from = null;
    }
    holding = match?.phase == 'boss_reveal';
    final arrival = match?.data['bossArrival'];
    if (holding && arrival is Map && arrival['actors'] is List) {
      final serial = (arrival['serial'] as num).toInt();
      if (serial != _serial) {
        _serial = serial;
        _from = null;
        _remaining = -1;
      }
      duration = (arrival['duration'] as num).toDouble();
      final remaining = match!.phaseSeconds;
      if (remaining != _remaining) {
        _remaining = remaining;
        _sampleAge = 0;
      } else {
        // At most one server interval of cosmetic interpolation, never free-run
        // through a disconnect or asset stall and then replay the entrance.
        _sampleAge = (_sampleAge + dt).clamp(0, .05);
      }
      elapsed = (duration - remaining + _sampleAge).clamp(0, duration);
      actors = (arrival['actors'] as List)
          .map(
            (a) => OnlineEntity((a as Map)['key'] as String, 'enemy', {
              ...Map<String, dynamic>.from(a),
              'boss': true,
            }),
          )
          .toList();
    } else {
      actors = [];
      _from = null;
    }
    final alive = scene.any(
      (e) => e.data['boss'] == true && e.number('health') > 0,
    );
    final target = alive ? .88 : 1.0;
    if (!holding || elapsed > duration - .6) {
      zoom = reducedMotion
          ? target
          : lerpDouble(zoom, target, (dt * 2.5).clamp(0, 1))!;
    }
  }

  Offset get focus => actors.isEmpty
      ? Offset.zero
      : actors.map((e) => Offset(e.x, e.y)).reduce((a, b) => a + b) /
            actors.length.toDouble();
  Offset camera(Offset player, {required bool reducedMotion}) {
    if (!holding || actors.isEmpty || reducedMotion) return player;
    _from ??= player;
    double ease(double t) {
      t = t.clamp(0, 1);
      return t * t * (3 - 2 * t);
    }

    if (elapsed < .65) return Offset.lerp(_from, focus, ease(elapsed / .65))!;
    if (elapsed < duration - .6) return focus;
    return Offset.lerp(focus, player, ease((elapsed - duration + .6) / .6))!;
  }

  double get opacity => ((elapsed - 1.05) / .65).clamp(0, 1);
  double get seal => (elapsed / .95).clamp(0, 1);
  double get fade => ((duration - elapsed) / .6).clamp(0, 1);
}
