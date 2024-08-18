import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

class MapComponent extends PositionComponent {
  late TiledComponent mapComponent;

  @override
  FutureOr<void> onLoad() async {
    mapComponent = await TiledComponent.load('maptile.tmx', Vector2.all(32));

    add(mapComponent);
    return super.onLoad();
  }
}
