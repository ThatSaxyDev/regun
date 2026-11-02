import 'dart:ui';

/// Ground locomotion follows accepted travel, not a shared animation clock.
/// Duplicate/held authoritative snapshots cannot advance feet.
class TravelGait {
  TravelGait({int phase = 0}) : distance = (phase % 4) * 5.0;
  double distance;
  Offset? _position;
  double? _age;
  bool moving = false;
  int get frame => moving ? (distance / 5).floor() % 4 : 0;
  static int phaseFor(String key) {
    var hash = 0;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash % 4;
  }

  void sample(Offset position, double age) {
    if (_age != null && age <= _age!) return;
    final travel = _position == null ? 0.0 : (position - _position!).distance;
    _position = position;
    _age = age;
    moving = travel > .02 && travel < 120;
    if (moving) distance = (distance + travel) % 20;
  }
}
