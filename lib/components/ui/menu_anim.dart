import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:regun/widgets/home_animation.dart';

class MenuComponent extends SpriteAnimationComponent
    with HasGameReference<MenuAnimationFlame> {
  MenuComponent({
    super.position,
    this.playerRadius = 25,
  });

  final double playerRadius;

  late SpriteAnimation idleRightAnimation;
  late SpriteAnimation runRightAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final idleRightSpriteSheet = SpriteSheet(
      image: await game.images.load('player_idle.png'),
      srcSize: Vector2(48, 48),
    );

    final runRightSpriteSheet = SpriteSheet(
      image: await game.images.load('player_run.png'),
      srcSize: Vector2(48, 48),
    );

    idleRightAnimation = idleRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 5,
    );

    runRightAnimation = runRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );

    animation = runRightAnimation;
  }

  @override
  void onMount() {
    size = Vector2.all(playerRadius * 7);
    super.onMount();
  }
}
