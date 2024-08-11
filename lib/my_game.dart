import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/boost_component.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/components/empty_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/game_joystick_component.dart';
import 'package:regun/components/player_component.dart';
import 'package:regun/notifiers/score_notifier.dart';

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale, RiverpodGameMixin {
  late PlayerComponent myPlayer;
  late final MovementJoystickComponent movementJoystick;
  late final WeaponJoystickComponent weaponJoystick;
  late final BoostButtonComponent boostButtonComponent;
  late GameState gameState;
  late GameNotifier gameNotifier;

  RegunGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 1500,
            height: 700,
          ),
        );

  @override
  Color backgroundColor() => const Color(0xff000000);

  @override
  FutureOr<void> onLoad() async {
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    boostButtonComponent = BoostButtonComponent();
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
    gameNotifier.resetScore();
    gameNotifier.playGame();
    gameNotifier.addBullets();
    add(boostButtonComponent);
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
    if (ref.read(gameNotifierProvider).reloading == true) {
      return;
    }

    if (ref.read(gameNotifierProvider).noOfBullets == 0) {
      gameNotifier.reloadBullets();
    }
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
    ref.read(gameNotifierProvider.notifier).decreaseBullets();
  }

  @override
  void onMount() {
    gameState = ref.watch(gameNotifierProvider);
    gameNotifier = ref.read(gameNotifierProvider.notifier);
    // debugMode = true;
    _initializeGamee();
    super.onMount();
  }

  @override
  void update(double dt) {
    // camera.viewfinder.zoom = 0.2;
    camera.viewfinder.position = myPlayer.position;

    // boostButtonComponent.onPressed;
    super.update(dt);
  }

  void gameOver() {
    pauseEngine();
    gameNotifier.gameOver();
    // _initializeGamee();
  }

  void restartGame() {
    for (var element in world.children) {
      element.removeFromParent();
    }
    _initializeGamee();
  }

  void pauseGame() {
    // (decorator as PaintDecorator).addBlur(8);
    pauseEngine();
    gameNotifier.pauseGame();
  }

  void resumeGame() {
    // (decorator as PaintDecorator).addBlur(0);
    resumeEngine();
    gameNotifier.playGame();
  }
}
