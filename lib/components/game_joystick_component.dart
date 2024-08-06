import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

class MovementJoystickComponent extends JoystickComponent {
  MovementJoystickComponent()
      : super(
          knob: CircleComponent(
            radius: 40,
            paint: BasicPalette.blue.withAlpha(150).paint(),
          ),
          margin: const EdgeInsets.only(left: 150, bottom: 100),
          background: CircleComponent(
            radius: 120,
            paint: BasicPalette.darkGray.withAlpha(30).paint(),
          ),
        );

  // @override
  // bool onDragUpdate(DragUpdateEvent event) {
  //   FlameAudio.play('move.wav', volume: 0.4);
  //   return super.onDragUpdate(event);
  // }
}

class WeaponJoystickComponent extends JoystickComponent {
  WeaponJoystickComponent()
      : super(
          knob: CircleComponent(
            radius: 40,
            paint: BasicPalette.red.withAlpha(100).paint(),
          ),
          margin: const EdgeInsets.only(right: 150, bottom: 100),
          background: CircleComponent(
            radius: 120,
            paint: BasicPalette.darkGray.withAlpha(30).paint(),
          ),
        );
}
