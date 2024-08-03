import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/components/player_component.dart';

class RegunGame extends FlameGame with PanDetector, HasCollisionDetection {
  late PlayerComponent myPlayer;
  RegunGame()
      : super(
          camera: CameraComponent.withFixedResolution(
            width: 1500,
            height: 700,
          ),
        );

  @override
  Color backgroundColor() => const Color(0xff222222);

  @override
  void onMount() {
    // debugMode = true;
    world.add(myPlayer = PlayerComponent(position: Vector2.zero()));
    world.add(
      SpawnComponent(
        factory: (index) {
          return EnemyComponent();
        },
        period: 0.2,
        area: Rectangle.fromCenter(center: Vector2.zero(), size: size),
      ),
    );
    super.onMount();
  }

  // @override
  // void update(double dt) {
  //   camera.viewfinder.zoom = 0.3;
  //   super.update(dt);
  // }

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
