/// Limits desktop game painting while preserving elapsed simulation time.
class DesktopFramePacer {
  double _elapsed = 0;
  double _phase = 0;
  bool _started = false;

  double? advance(double dt, int ceiling) {
    if (!_started || dt == 0) {
      _started = true;
      _elapsed = _phase = 0;
      return dt;
    }
    final interval = 1 / ceiling;
    _elapsed += dt;
    _phase += dt;
    if (_phase + .0003 < interval) return null;
    _phase = (_phase - interval).clamp(-.0003, interval);
    final elapsed = _elapsed;
    _elapsed = 0;
    return elapsed;
  }
}
