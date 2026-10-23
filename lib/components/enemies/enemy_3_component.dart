import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/notifiers/game_notifier.dart';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/game.dart';

class Enemy3Component extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks, CombatEnemy {
  Enemy3Component({super.position})
    : super(size: Vector2.all(enemySize), anchor: Anchor.center);
  static const enemySize = 100.0;
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
  double _windup = 0;

  double attackInterval = 2; // Time between attacks
  double timeSinceLastAttack = 0; // Timer to track the interval

  @override
  Future<void> onLoad() async {
    // Cache the owner before awaiting: leaving Training can detach pending loads.
    final owner = game;
    await super.onLoad();
    initializeHealth(3 * owner.director.healthScale);
    moveLeftAnimation = moveRightAnimation = RegunArt.shared.animation(
      'enemies/ranged',
      step: 1 / 12,
    );
    attackLeftAnimation = attackRightAnimation = RegunArt.shared.animation(
      'enemies/ranged',
      row: 1,
      from: 1,
      count: 2,
      step: .3,
    );
    deathLeftAnimation = deathRightAnimation = RegunArt.shared.animation(
      'enemies/ranged',
      row: 1,
      from: 3,
      count: 1,
      step: .6,
      loop: false,
    );
    hurtLeftAnimation = hurtRightAnimation = RegunArt.shared.animation(
      'enemies/ranged',
      row: 1,
      count: 1,
    );
    animation = moveRightAnimation;
    add(
      RectangleHitbox(
        size: Vector2(40, 70),
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
    if (game.gameState.gameplayState != GameplayState.playing) return;

    if (isDying) {
      _deathElapsed += dt;
      if (_deathElapsed >= 0.6) removeFromParent();
      return;
    }

    if (freezeHeld || impactHeld) return;
    final facingLeft = game.myPlayer.position.x < position.x;
    if (isFlippedHorizontally != facingLeft) flipHorizontallyAroundCenter();

    final playerPosition = game.myPlayer.position;
    final distance = position.distanceTo(playerPosition);
    if (isAttacking) {
      _windup += dt;
      animation = attackRightAnimation;
      // A visible planted cast; movement cannot cancel or accelerate the shot.
      if (_windup >= .4) {
        if (distance < 540 && !game.segmentBlocked(position, playerPosition)) {
          game.audio.play('enemy3projectile.wav');
          game.world.add(Enemy3Projectile(position: position.clone()));
        }
        isAttacking = false;
        _windup = 0;
        timeSinceLastAttack = 0;
      }
      return;
    }

    game.moveActor(this, game.enemyIntent(this, EnemyKind.ranged), 80, dt);
    animation = moveRightAnimation;
    timeSinceLastAttack += dt;
    if (timeSinceLastAttack >= attackInterval &&
        distance < 500 &&
        !game.segmentBlocked(position, playerPosition)) {
      isAttacking = true;
      _windup = 0;
      animation = attackRightAnimation;
    }
  }

  @override
  void onFreezeStarted() {
    isAttacking = false;
    _windup = 0;
    timeSinceLastAttack = 0;
    animation = moveRightAnimation;
    animationTicker?.reset();
  }

  @override
  int get xpReward => 2;
  @override
  int get scoreReward => 20;

  @override
  void onCombatDeath() {
    isDying = true;
    isAttacking = false;
    game.addCombatEffectForKill(
      position,
      radius: 58,
      remains: RegunArt.shared.rawSprite('enemies/ranged_remains', 0),
      flipRemains: isFlippedHorizontally,
    );
    removeFromParent();
  }
}
