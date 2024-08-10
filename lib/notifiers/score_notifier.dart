// ignore_for_file: public_member_api_docs, sort_constructors_first
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
}

class GameState {
  int score;
  GameplayState gameplayState;

  GameState({
    this.score = 0,
    this.gameplayState = GameplayState.playing,
  });

  GameState copyWith({
    int? score,
    GameplayState? gameplayState,
  }) {
    return GameState(
      score: score ?? this.score,
      gameplayState: gameplayState ?? this.gameplayState,
    );
  }
}

enum GameplayState {
  playing,
  paused,
  gameOver,
}
