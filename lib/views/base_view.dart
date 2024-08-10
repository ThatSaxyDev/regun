import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:regun/utils/app_extensions.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/my_game.dart';
import 'package:regun/notifiers/score_notifier.dart';
import 'package:regun/theme/palette.dart';
import 'package:regun/widgets/click_button.dart';
import "package:flutter_animate/flutter_animate.dart";

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
                            ).fadeInFromTop(delay: 0.ms),

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
                                    ).fadeInFromTop(delay: 0.ms);
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
                              ).fadeInFromTop(delay: 0.ms),
                              const SizedBox(
                                height: 20,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClickButton(
                                    onTap: () {
                                      _myGame.resumeGame();
                                    },
                                    text: 'Resume',
                                    width: 100,
                                    height: 50,
                                  ).fadeInFromBottom(delay: 100.ms),
                                  const SizedBox(
                                    width: 30,
                                  ),
                                  ClickButton(
                                    onTap: () {
                                      _myGame.resumeGame();
                                      _myGame.restartGame();
                                    },
                                    buttonColor: Palette.buttonRed,
                                    buttonShadow: Palette.buttonShadowRed,
                                    text: 'Restart',
                                    width: 100,
                                    height: 50,
                                  ).fadeInFromBottom(delay: 100.ms),
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
                                    color: Palette.redColor
                                    // fontWeight: FontWeight.bold,
                                    ),
                              ).fadeInFromTop(delay: 0.ms),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'Score: ${ref.watch(gameNotifierProvider).score}',
                                style: const TextStyle(
                                  fontFamily: FontFam.orbitron,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ).fadeIn(delay: 0.ms),
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
                                  ).fadeInFromBottom(delay: 100.ms),
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
