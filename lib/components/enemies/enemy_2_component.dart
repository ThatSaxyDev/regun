import 'package:regun/systems/player_hurt_geometry.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/notifiers/game_notifier.dart';

import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/mummy_walk.dart';

class Enemy2Component extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks, CombatEnemy {
  Enemy2Component({super.position})
    : super(size: Vector2.all(enemySize), anchor: Anchor.center);
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
  final walk = MummyWalk();
  late SpriteAnimation blockedAnimation;
  bool _hasStruck = false;

  static const pursuitSpeed = 95.0;

  double attackInterval = 0.6; // Time between health reductions in seconds
  double firstStrikeDelay = 0.3; // Faster opening hit once melee is reached
  double timeSinceLastAttack = 0.0; // Timer to track the interval

  @override
  Future<void> onLoad() async {
    // Cache the owner before awaiting: leaving Training can detach pending loads.
    final owner = game;
    await super.onLoad();
    initializeHealth(6 * owner.director.healthScale);
    moveLeftAnimation = moveRightAnimation = RegunArt.shared.animation(
      'enemies/mummy_walk',
      count: 8,
      step: .1,
    );
    attackLeftAnimation = attackRightAnimation = RegunArt.shared.animation(
      'enemies/mummy',
      row: 1,
      from: 1,
      count: 2,
      step: .3,
    );
    deathLeftAnimation = deathRightAnimation = RegunArt.shared.animation(
      'enemies/mummy',
      row: 1,
      from: 3,
      count: 1,
      step: .6,
      loop: false,
    );
    hurtLeftAnimation = hurtRightAnimation = RegunArt.shared.animation(
      'enemies/mummy',
      row: 1,
      count: 1,
    );
    blockedAnimation = SpriteAnimation.spriteList([
      RegunArt.shared.sprite('enemies/mummy', 4),
    ], stepTime: 1);
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
    if (game.gameState.gameplayState != GameplayState.playing) return;

    if (isDying) {
      _deathElapsed += dt;
      if (_deathElapsed >= 0.6) removeFromParent();
      return;
    }

    if (freezeHeld || impactHeld) return;
    final playerPosition = game.myPlayer.position;
    final direction = game.enemyIntent(this, EnemyKind.mummy);
    final distanceToPlayer = (playerPosition - position).length;
    final minimumDistance = PlayerHurtGeometry.reach(40);
    if (distanceToPlayer > minimumDistance ||
        game.segmentBlocked(position, playerPosition)) {
      isAttacking = false;
      _hasStruck = false;
      timeSinceLastAttack = 0;
      walk.follow(position.toOffset(), walking: false, dt: 0);
      game.moveActor(this, direction, pursuitSpeed, dt);
      walk.follow(
        position.toOffset(),
        walking: true,
        facingX: playerPosition.x - position.x,
        dt: dt,
      );
      animation = walk.blocked ? blockedAnimation : moveRightAnimation;
      playing = false;
      animationTicker!.currentIndex = walk.blocked ? 0 : walk.frame;
    } else {
      isAttacking = true;
      walk.follow(
        position.toOffset(),
        walking: false,
        facingX: playerPosition.x - position.x,
        dt: dt,
      );
      timeSinceLastAttack += dt;
      final strikeDelay = _hasStruck ? attackInterval : firstStrikeDelay;
      if (timeSinceLastAttack >= strikeDelay &&
          !game.segmentBlocked(position, playerPosition)) {
        timeSinceLastAttack = 0;
        _hasStruck = true;
        game.damagePlayer(cause: 'Mummy strike');
      }
      animation = attackRightAnimation;
      playing = false;
      animationTicker!.currentIndex =
          MummyWalk.attackFrame(timeSinceLastAttack, hasStruck: _hasStruck) - 5;
    }
    if (isFlippedHorizontally != walk.left) flipHorizontallyAroundCenter();
  }

  @override
  void render(Canvas canvas) {
    final stance = !isDying && walk.blocked && !freezeHeld && !impactHeld;
    if (stance) {
      canvas.save();
      canvas.translate(size.x * .5, size.y * .88);
      canvas.scale(
        1,
        walk.stanceScale(reducedMotion: game.preferences.reducedMotion),
      );
      canvas.translate(-size.x * .5, -size.y * .88);
    }
    super.render(canvas);
    if (stance) canvas.restore();
  }

  @override
  void onFreezeStarted() {
    isAttacking = false;
    _hasStruck = false;
    timeSinceLastAttack = 0;
    animation = moveRightAnimation;
    playing = false;
    animationTicker?.reset();
  }

  @override
  int get xpReward => 3;
  @override
  int get scoreReward => 25;

  @override
  void onCombatDeath() {
    isDying = true;
    playing = true;
    isAttacking = false;
    animation = game.myPlayer.position.x > position.x
        ? deathRightAnimation
        : deathLeftAnimation;
  }
}
