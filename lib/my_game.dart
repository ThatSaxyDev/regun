import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/game_joystick_component.dart';
import 'package:regun/components/player_component.dart';
import 'package:flame/rendering.dart';

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale {
  late PlayerComponent myPlayer;
  late final MovementJoystickComponent movementJoystick;
  late final WeaponJoystickComponent weaponJoystick;
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

  ValueNotifier<int> currentScore = ValueNotifier(0);

  @override
  FutureOr<void> onLoad() async {
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    camera.viewport.addAll([movementJoystick, weaponJoystick]);
    return super.onLoad();
  }

  void _initializeGamee() {
    currentScore.value = 0;
    world.add(myPlayer = PlayerComponent(
      position: Vector2.zero(),
    ));
    world.add(SpawnComponent(
      period: 0.2,
      selfPositioning: true,
      factory: (amount) {
        return BulletComponent(
          position: myPlayer.position,
          direction: weaponJoystick.delta.normalized(),
        );
      },
      autoStart: true,
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
  }

  @override
  void onMount() {
    // debugMode = true;
    _initializeGamee();
    super.onMount();
  }

  @override
  void update(double dt) {
    // camera.viewfinder.zoom = 0.2;
    camera.viewfinder.position = myPlayer.position;
    super.update(dt);
  }

  void gameOver() {
    for (var element in world.children) {
      element.removeFromParent();
    }
    _initializeGamee();
  }

  bool get isGamePaused => timeScale == 0.0;

  bool get isGamePlaying => !isGamePaused;

  void pauseGame() {
    // (decorator as PaintDecorator).addBlur(8);
    timeScale = 0.0;
  }

  void resumeGame() {
    // (decorator as PaintDecorator).addBlur(0);
    timeScale = 1;
  }

  void increaseScore() {
    currentScore.value++;
  }
}
