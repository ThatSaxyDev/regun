import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/components/map/map_component.dart';
import 'package:regun/components/movement/boost_component.dart';
import 'package:regun/components/ui/border_component.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/game_utils/empty_component.dart';
import 'package:regun/components/movement/game_joystick_component.dart';
import 'package:regun/components/game_utils/player_component.dart';
import 'package:regun/components/weapons/mine_component.dart';
import 'package:regun/components/weapons/reload_component.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class RegunGame extends FlameGame
    with HasCollisionDetection, HasDecorator, HasTimeScale, RiverpodGameMixin {
  late PlayerComponent myPlayer;
  // late SpawnComponent coinSpawn;
  late final MovementJoystickComponent movementJoystick;
  late final WeaponJoystickComponent weaponJoystick;
  late final BoostButtonComponent boostButtonComponent;
  late final ReloadButtonComponent reloadButtonComponent;
  late GameState gameState;
  late GameNotifier gameNotifier;
  double bulletFireRate = 0.35;
  BuildContext context;
  late Size screenSize;
  late Vector2 centerOfScreen;
  late final MapComponent map;

  RegunGame(this.context)
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 1500,
            height: 700,
          ),
        );

  @override
  Color backgroundColor() => const Color.fromRGBO(8, 5, 8, 1);

  @override
  FutureOr<void> onLoad() async {
    map = MapComponent();
    screenSize = MediaQuery.of(context).size;
    centerOfScreen = Vector2(screenSize.width / 2, screenSize.height / 2);
    movementJoystick = MovementJoystickComponent();
    weaponJoystick = WeaponJoystickComponent();
    boostButtonComponent = BoostButtonComponent();
    reloadButtonComponent = ReloadButtonComponent();
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
    gameNotifier.removeSprintMine();
    gameNotifier.resetSprintMineCount();
    add(boostButtonComponent);
    add(reloadButtonComponent);
    world.add(myPlayer = PlayerComponent(
      position: Vector2.zero(),
    ));
    // world.add(ShadowBossComponent(
    //   position: Vector2(-600, 0),
    // ));
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
          center: Vector2.zero(),
          size: Vector2(size.x * 2.93, size.x * 2.93),
        ),
      ),
    );

    // Future.delayed(const Duration(seconds: 5)).whenComplete(() {});
    // world.add(
    //   SpawnComponent(
    //     factory: (index) {
    //       return Enemy2Component();
    //     },
    //     period: 1.5,
    //     within: false,
    //     area: Rectangle.fromCenter(
    //       center: myPlayer.position,
    //       size: Vector2(size.x * 2.93, size.x * 2.93),
    //     ),
    //   ),
    // );
    // world.add(
    //   SpawnComponent(
    //     factory: (index) {
    //       return Enemy3Component();
    //     },
    //     period: 3,
    //     within: false,
    //     area: Rectangle.fromCenter(
    //       center: myPlayer.position,
    //       size: Vector2(size.x * 2.93, size.x * 2.93),
    //     ),
    //   ),
    // );
    world.add(BorderComponent(size: size * 3));
    world.add(MapComponent()..position = Vector2(-2256, -2256));
    world.add(
      SpawnComponent(
        factory: (index) {
          return CoinComponent(position: randomVector2());
        },
        period: 0.5,
        within: true,
        area: Rectangle.fromCenter(
          center: myPlayer.position,
          size: Vector2(size.x * 2.93, size.x * 2.93),
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
    // soloudPlay.play('shoot.wav');
    ref.read(soloudPlayProvider).play('shoot.wav');

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
    // camera.viewfinder.zoom = 0.05;
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
    gameNotifier.pauseGame();
  }

  void resumeGame() {
    // (decorator as PaintDecorator).addBlur(0);
    resumeEngine();
    gameNotifier.playGame();
  }

  //! add mine
  void addMine() {
    world.add(
      MineComponent(
        position: myPlayer.position.clone(),
      ),
    );
  }

  //! add enemy 2
  void addEnemy2Component() {
    debugPrint('enemy 2 added');
    world.add(
      SpawnComponent(
        factory: (index) {
          return Enemy2Component();
        },
        period: 1.5,
        within: false,
        area: Rectangle.fromCenter(
          center: Vector2.zero(),
          size: Vector2(size.x * 2.93, size.x * 2.93),
        ),
      ),
    );
  }

  //! add enemy 3
  void addEnemy3Component() {
    debugPrint('enemy 3 added');
    world.add(
      SpawnComponent(
        factory: (index) {
          return Enemy3Component();
        },
        period: 3,
        within: false,
        area: Rectangle.fromCenter(
          center: Vector2.zero(),
          size: Vector2(size.x * 2.93, size.x * 2.93),
        ),
      ),
    );
  }
}
