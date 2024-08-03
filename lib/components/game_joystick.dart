import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

class GameJoystick extends JoystickComponent {
  GameJoystick()
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
