import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/components/movement/boost_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class ReloadButtonComponent extends ButtonComponent
    with HasGameReference<RegunGame>, RiverpodComponentMixin {
  bool tapped;
  ReloadButtonComponent({
    super.onPressed,
    this.tapped = false,
  }) : super(
          button: Buttonn(radius: 35, buttonAsset: 'b_button.png'),
          buttonDown: Buttonn(radius: 35, buttonAsset: 'b_button_pressed.png'),
          size: Vector2.all(70),
          position: Vector2(765, 310),
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    // debugMode = true;
    super.onMount();
  }

  @override
  void onTapDown(TapDownEvent event) async {
    ref.read(gameNotifierProvider.notifier).reloadBullets();
    super.onTapDown(event);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // tapped = false;
    super.onTapUp(event);
  }
}
