// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:regun/utils/soloud_play.dart';

final gameNotifierProvider = NotifierProvider<GameNotifier, GameState>(() {
  return GameNotifier();
});

class GameNotifier extends Notifier<GameState> {
  @override
  build() => GameState();

  void updateScore() {
    state = state.copyWith(score: state.score + 1);
  }

  void resetScore() {
    state = state.copyWith(
      score: 0,
      xP: 0,
      currentLevel: 1,
      noOfCoinsToUpgrade: 7,
    );
  }

  void pauseGame() {
    state = state.copyWith(gameplayState: GameplayState.paused);
  }

  void powerupState() {
    state = state.copyWith(gameplayState: GameplayState.powerup);
  }

  void playGame() {
    state = state.copyWith(gameplayState: GameplayState.playing);
  }

  void gameOver() {
    state = state.copyWith(gameplayState: GameplayState.gameOver);
  }

  void decreaseBullets() {
    state = state.copyWith(noOfBullets: state.noOfBullets - 1);
  }

  void reloadBullets() async {
    if (state.fastReload == true) {
      fastReloadBullets();
      return;
    }
    if (state.noOfBullets == state.maxBullets || state.reloading) return;

    state = state.copyWith(reloading: true);
    playReloadSound();

    const int baseReloadTime = 900;
    const int buffer = 700;
    final int bulletsToReload = state.maxBullets - state.noOfBullets;
    final int totalDelay = (buffer * (bulletsToReload - 1)) + baseReloadTime;

    await Future.delayed(Duration(milliseconds: totalDelay));

    state = state.copyWith(
      noOfBullets: state.maxBullets,
      reloading: false,
    );
  }

  void fastReloadBullets() async {
    if (state.noOfBullets == state.maxBullets || state.reloading) return;

    state = state.copyWith(reloading: true);

    // FlameAudio.play('reloadSound.mp3');
    ref.read(soloudPlayProvider).play('reloadSound.mp3');

    await Future.delayed(Duration(milliseconds: state.fastReloadTime));

    state = state.copyWith(
      noOfBullets: state.maxBullets,
      reloading: false,
    );
  }

  // void reloadBullets() async {
  //   if (state.noOfBullets == 8 || state.reloading == true) return;
  //   state = state.copyWith(reloading: true);
  //   playReloadSound();
  //   await Future.delayed(Duration(
  //       milliseconds: switch (state.noOfBullets) {
  //     7 => 900,
  //     6 => 1600,
  //     5 => 2300,
  //     4 => 3000,
  //     3 => 3700,
  //     2 => 4400,
  //     1 => 5100,
  //     _ => 5800,
  //   }));
  //   state = state.copyWith(
  //     noOfBullets: 8,
  //     reloading: false,
  //   );
  // }

  void playReloadSound() async {
    int missingBullets = state.maxBullets - state.noOfBullets;

    for (int i = 0; i < missingBullets; i++) {
      // FlameAudio.play('reloadSound.mp3');
      ref.read(soloudPlayProvider).play('reloadSound.mp3');
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  void addBullets() async {
    state = state.copyWith(
      noOfBullets: 5,
      maxBullets: 5,
    );
  }

  void reduceHealth() {
    state = state.copyWith(health: state.health - 1);
    // debugPrint(state.health.toString());
  }

  void increaseXP() {
    if (state.xP == state.noOfCoinsToUpgrade.floor()) {
      upgradeLevel();

      powerupState();
      return;
    }
    state = state.copyWith(xP: state.xP + 1);
    // debugPrint(
    //     'XP:${state.xP}, Coins2Up:${state.noOfCoinsToUpgrade}, Level:${state.currentLevel}');
  }

  void resetXP() {
    state = state.copyWith(xP: 0);
  }

  void upgradeLevel() async {
    state = state.copyWith(
      triggerEnemySpawn: true,
      xP: 0,
      currentLevel: state.currentLevel + 1,
      noOfCoinsToUpgrade: state.noOfCoinsToUpgrade * 1.2,
    );

    await Future.delayed(const Duration(milliseconds: 20)).whenComplete(() {
      state = state.copyWith(triggerEnemySpawn: false);
    });
  }

  //! POWER UPS
  //! increase max bullet
  void maxBulletsIncrease() async {
    state = state.copyWith(maxBullets: state.maxBullets + 2);
    await Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
      state = state.copyWith(noOfBullets: state.maxBullets);
    });
  }

  //! increase health
  void healthIncrease() {
    state = state.copyWith(health: state.health + 1);
  }

  void resetHealth() {
    state = state.copyWith(health: 3);
  }

