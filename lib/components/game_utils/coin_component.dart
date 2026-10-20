import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class CoinComponent extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  CoinComponent({super.position, this.value = 1})
      : super(
          size: Vector2.all(coinSize),
          anchor: Anchor.center,
        );

  bool isCollected = false;
  int value;

  static const coinSize = 24.0;
  late SpriteAnimation coinAnimation;

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected || game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final toPlayer = game.myPlayer.position - position;
    final radius = 180 +
        game.gameState.effectRank(PowerUp.scavenger) * 60 +
        (game.loadout.character.name == 'scrapper' ? 80 : 0);
    if (toPlayer.length2 <= radius * radius) {
      position.addScaled(toPlayer.normalized(), 460 * dt);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    coinAnimation = RegunArt.shared.animation('items/items', step: .14);
    animation = coinAnimation;
    add(
      CircleHitbox(
        radius: coinSize / 2,
        collisionType: CollisionType.passive,
      ),
    );
  }
}
