import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/my_game.dart';
import 'package:regun/notifiers/score_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.device.fullScreen();
  Flame.device.setLandscape();
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeView(),
      ),
    ),
  );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late RegunGame _myGame;
  final GlobalKey<RiverpodAwareGameWidgetState> gameWidgetKey =
      GlobalKey<RiverpodAwareGameWidgetState>();

  @override
  void initState() {
    super.initState();
    _myGame = RegunGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RiverpodAwareGameWidget(
            key: gameWidgetKey,
            game: _myGame,
          ),
          Consumer(
            builder: (context, ref, child) {
              return ref.watch(gameNotifierProvider).gameplayState ==
                      GameplayState.playing
                  ? SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_myGame.paused) {
                                  _myGame.resumeGame();
                                } else {
                                  _myGame.pauseGame();
                                }
                              },
                              icon: Icon(
                                _myGame.paused ? Icons.play_arrow : Icons.pause,
                                size: 40,
                              ),
                            ),

                            //! score
                            Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Consumer(
                                  builder: (context, ref, child) {
                                    return Text(
                                      'Score: ${ref.watch(gameNotifierProvider).score}',
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                )
                                //  ValueListenableBuilder(
                                //   valueListenable: _myGame.currentScore,
                                //   builder: (context, value, child) => Text(
                                //     'Score: $value',
                                //     style: const TextStyle(
                                //       fontSize: 25,
                                //       fontWeight: FontWeight.bold,
                                //     ),
                                //   ),
                                // ),
                                ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              return ref.watch(gameNotifierProvider).gameplayState ==
                      GameplayState.paused
                  ? Container(
                      color: Colors.black45,
                      child: SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'PAUSED',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _myGame.resumeGame();
                                    },
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 60,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _myGame.resumeGame();
                                      _myGame.restartGame();
                                    },
                                    icon: const Icon(
                                      Icons.restart_alt,
                                      size: 60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              return ref.watch(gameNotifierProvider).gameplayState ==
                      GameplayState.gameOver
                  ? Container(
                      color: Colors.black45,
                      child: SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'GAME OVER',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _myGame.resumeGame();
                                      _myGame.restartGame();
                                    },
                                    icon: const Icon(
                                      Icons.restart_alt,
                                      size: 60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