  //! increase movement speed
  void walkingSpeedIncrease() {
    state = state.copyWith(movementSpeed: state.movementSpeed + 50);
  }

  void resetWalkingSpeed() {
    state = state.copyWith(movementSpeed: 300);
  }

  //! increase sprint distance
  void sprintDistanceIncrease() {
    state = state.copyWith(sprintTimeDistance: state.sprintTimeDistance + 15);
  }

  void resetSprintTimeDistance() {
    state = state.copyWith(sprintTimeDistance: 150);
  }

  //! increase bullet range
  void bulletRangeIncrease() {
    state = state.copyWith(bulletRange: state.bulletRange + 15);
  }

  void resetBulletRange() {
    state = state.copyWith(bulletRange: 420);
  }

  //! increase bullet number range
  void numberOfBulletsPerShotIncrease() {
    state = state.copyWith(
        bulletNumberRange: switch (state.bulletNumberRange) {
      >= 4 => 4,
      _ => state.bulletNumberRange + 1,
    });
  }

  void resetBulletNumberRange() {
    state = state.copyWith(bulletNumberRange: 1);
  }

  //! switch on fast reload
  void fastReload() {
    state = state.copyWith(
        fastReload: true,
        fastReloadTime: switch (state.fastReloadTime) {
          <= 1000 => state.fastReloadTime,
          _ => state.fastReloadTime - 500,
        });
  }

  void resetFastReload() {
    state = state.copyWith(
      fastReload: false,
      fastReloadTime: 2500,
    );
  }

  //! sprint invincibility
  void sprintInvincibility() {
    state = state.copyWith(sprintInvincibility: true);
  }

  void resetSprintInvincibility() {
    state = state.copyWith(sprintInvincibility: false);
  }

  void triggerSprintInvincibility() async {
    state = state.copyWith(triggerSprintInvincibility: true);
    await Future.delayed(Duration(milliseconds: state.sprintTimeDistance))
        .whenComplete(() {
      state = state.copyWith(triggerSprintInvincibility: false);
    });
  }

  void removeSprintInvincibilityTrigger() {
    state = state.copyWith(triggerSprintInvincibility: false);
  }

  //! bullets phase through
  void triggerBulletsPhaseThrough() {
    state = state.copyWith(bulletsPhaseThrough: true);
  }

  void resetBulletsPhaseThrough() {
    state = state.copyWith(bulletsPhaseThrough: false);
  }

  //! bullet fire rate
  void rapidFire() {
    state = state.copyWith(
        bulletSpeed: switch (state.bulletSpeed) {
      >= 1300 => state.bulletSpeed,
      _ => state.bulletSpeed + 200,
    });
  }

  void resetFireRate() {
    state = state.copyWith(bulletSpeed: 700);
  }

  //! sprint mine
  void sprintMine() {
    state = state.copyWith(triggerSprintMine: true);
  }

  void removeSprintMine() {
    state = state.copyWith(triggerSprintMine: false);
  }

  void decreaseSprintMineCount() {
    state = state.copyWith(
        sprintMineCount: switch (state.sprintMineCount) {
      > 0 => state.sprintMineCount - 1,
      _ => 0,
    });
  }

  void increaseSprintMineCount() {
    state = state.copyWith(
        sprintMineCount: switch (state.sprintMineCount) {
      < 3 => state.sprintMineCount + 1,
      _ => 3,
    });
  }

  void resetSprintMineCount() {
    state = state.copyWith(sprintMineCount: 3);
  }
}

class GameState {
  int score;
  GameplayState gameplayState;
  int maxBullets;
  int noOfBullets;
  bool reloading;
  int health;
  int xP;
  int currentLevel;
  double noOfCoinsToUpgrade;
  double movementSpeed;
  int sprintTimeDistance;
  int bulletRange;
  int bulletNumberRange;
  bool fastReload;
  int fastReloadTime;
  bool sprintInvincibility;
  bool triggerSprintInvincibility;
  bool bulletsPhaseThrough;
  double bulletSpeed;
  bool triggerSprintMine;
  int sprintMineCount;
  bool triggerEnemySpawn;

  GameState({
    this.score = 0,
    this.gameplayState = GameplayState.playing,
    this.maxBullets = 5,
    this.noOfBullets = 5,
    this.reloading = false,
    this.health = 3,
    this.xP = 0,
    this.currentLevel = 1,
    this.noOfCoinsToUpgrade = 7,
    this.movementSpeed = 300.0,
    this.sprintTimeDistance = 150,
    this.bulletRange = 420,
    this.bulletNumberRange = 1,
    this.fastReload = false,
    this.fastReloadTime = 2500,
    this.sprintInvincibility = false,
    this.triggerSprintInvincibility = false,
    this.bulletsPhaseThrough = false,
    this.bulletSpeed = 700,
    this.triggerSprintMine = false,
    this.sprintMineCount = 3,
    this.triggerEnemySpawn = false,
  });

