// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    state = state.copyWith(score: 0);
  }

  void pauseGame() {
    state = state.copyWith(gameplayState: GameplayState.paused);
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
    if (state.noOfBullets == state.maxBullets || state.reloading) return;

    state = state.copyWith(reloading: true);
    playReloadSound();

    const int baseReloadTime = 700;
    final int bulletsToReload = state.maxBullets - state.noOfBullets;
    final int totalDelay = bulletsToReload * baseReloadTime;

    await Future.delayed(Duration(milliseconds: totalDelay));

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
    int missingBullets = 8 - state.noOfBullets;

    for (int i = 0; i < missingBullets; i++) {
      FlameAudio.play('reloadSound.mp3');
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  void addBullets() async {
    state = state.copyWith(
      noOfBullets: 8,
    );
  }

  void reduceHealth() {
    state = state.copyWith(health: state.health - 1);
    // debugPrint(state.health.toString());
  }

  void resetHealth() {
    state = state.copyWith(health: 3);
  }
}

class GameState {
  int score;
  GameplayState gameplayState;
  int maxBullets;
  int noOfBullets;
  bool reloading;
  int health;

  GameState({
    this.score = 0,
    this.gameplayState = GameplayState.playing,
    this.maxBullets = 8,
    this.noOfBullets = 8,
    this.reloading = false,
    this.health = 3,
  });

  GameState copyWith({
    int? score,
    GameplayState? gameplayState,
    int? maxBullets,
    int? noOfBullets,
    bool? reloading,
    int? health,
  }) {
    return GameState(
      score: score ?? this.score,
      gameplayState: gameplayState ?? this.gameplayState,
      maxBullets: maxBullets ?? this.maxBullets,
      noOfBullets: noOfBullets ?? this.noOfBullets,
      reloading: reloading ?? this.reloading,
      health: health ?? this.health,
    );
  }
}

enum GameplayState {
  playing,
  paused,
  gameOver,
}
