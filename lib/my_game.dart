import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/player_component.dart';

class RegunGame extends FlameGame with PanDetector, HasCollisionDetection {
  late PlayerComponent myPlayer;

  @override
  Color backgroundColor() => const Color(0xff222222);

  @override
  void onMount() {
    // debugMode = true;
    add(myPlayer = PlayerComponent(position: Vector2(200, 750)));
    add(
      SpawnComponent(
        factory: (index) {
          return EnemyComponent();
        },
        period: 0.5,
        area: Rectangle.fromLTWH(
          0,
          0,
          size.x,
          -EnemyComponent.enemySize,
        ),
      ),
    );
    super.onMount();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    myPlayer.move(info.delta.global);
  }

  @override
  void onPanStart(DragStartInfo info) {
    myPlayer.startShooting();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    myPlayer.stopShooting();
  }
}
