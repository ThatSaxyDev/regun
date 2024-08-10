import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:regun/constants.dart';
import 'package:regun/my_game.dart';
import 'package:regun/notifiers/score_notifier.dart';
import 'package:regun/widgets/click_button.dart';

class BaseView extends StatefulWidget {
  const BaseView({super.key});

  @override
  State<BaseView> createState() => _BaseViewState();
}

class _BaseViewState extends State<BaseView> {
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
                                _myGame.pauseGame();
                              },
                              icon: const Icon(
                                PhosphorIconsFill.pause,
                                size: 37,
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
                                        fontFamily: FontFam.orbitron,
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
                                  fontFamily: FontFam.pressStart,
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
                                      PhosphorIconsBold.repeat,
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
                      // height: height(context),
                      // width: width(context),
                      color: Colors.black45,
                      child: SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'GAME OVER',
                                style: TextStyle(
                                  fontFamily: FontFam.pressStart,
                                  fontSize: 40,
                                  // fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Score: ${ref.watch(gameNotifierProvider).score}',
                                style: const TextStyle(
                                  fontFamily: FontFam.orbitron,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClickButton(
                                    onTap: () {
                                      _myGame.resumeGame();
                                      _myGame.restartGame();
                                    },
                                    text: 'Restart',
                                    width: 100,
                                    height: 50,
                                  ),
                                  // IconButton(
                                  //   onPressed: () {
                                  //     _myGame.resumeGame();
                                  //     _myGame.restartGame();
                                  //   },
                                  //   icon: const Icon(
                                  //     PhosphorIconsBold.repeat,
                                  //     size: 60,
                                  //   ),
                                  // ),
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
