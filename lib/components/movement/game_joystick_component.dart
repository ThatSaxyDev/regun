import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

class MovementJoystickComponent extends JoystickComponent {
  MovementJoystickComponent()
      : super(
          knob: JoyStickKnob(knobSize: 130),
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
          knob: JoyStickKnob(knobSize: 120),
          margin: const EdgeInsets.only(right: 150, bottom: 150),
          background: CircleComponent(
            radius: 80,
            paint: BasicPalette.darkGray.withAlpha(30).paint(),
          ),
        );
}

//! joystick knob
class JoyStickKnob extends PositionComponent {
  late Sprite _knobSprite;
  late double knobSize;

  JoyStickKnob({
    required this.knobSize,
  });

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    await super.onLoad();
    _knobSprite = await Sprite.load(
      'joystick.png',
      srcSize: Vector2.all(16),
    );
  }

  @override
  void render(Canvas canvas) {
    _knobSprite.render(
      canvas,
      size: Vector2.all(knobSize),
      anchor: Anchor.center,
    );
  }
}
