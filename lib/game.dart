import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/components/movement/boost_component.dart';
import 'package:regun/components/ui/border_component.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/game_utils/empty_component.dart';
import 'package:regun/components/movement/game_joystick_component.dart';
import 'package:regun/components/game_utils/player_component.dart';
import 'package:regun/components/weapons/mine_component.dart';
import 'package:regun/notifiers/game_notifier.dart';

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale, RiverpodGameMixin {
  late PlayerComponent myPlayer;
  // late SpawnComponent coinSpawn;
  late final MovementJoystickComponent movementJoystick;
  late final WeaponJoystickComponent weaponJoystick;
  late final BoostButtonComponent boostButtonComponent;
  late GameState gameState;
  late GameNotifier gameNotifier;
  double bulletFireRate = 0.35;
  BuildContext context;
  late Size screenSize;
  late Vector2 centerOfScreen;

  RegunGame(this.context)
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
    screenSize = MediaQuery.of(context).size;
    centerOfScreen = Vector2(screenSize.width / 2, screenSize.height / 2);
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    boostButtonComponent = BoostButtonComponent();
    camera.viewport.addAll([movementJoystick, weaponJoystick]);
    // await FlameAudio.audioCache.loadAll([
    //   'gameov.wav',
    //   'hit.wav',
    //   'move.wav',
    //   'shoot.wav',
    //   'coinSound1.mp3',
    //   'coinSound2.wav',
    // ]);

    return super.onLoad();
  }

  void _initializeGamee() {
    final rnd = Random();
    Vector2 randomVector2() => (Vector2.random(rnd) - Vector2.random(rnd)) * 80;
    gameNotifier.resetScore();
    gameNotifier.playGame();
    gameNotifier.addBullets();
    gameNotifier.resetHealth();
    gameNotifier.resetWalkingSpeed();
    gameNotifier.resetSprintTimeDistance();
    gameNotifier.resetBulletRange();
    gameNotifier.resetBulletNumberRange();
    gameNotifier.resetFastReload();
    gameNotifier.resetSprintInvincibility();
    gameNotifier.removeSprintInvincibilityTrigger();
    gameNotifier.resetBulletsPhaseThrough();
    gameNotifier.resetFireRate();
    add(boostButtonComponent);
    world.add(myPlayer = PlayerComponent(
      position: Vector2.zero(),
    ));
    world.add(SpawnComponent(
      period: bulletFireRate,
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
        period: 0.7,
        within: false,
        area: Rectangle.fromCenter(
          center: myPlayer.position,
          size: Vector2(size.x * 3, size.x * 3),
        ),
      ),
    );
    world.add(
      SpawnComponent(
        factory: (index) {
          return Enemy2Component();
        },
        period: 1.5,
        within: false,
        area: Rectangle.fromCenter(
          center: myPlayer.position,
          size: Vector2(size.x * 3, size.x * 3),
        ),
      ),
    );
    world.add(BorderComponent(size: size * 3));
    world.add(
      SpawnComponent(
        factory: (index) {
          return CoinComponent(position: randomVector2());
        },
        period: 0.5,
        within: true,
        area: Rectangle.fromCenter(
          center: myPlayer.position,
          size: Vector2(size.x * 3, size.x * 3),
        ),
      ),
    );
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
    // FlameAudio.play('shoot.wav');

    const spreadAngle = pi / 20;
    for (int i = -(ref.read(gameNotifierProvider).bulletNumberRange);
        i <= ref.read(gameNotifierProvider).bulletNumberRange;
        i++) {
      final angle = i * spreadAngle;
      final direction = baseDirection.clone()..rotate(angle);
      final bulletAngle = -direction.angleToSigned(Vector2(1, 0));
      final bullet = BulletComponent(
        position: myPlayer.position.clone(),
        direction: direction,
        angle: bulletAngle,
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

  void removeCoinsAndEnemies() {
    for (var element in world.children) {
      if (
          // element is EnemyComponent ||
          element is CoinComponent
          // ||
          // element is Enemy2Component
          ) {
        element.removeFromParent();
      }
    }
  }

  void slow() {
    timeScale = 0.1;
  }

  void normalizeGameSpeed() {
    timeScale = 1.0;
  }

  void pauseGame() {
    // (decorator as PaintDecorator).addBlur(8);
    pauseEngine();
    ref.read(gameNotifierProvider.notifier).pauseGame();
  }

  void resumeGame() {
    // (decorator as PaintDecorator).addBlur(0);
    resumeEngine();
    ref.read(gameNotifierProvider.notifier).playGame();
  }

  //! add mine
  void addMine() {
    world.add(
      MineComponent(
        position: myPlayer.position.clone(),
      ),
    );
  }
}
