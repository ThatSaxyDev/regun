import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/game_joystick.dart';
import 'package:regun/components/player_component.dart';

class RegunGame extends FlameGame with HasCollisionDetection {
  late PlayerComponent myPlayer;
  late final GameJoystick gameJoystick;
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
    gameJoystick = GameJoystick();
    camera.viewport.add(gameJoystick);
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
        area: Rectangle.fromCenter(center: Vector2.zero(), size: size),
      ),
    );
    super.onMount();
  }

  // @override
  // void update(double dt) {
  //   camera.viewfinder.zoom = 0.3;
  //   super.update(dt);
  // }
}
