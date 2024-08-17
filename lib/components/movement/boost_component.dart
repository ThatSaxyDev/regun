import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class BoostButtonComponent extends AdvancedButtonComponent
    with HasGameReference<RegunGame>, RiverpodComponentMixin {
  bool tapped;
  BoostButtonComponent({
    super.onPressed,
    this.tapped = false,
  }) : super(
          defaultSkin: Buttonn(radius: 35, buttonAsset: 'a_button.png'),
          // downSkin: Buttonn(radius: 35, buttonAsset: 'b_button_pressed.png'),
          size: Vector2.all(70),
          position: Vector2(620, 340),
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    // debugMode = true;
    super.onMount();
  }

  @override
  void onTapDown(TapDownEvent event) async {
    // if (!game.movementJoystick.delta.isZero() &&
    //     ref.read(gameNotifierProvider).triggerSprintMine == true &&
    //     ref.read(gameNotifierProvider).sprintMineCount > 0) {
    //   game.addMine();
    //   ref.read(gameNotifierProvider.notifier).decreaseSprintMineCount();
    // }
    ref.read(soloudPlayProvider).play('click.mp3');

    tapped = true;
    if (ref.read(gameNotifierProvider).sprintInvincibility == true) {
      ref.read(gameNotifierProvider.notifier).triggerSprintInvincibility();
    }
    await Future.delayed(Duration(
            milliseconds: ref.read(gameNotifierProvider).sprintTimeDistance))
        .whenComplete(() {
      tapped = false;
    });
    super.onTapDown(event);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // tapped = false;
    super.onTapUp(event);
  }
}

class Buttonn extends PositionComponent {
  Buttonn({
    required double radius,
    Paint? paint,
    super.position,
    required this.buttonAsset,
  }) : super(
          priority: 30,
          size: Vector2.all(2 * radius),
          // anchor: Anchor.center,
        );

  late Sprite _buttonSprite;
  late String buttonAsset;

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    await super.onLoad();
    _buttonSprite = await Sprite.load(
      buttonAsset,
      srcSize: Vector2.all(16),
    );
  }

  @override
  void render(Canvas canvas) {
    _buttonSprite.render(
      canvas,
      size: size,
      // anchor: Anchor.center,
    );
  }
}
