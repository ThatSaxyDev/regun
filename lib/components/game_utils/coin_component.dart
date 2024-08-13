import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/game.dart';

class CoinComponent extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  CoinComponent({super.position})
      : super(
          size: Vector2.all(coinSize),
          anchor: Anchor.center,
        );

  static const coinSize = 40.0;
  late SpriteAnimation coinAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // debugMode = true;
    final coinSpriteSheet = SpriteSheet(
      image: await game.images.load('coin.png'),
      srcSize: Vector2(16, 16),
    );
    coinAnimation = coinSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 5,
    );
    animation = coinAnimation;
    add(
      CircleHitbox(
        radius: coinSize / 2,
        collisionType: CollisionType.passive,
      ),
    );
  }
}
