// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
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
    debugPrint(state.noOfBullets.toString());
  }

  void reloadBullets() async {
    state = state.copyWith(reloading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(
      noOfBullets: 5,
      reloading: false,
    );
  }

  void addBullets() async {
    state = state.copyWith(
      noOfBullets: 5,
    );
  }
}

class GameState {
  int score;
  GameplayState gameplayState;
  int noOfBullets;
  bool reloading;

  GameState({
    this.score = 0,
    this.gameplayState = GameplayState.playing,
    this.noOfBullets = 5,
    this.reloading = false,
  });

  GameState copyWith({
    int? score,
    GameplayState? gameplayState,
    int? noOfBullets,
    bool? reloading,
  }) {
    return GameState(
      score: score ?? this.score,
      gameplayState: gameplayState ?? this.gameplayState,
      noOfBullets: noOfBullets ?? this.noOfBullets,
      reloading: reloading ?? this.reloading,
    );
  }
}

enum GameplayState {
  playing,
  paused,
  gameOver,
}
