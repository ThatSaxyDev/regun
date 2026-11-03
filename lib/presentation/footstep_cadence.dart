/// A short first stride makes movement feel planted. Subsequent contacts follow
/// distance traveled, so slow movement, collision and input release stay quiet.
class FootstepCadence {
  static const _stride = 92.0;
  double _distance = 0;
  bool _firstContact = true;
  int _variant = 0;

  void reset() {
    _distance = 0;
    _firstContact = true;
  }

  int? advance(double distance) {
    if (distance < .05) {
      reset();
      return null;
    }
    _distance += distance;
    final threshold = _firstContact ? _stride / 2 : _stride;
    if (_distance < threshold) return null;
    _firstContact = false;
    _distance = (_distance - threshold) % _stride;
    return _variant++ % 3;
  }
}
