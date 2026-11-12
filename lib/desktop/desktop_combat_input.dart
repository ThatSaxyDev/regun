import 'package:flame/components.dart';
import 'package:flutter/services.dart';

enum DesktopAction {
  up(PhysicalKeyboardKey.keyW),
  down(PhysicalKeyboardKey.keyS),
  left(PhysicalKeyboardKey.keyA),
  right(PhysicalKeyboardKey.keyD),
  dash(PhysicalKeyboardKey.space),
  reload(PhysicalKeyboardKey.keyR),
  grenade(PhysicalKeyboardKey.keyG),
  fire(PhysicalKeyboardKey.keyF);

  const DesktopAction(this.defaultKey);
  final PhysicalKeyboardKey defaultKey;
}

class DesktopCombatInput {
  bool active = true;
  bool controller = false;
  Offset? pointer;
  final movement = Vector2.zero();
  final stickAim = Vector2.zero();
  bool stickAiming = false;
  bool _fireHeld = false;
  bool _firePressed = false;
  bool get fire => _fireHeld || _firePressed;
  set fire(bool held) {
    if (held && !_fireHeld) _firePressed = true;
    _fireHeld = held;
  }

  void consumeFirePress() => _firePressed = false;
  void cancelFire() => _fireHeld = _firePressed = false;

  bool grenade = false;
  double controllerGrenadePower = 1;
  int epoch = 0;

  void reset() {
    movement.setZero();
    stickAim.setZero();
    stickAiming = false;
    cancelFire();
    grenade = false;
    controllerGrenadePower = 1;
    epoch++;
  }
}
