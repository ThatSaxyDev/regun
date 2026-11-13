import 'package:regun/presentation/travel_gait.dart';
import 'package:regun/systems/player_hurt_geometry.dart';
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
    : super(size: Vector2.all(enemySize), anchor: Anchor.center);
  bool isDying = false;
  late TravelGait gait;
  @override
  void onMount() {
    super.onMount();
    gait = TravelGait(phase: combatId % 4)
      ..sample(position.toOffset(), statusClock);
    playing = false;
  }

  static const enemySize = 85.0;
  late SpriteAnimation moveLeftAnimation;
  late SpriteAnimation moveRightAnimation;

  @override
  Future<void> onLoad() async {
    // Cache the owner before awaiting: leaving Training can detach pending loads.
    final owner = game;
    await super.onLoad();
    initializeHealth(2 * owner.director.healthScale);
    moveLeftAnimation = moveRightAnimation = RegunArt.shared.animation(
      'enemies/scorpion',
      step: 1 / 12,
    );
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
    if (game.skipManagedMinion(this)) return;
    super.update(dt);
    if (isDying || freezeHeld || impactHeld) return;
    final facingLeft = game.myPlayer.position.x < position.x;
    if (isFlippedHorizontally != facingLeft) flipHorizontallyAroundCenter();

    //! PLAYER POSITION
    final playerPosition = game.myPlayer.position;

    //! DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = game.enemyIntent(this, EnemyKind.scorpion);

    //! MOVE ENEMY TOWARDS PLAYER
    const speed = 63.0;
    game.moveActor(this, direction, speed, dt);
    gait.sample(position.toOffset(), statusClock);
    playing = false;
    animationTicker?.currentIndex = gait.frame;
    const contact = 25.5 + PlayerHurtGeometry.radius;
    if (position.distanceToSquared(playerPosition) <= contact * contact &&
        !game.segmentBlocked(position, playerPosition)) {
      game.damagePlayer(
        amount: game.expedition?.enemyDamage() ?? 1,
        cause: 'Scorpion',
      );
    }

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
    game.addCombatEffectForKill(
      position,
      radius: size.y / 2,
      remains: RegunArt.shared.sprite('enemies/scorpion', 7),
    );
    game.addDeathParticles(position, color: const Color(0xff8ABF8B));
    removeFromParent();
  }
}