  GameState copyWith({
    int? score,
    GameplayState? gameplayState,
    int? maxBullets,
    int? noOfBullets,
    bool? reloading,
    int? health,
    int? xP,
    int? currentLevel,
    double? noOfCoinsToUpgrade,
    double? movementSpeed,
    int? sprintTimeDistance,
    int? bulletRange,
    int? bulletNumberRange,
    bool? fastReload,
    int? fastReloadTime,
    bool? sprintInvincibility,
    bool? triggerSprintInvincibility,
    bool? bulletsPhaseThrough,
    double? bulletSpeed,
    bool? triggerSprintMine,
    int? sprintMineCount,
    bool? triggerEnemySpawn,
  }) {
    return GameState(
      score: score ?? this.score,
      gameplayState: gameplayState ?? this.gameplayState,
      maxBullets: maxBullets ?? this.maxBullets,
      noOfBullets: noOfBullets ?? this.noOfBullets,
      reloading: reloading ?? this.reloading,
      health: health ?? this.health,
      xP: xP ?? this.xP,
      currentLevel: currentLevel ?? this.currentLevel,
      noOfCoinsToUpgrade: noOfCoinsToUpgrade ?? this.noOfCoinsToUpgrade,
      movementSpeed: movementSpeed ?? this.movementSpeed,
      sprintTimeDistance: sprintTimeDistance ?? this.sprintTimeDistance,
      bulletRange: bulletRange ?? this.bulletRange,
      bulletNumberRange: bulletNumberRange ?? this.bulletNumberRange,
      fastReload: fastReload ?? this.fastReload,
      fastReloadTime: fastReloadTime ?? this.fastReloadTime,
      sprintInvincibility: sprintInvincibility ?? this.sprintInvincibility,
      triggerSprintInvincibility:
          triggerSprintInvincibility ?? this.triggerSprintInvincibility,
      bulletsPhaseThrough: bulletsPhaseThrough ?? this.bulletsPhaseThrough,
      bulletSpeed: bulletSpeed ?? this.bulletSpeed,
      triggerSprintMine: triggerSprintMine ?? this.triggerSprintMine,
      sprintMineCount: sprintMineCount ?? this.sprintMineCount,
      triggerEnemySpawn: triggerEnemySpawn ?? this.triggerEnemySpawn,
    );
  }
}

enum GameplayState {
  playing,
  paused,
  gameOver,
  powerup,
}

enum PowerUp {
  maxBulletsIncrease('Increase max bullets'),
  sprintMine('Sprinting plants a mine'),
  sprintInvincibility('Invincible while sprinting'),
  walkingSpeedIncrease('Increase movement speed '),
  sprintDistanceIncrease('Increase sprint distance'),
  fastReload('Fast reload'),
  numberOfBulletsPerShotIncrease('Increase bullets per shot'),
  bulletRangeIncrease('Increase range of bullets'),
  bulletsPhaseThrough('Bullets phase through enemies'),
  rapidFire('Increase bullet speed'),
  healthIncrease('Increase health');

  const PowerUp(this.title);
  final String title;
}

List<PowerUp> powerUps = [
  // PowerUp.sprintMine,
  PowerUp.sprintInvincibility,
  PowerUp.fastReload,
  PowerUp.numberOfBulletsPerShotIncrease,
  PowerUp.bulletRangeIncrease,
  PowerUp.walkingSpeedIncrease,
  PowerUp.sprintDistanceIncrease,
  PowerUp.maxBulletsIncrease,
  PowerUp.healthIncrease,
  PowerUp.bulletsPhaseThrough,
  PowerUp.rapidFire,
];

Future<List<PowerUp>> pickTwoRandomPowerUps() async {
  // await Future.delayed(const Duration(seconds: 2)); // Simulate some delay
  powerUps.shuffle();
  if (powerUps.length < 2) {
    throw ArgumentError('The list must contain at least 2 items.');
  }

  final random = Random();
  final firstIndex = random.nextInt(powerUps.length);

  int secondIndex;
  do {
    secondIndex = random.nextInt(powerUps.length);
  } while (secondIndex == firstIndex);

  return [powerUps[firstIndex], powerUps[secondIndex]];
}
