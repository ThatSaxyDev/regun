import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/components/empty_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/game_joystick_component.dart';
import 'package:regun/components/player_component.dart';

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
  Color backgroundColor() => const Color(0xff000000);

  ValueNotifier<int> currentScore = ValueNotifier(0);

  @override
  FutureOr<void> onLoad() async {
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    camera.viewport.addAll([movementJoystick, weaponJoystick]);
    await FlameAudio.audioCache.loadAll([
      'gameov.wav',
      'hit.wav',
      'move.wav',
      'shoot.wav',
    ]);

    return super.onLoad();
  }

  void _initializeGamee() {
    currentScore.value = 0;
    world.add(myPlayer = PlayerComponent(
      position: Vector2.zero(),
    ));
    world.add(SpawnComponent(
      period: 0.4,
      selfPositioning: true,
      factory: (amount) {
        spawnShotgunBullets();
        return EmptyComponent();
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

  void spawnShotgunBullets() {
    final baseDirection = weaponJoystick.relativeDelta.normalized();
    if (baseDirection.isZero()) {
      return;
    }
    FlameAudio.play('shoot.wav');

    const spreadAngle = pi / 16;
    for (int i = -2; i <= 2; i++) {
      final angle = i * spreadAngle;
      final direction = baseDirection.clone()..rotate(angle);
      final bullet = BulletComponent(
        position: myPlayer.position.clone(),
        direction: direction,
      );

      world.add(bullet);
    }
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
