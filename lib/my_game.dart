import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/game_joystick.dart';
import 'package:regun/components/player_component.dart';

class RegunGame extends FlameGame with HasCollisionDetection {
  late PlayerComponent myPlayer;
  late final MovementJoystick movementJoystick;
  // final Random _random = Random();
  RegunGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 1500,
            height: 700,
          ),
        );

  @override
  Color backgroundColor() => const Color(0xff222222);

  @override
  FutureOr<void> onLoad() async {
    movementJoystick = MovementJoystick();
    camera.viewport.add(movementJoystick);
    return super.onLoad();
  }

  @override
  void onMount() {
    // debugMode = true;

    world.add(myPlayer = PlayerComponent(
      position: Vector2.zero(),
    ));
    world.add(
      SpawnComponent(
        factory: (index) {
          return EnemyComponent();
        },
        period: 0.2,
        within: false,
        area: Rectangle.fromCenter(
          center: myPlayer.position,
          size: Vector2(size.x * 3, size.x * 3),
        ),
      ),
    );
    world.add(BorderComponent(size: size * 3));
    super.onMount();
  }

  @override
  void update(double dt) {
    // camera.viewfinder.zoom = 0.2;
    camera.viewfinder.position = myPlayer.position;
    super.update(dt);
  }
}
