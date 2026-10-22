import 'dart:async';

/// Send state edges without waiting for a network round trip. Bounded requests
/// and a 150ms keepalive preserve the server's 250ms stale-input safety window.
class CombatInputPump {
  int _epoch = 0, _serial = 0;
  int inFlight = 0;
  double _at = double.negativeInfinity;
  (bool, int, int)? _sent;
  bool _retry = false;

  void reset() {
    _epoch++;
    inFlight = 0;
    _at = double.negativeInfinity;
    _sent = null;
    _retry = false;
  }

  void tick(
    double now,
    bool firing,
    int reload,
    Future<bool> Function(bool firing, int reload) send, {
    int burst = 0,
  }) {
    final state = (firing, reload, burst);
    if (inFlight >= 6 ||
        now - _at < .049 ||
        (!_retry && state == _sent && now - _at < .149)) {
      return;
    }
    _at = now;
    _sent = state;
    _retry = false;
    final epoch = _epoch, serial = ++_serial;
    inFlight++;
    unawaited(() async {
      var accepted = false;
      try {
        accepted = await send(firing, reload);
      } catch (_) {
        // The session handles transport failure; the pump never leaks errors.
      } finally {
        if (_epoch == epoch) {
          inFlight--;
          if (!accepted && serial == _serial) _retry = true;
        }
      }
    }());
  }
}
