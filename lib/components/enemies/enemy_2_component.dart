import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/notifiers/game_notifier.dart';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/game.dart';

class Enemy2Component extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks, CombatEnemy {
  Enemy2Component({super.position})
      : super(
          size: Vector2.all(enemySize),
          anchor: Anchor.center,
        );
  static const enemySize = 100.0;
  @override
  double get impactResponse => .7;
  late SpriteAnimation moveLeftAnimation;
  late SpriteAnimation moveRightAnimation;
  late SpriteAnimation attackLeftAnimation;
  late SpriteAnimation attackRightAnimation;
  late SpriteAnimation deathLeftAnimation;
  late SpriteAnimation deathRightAnimation;
  late SpriteAnimation hurtLeftAnimation;
  late SpriteAnimation hurtRightAnimation;
  bool isAttacking = false;
  bool isDying = false;
  double _deathElapsed = 0;

  double attackInterval = 0.6; // Time between health reductions in seconds
  double timeSinceLastAttack = 0.0; // Timer to track the interval

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initializeHealth(6 * game.director.healthScale);
    moveLeftAnimation = moveRightAnimation =
        RegunArt.shared.animation('enemies/mummy', step: 1 / 12);
    attackLeftAnimation = attackRightAnimation = RegunArt.shared
        .animation('enemies/mummy', row: 1, from: 1, count: 2, step: .3);
    deathLeftAnimation = deathRightAnimation = RegunArt.shared.animation(
        'enemies/mummy',
        row: 1,
        from: 3,
        count: 1,
        step: .6,
        loop: false);
    hurtLeftAnimation = hurtRightAnimation =
        RegunArt.shared.animation('enemies/mummy', row: 1, count: 1);
    animation = moveRightAnimation;
    add(
      CircleHitbox(
        radius: 40,
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
    final facingLeft = game.myPlayer.position.x < position.x;
    if (isFlippedHorizontally != facingLeft) flipHorizontallyAroundCenter();
    if (game.gameState.gameplayState != GameplayState.playing) return;

    if (isDying) {
      _deathElapsed += dt;
      if (_deathElapsed >= 0.6) removeFromParent();
      return;
    }

    //! PLAYER POSITION
    final playerPosition = game.myPlayer.position;

    //! DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = game.enemyIntent(this, EnemyKind.mummy);

    //! CALCULATE DISTANCE BETWEEN ENEMY AND PLAYER
    final distanceToPlayer = (playerPosition - position).length;

    //! DEFINE A MINIMUM DISTANCE TO STOP BEFORE TOUCHING THE PLAYER
    const minimumDistance = 40.0; // Adjust this value as needed

    //! MOVE ENEMY TOWARDS PLAYER IF IT'S FARTHER THAN THE MINIMUM DISTANCE
    if (distanceToPlayer > minimumDistance) {
      isAttacking = false;
      timeSinceLastAttack = 0.0; // Reset the attack timer
      const speed = 90;
      game.moveActor(this, direction, speed.toDouble(), dt);

      // Set move animation if not attacking
      if (playerPosition.x > position.x) {
        animation = moveRightAnimation;
      } else {
        animation = moveLeftAnimation;
      }
    } else {
      isAttacking = true;

      // Reduce health at regular intervals
      timeSinceLastAttack += dt;
      if (timeSinceLastAttack >= attackInterval &&
          !game.segmentBlocked(position, playerPosition)) {
        timeSinceLastAttack = 0.0;
        game.damagePlayer(cause: 'Mummy strike');
      }

      // Set attack animation
      if (playerPosition.x > position.x) {
        animation = attackRightAnimation;
      } else {
        animation = attackLeftAnimation;
      }
    }
  }

  @override
  int get xpReward => 3;
  @override
  int get scoreReward => 25;

  @override
  void onCombatDeath() {
    isDying = true;
    isAttacking = false;
    animation = game.myPlayer.position.x > position.x
        ? deathRightAnimation
        : deathLeftAnimation;
  }
}
