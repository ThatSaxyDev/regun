import 'dart:ui';

enum ArenaMachineKind {
  press(0.72, .24, 5.2),
  sluice(1.65, 2.7, 6.5),
  relay(1.1, .32, 6.2);

  const ArenaMachineKind(this.warning, this.active, this.cooldown);
  final double warning, active, cooldown;
}

class ArenaMachine {
  ArenaMachine(this.kind, this.body, this.area);

  final ArenaMachineKind kind;
  final Rect body, area;
  double _age = -1;
  bool _needsClear = false;

  bool get warning => _age >= 0 && _age < kind.warning;
  bool get active => _age >= kind.warning && _age < kind.warning + kind.active;
  bool get resetting => _age >= kind.warning + kind.active;
  bool get ready => _age < 0 && !_needsClear;
  double get warningProgress => (_age / kind.warning).clamp(0.0, 1.0);
  double get activeProgress =>
      ((_age - kind.warning) / kind.active).clamp(0.0, 1.0);
  double get resetProgress =>
      ((_age - kind.warning - kind.active) / kind.cooldown).clamp(0.0, 1.0);

  Rect get trigger => kind == ArenaMachineKind.relay
      ? Rect.fromLTRB(area.left, area.top, area.right, area.top + 90)
      : area;

  /// Return true only on the frame that crosses impact. Occupants must clear a
  /// pressure switch before it can arm again.
  bool advance(double dt, {required bool occupied}) {
    if (!occupied) _needsClear = false;
    if (_age < 0) {
      if (!occupied || _needsClear) return false;
      _age = 0;
      _needsClear = kind != ArenaMachineKind.sluice;
      return false;
    }
    final before = _age;
    _age += dt;
    final struck = before < kind.warning && _age >= kind.warning;
    if (_age >= kind.warning + kind.active + kind.cooldown) _age = -1;
    return struck;
  }

  List<Object> toJson() => [_age, _needsClear];

  void restore(Object? raw) {
    if (raw is! List || raw.length != 2) return;
    final age = raw.first;
    final clear = raw.last;
    if (age is! num ||
        !age.isFinite ||
        clear is! bool ||
        (age != -1 &&
            (age < 0 || age >= kind.warning + kind.active + kind.cooldown))) {
      return;
    }
    _age = age.toDouble();
    _needsClear = clear;
  }
}
