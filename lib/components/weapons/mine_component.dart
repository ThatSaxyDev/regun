import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class MineComponent extends PositionComponent with HasGameReference<RegunGame> {
  MineComponent({super.position})
    : super(size: Vector2.all(32), anchor: Anchor.center);
  double age = 0;
  bool exploded = false;
  @override
  void onRemove() {
    game.unregisterMine(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    age += dt;
    if (age > 8) {
      removeFromParent();
      return;
    }
    if (age < 0.35 || exploded) return;
    if (game.liveEnemies.any(
      (e) => e.position.distanceToSquared(position) < 75 * 75,
    )) {
      exploded = true;
      game.explode(
        position,
        reaction: WeaponReaction.mine,
        radius: 185,
        damage:
            (3.5 + game.gameState.effectRank(PowerUp.sprintMine)) *
            (game.loadout.character.name == 'scrapper' ? 1.4 : 1),
      );
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    RegunArt.shared
        .rawSprite('items/items', age >= .35 ? 5 : 4)
        .render(
          canvas,
          size: size,
          overridePaint: Paint()..filterQuality = FilterQuality.none,
        );
  }
}
