import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/combat_enemy.dart';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';

class EnemyComponent extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  EnemyComponent({super.position})
      : super(
          size: Vector2.all(enemySize),
          anchor: Anchor.center,
        );
  bool isDying = false;
  static const enemySize = 85.0;
  late SpriteAnimation moveLeftAnimation;
  late SpriteAnimation moveRightAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initializeHealth(2 * game.director.healthScale);
    moveLeftAnimation = moveRightAnimation =
        RegunArt.shared.animation('enemies/scorpion', step: 1 / 12);
    animation = moveRightAnimation;
    add(
      RectangleHitbox(
        size: Vector2(61, 35),
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  // @override
  // void render(Canvas canvas) {
  //   canvas.drawRect(size.toRect(), _paint);
  // }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDying) return;
    final facingLeft = game.myPlayer.position.x < position.x;
    if (isFlippedHorizontally != facingLeft) flipHorizontallyAroundCenter();



    //! PLAYER POSITION
    final playerPosition = game.myPlayer.position;

    //! DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = game.enemyIntent(this, EnemyKind.scorpion);

    //! MOVE ENEMY TOWARDS PLAYER
    const speed = 60;
    game.moveActor(this, direction, speed.toDouble(), dt);

    if (playerPosition.x > position.x) {
      animation = moveRightAnimation;
    } else {
      animation = moveLeftAnimation;
    }

    //! DELETE ENEMY WHEN IT TOUCHES THE PLAYER
    // if ((position - center).length < 1) {
    //   removeFromParent();
    // }
  }

  @override
  void onCombatDeath() => showDeathSplashEffect();

  void showDeathSplashEffect() {
    if (isDying || isRemoving) return;
    isDying = true;
    game.addCombatEffectForKill(position,
        radius: size.y / 2,
        remains: RegunArt.shared.sprite('enemies/scorpion', 7));
    game.addDeathParticles(position, color: const Color(0xff8ABF8B));
    removeFromParent();
  }
}
