import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:regun/components/ui/action_control_skin.dart';
import 'package:regun/game.dart';
import 'package:regun/theme/pixel_glyph.dart';

class ReloadButtonComponent extends ButtonComponent
    with HasGameReference<RegunGame> {
  ReloadButtonComponent({super.onPressed})
    : super(
        button: ActionControlSkin(glyph: PixelGlyph.reload, label: 'RELOAD'),
        buttonDown: ActionControlSkin(
          glyph: PixelGlyph.reload,
          label: 'RELOAD',
          pressed: true,
        ),
        size: Vector2.all(112),
        position: Vector2(1380, 370),
        anchor: Anchor.center,
      );

  @override
  void onTapDown(TapDownEvent event) {
    if (game.inputBlocked) return;
    game.requestReload();
    super.onTapDown(event);
  }
}
