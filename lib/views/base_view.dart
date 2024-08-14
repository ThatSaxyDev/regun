import 'dart:math';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flextras/flextras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:regun/utils/app_extensions.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/theme/palette.dart';
import 'package:regun/utils/nav.dart';
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
  late final Widget lottieWidget;

  @override
  void initState() {
    super.initState();
    _myGame = RegunGame();
    lottieWidget = Lottie.asset('assets/lottie/reload.json');
  }

  Color getPowerUpColor(double length) {
    if (length < width(context) * 0.25) {
      return Colors.red;
    } else if (length < width(context) * 0.5) {
      return Colors.orange;
    } else if (length < width(context) * 0.75) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
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
              GameState gameState = ref.watch(gameNotifierProvider);
              final powerUpLength = width(context) *
                  (gameState.xP / gameState.noOfCoinsToUpgrade.floor());
              return gameState.gameplayState == GameplayState.playing
                  ? SafeArea(
                      bottom: false,
                      top: false,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: 5,
                              width: powerUpLength,
                              color: getPowerUpColor(powerUpLength),
                            ),
                          ),
                          Row(
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
                                      return Row(
                                        children: [
                                          Image.asset(
                                            'assets/images/heart.png',
                                            height: 30,
                                            width: 30,
                                          ).fadeInFromTop(delay: 0.ms),
                                          Text(
                                            ' ${gameState.health}',
                                            style: const TextStyle(
                                              fontFamily: FontFam.orbitron,
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ).fadeInFromTop(delay: 0.ms),
                                          const SizedBox(
                                            width: 20,
                                          ),
                                          Image.asset(
                                            'assets/images/coinui.png',
                                            height: 30,
                                            width: 30,
                                          ).fadeInFromTop(delay: 0.ms),
                                          Text(
                                            ' ${ref.watch(gameNotifierProvider).score}',
                                            style: const TextStyle(
                                              fontFamily: FontFam.orbitron,
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ).fadeInFromTop(delay: 0.ms),
                                        ],
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
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(
                                width: 30,
                              ),
                              gameState.reloading == true
                                  ? switch (gameState.fastReload) {
                                      true =>
                                        LoadingAnimationWidget.prograssiveDots(
                                          color: Colors.red,
                                          size: 70,
                                        ),
                                      false => SizedBox(
                                          height: 100,
                                          width: 200,
                                          child: lottieWidget,
                                        )
                                    }
                                  : Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      child: switch (gameState.maxBullets > 7) {
                                        true => Row(
                                            children: [
                                              Container(
                                                height: 20,
                                                width: 20,
                                                decoration: BoxDecoration(
                                                  image: const DecorationImage(
                                                      image: AssetImage(
                                                          'assets/images/bullet.png')),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              Text(
                                                ' ${ref.watch(gameNotifierProvider).noOfBullets}',
                                                style: const TextStyle(
                                                  fontFamily: FontFam.orbitron,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        false => SeparatedRow(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            separatorBuilder: () =>
                                                const SizedBox(
                                              width: 10,
                                            ),
                                            children: List.generate(
                                                gameState.noOfBullets, (index) {
                                              return Container(
                                                height: 20,
                                                width: 20,
                                                decoration: BoxDecoration(
                                                  image: const DecorationImage(
                                                      image: AssetImage(
                                                          'assets/images/bullet.png')),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              );
                                            }),
                                          ),
                                      },
                                    ),

                              //! reload
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      ref
                                          .read(gameNotifierProvider.notifier)
                                          .reloadBullets();
                                    },
                                    icon: const Icon(
                                      PhosphorIconsBold.repeat,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  )
                                ],
                              ),
                            ],
                          ),
                        ],
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
                              const SizedBox(
                                height: 20,
                              ),
                              ClickButtonM(
                                onTap: () {
                                  goBack(context);
                                  // goTo(
                                  //     context: context, view: const MenuView());
                                  // context.goNamed(Routes.menu.name);
                                },
                                text: 'Menu',
                                width: 100,
                                height: 50,
                              ).fadeInFromBottom(delay: 100.ms),
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
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  ClickButtonM(
                                    onTap: () {
                                      goBack(context);
                                      // goTo(
                                      //     context: context,
                                      //     view: const MenuView());
                                      // context.goNamed(Routes.menu.name);
                                    },
                                    buttonColor: Palette.buttonRed,
                                    buttonShadow: Palette.buttonShadowRed,
                                    text: 'Menu',
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

          //! power up
          Consumer(
            builder: (context, ref, child) {
              GameNotifier gameNotifier =
                  ref.read(gameNotifierProvider.notifier);
              if (ref.watch(gameNotifierProvider).gameplayState ==
                  GameplayState.powerup) {
                _myGame.slow();
                _myGame.removeCoinsAndEnemies();
                return Container(
                  color: Colors.black45,
                  child: Center(
                    child: SeparatedColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      separatorBuilder: () => const SizedBox(height: 20),
                      children: List.generate(
                        2,
                        (index) {
                          powerUps.shuffle(Random());

                          List<PowerUp> selectedPowerUps =
                              powerUps.take(2).toList();
                          PowerUp powerUp = selectedPowerUps[index];
                          return ClickButton(
                            onTap: () {
                              switch (powerUp) {
                                case PowerUp.maxBulletsIncrease:
                                  gameNotifier.maxBulletsIncrease();
                                  break;

                                case PowerUp.healthIncrease:
                                  gameNotifier.healthIncrease();
                                  break;

                                case PowerUp.walkingSpeedIncrease:
                                  gameNotifier.walkingSpeedIncrease();
                                  break;

                                case PowerUp.sprintDistanceIncrease:
                                  gameNotifier.sprintDistanceIncrease();
                                  break;

                                case PowerUp.bulletRangeIncrease:
                                  gameNotifier.bulletRangeIncrease();
                                  break;

                                case PowerUp.numberOfBulletsPerShotIncrease:
                                  gameNotifier.numberOfBulletsPerShotIncrease();
                                  break;

                                case PowerUp.fastReload:
                                  gameNotifier.fastReload();
                                  break;

                                case PowerUp.sprintInvincibility:
                                  gameNotifier.sprintInvincibility();
                                  break;
                                default:
                                  {}
                              }
                              _myGame.normalizeGameSpeed();
                              ref
                                  .read(gameNotifierProvider.notifier)
                                  .playGame();
                            },
                            text: powerUp.title,
                            buttonColor:
                                index == 1 ? Palette.buttonBlueVariant : null,
                            buttonShadow: index == 1
                                ? Palette.buttonShadowBlueVariant
                                : null,
                            width: 300,
                            height: 60,
                          ).fadeInFromBottom(delay: 100.ms);
                        },
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }
}
