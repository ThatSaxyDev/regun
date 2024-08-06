import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

class MovementJoystickComponent extends JoystickComponent {
  MovementJoystickComponent()
      : super(
          knob: CircleComponent(
            radius: 40,
            paint: BasicPalette.red.withAlpha(150).paint(),
          ),
          margin: const EdgeInsets.only(left: 140, bottom: 80),
          background: CircleComponent(
            radius: 120,
            paint: BasicPalette.black.withAlpha(100).paint(),
          ),
        );
}

class WeaponJoystick extends JoystickComponent {
  WeaponJoystick()
      : super(
          knob: CircleComponent(
            radius: 40,
            paint: BasicPalette.blue.withAlpha(100).paint(),
          ),
          margin: const EdgeInsets.only(right: 140, bottom: 80),
          background: CircleComponent(
            radius: 120,
            paint: BasicPalette.black.withAlpha(100).paint(),
          ),
        );
}
