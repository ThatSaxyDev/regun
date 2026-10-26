import 'package:flame/components.dart';
import 'package:regun/systems/dash_reserve.dart';
import 'package:flame/events.dart';
import 'package:regun/components/ui/action_control_skin.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/theme/pixel_glyph.dart';

class BoostButtonComponent extends AdvancedButtonComponent
    with HasGameReference<RegunGame> {
  BoostButtonComponent({super.onPressed, this.tapped = false})
    : super(
        defaultSkin: ActionControlSkin(glyph: PixelGlyph.dash, label: 'DASH'),
        downSkin: ActionControlSkin(
          glyph: PixelGlyph.dash,
          label: 'DASH',
          pressed: true,
        ),
        size: Vector2.all(112),
        position: Vector2(1130, 585),
        anchor: Anchor.center,
      );

  bool tapped;
  double _remaining = 0;
  final reserve = DashReserve();
  void syncCapacity() => reserve.setCapacity(game.gameState.dashCapacity);
  double get recharge =>
      (1.6 - game.gameState.effectRank(PowerUp.quickstep) * .25).clamp(.6, 1.6);
  Map<String, dynamic> checkpoint() {
    syncCapacity();
    return reserve.toJson();
  }

  void restoreCheckpoint(Map<String, dynamic> map) => reserve.restore(map);
  double get cooldownFraction => reserve.charges > 0
      ? 0
      : (reserve.remaining / reserve.duration).clamp(0, 1);
  void cancelDash() {
    tapped = false;
    _remaining = 0;
  }

  void reset() {
    tapped = false;
    _remaining = 0;
    reserve.setCapacity(game.gameState.dashCapacity);
    reserve.charges = reserve.capacity;
    reserve.remaining = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    syncCapacity();
    if (game.inputBlocked) return;
    reserve.advance(dt, recharge);
    if (!tapped) return;
    _remaining -= dt;
    if (_remaining <= 0) {
      tapped = false;
      game.gameNotifier.survivor.landedDash(game.loadout.character);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (game.inputBlocked) return;
    super.onTapDown(event);
    if (game.gameState.gameplayState != GameplayState.playing ||
        tapped ||
        reserve.charges <= 0) {
      return;
    }
    syncCapacity();
    if (!reserve.spend(recharge)) return;
    final movement = game.movementJoystick.relativeDelta;
    final aim = game.weaponJoystick.relativeDelta;
    game.myPlayer.dashDirection.setFrom(
      !movement.isZero()
          ? movement.normalized()
          : !aim.isZero()
          ? aim.normalized()
          : game.myPlayer.lastMovement,
    );
    game.dashCount++;
    game.combat.onDash();
    tapped = true;
    _remaining = game.gameState.sprintTimeDistance / 1000;
    game.gameNotifier.triggerSprintInvincibility();
  }
}
