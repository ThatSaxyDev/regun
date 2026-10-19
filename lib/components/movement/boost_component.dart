import 'package:flame/components.dart';
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
              glyph: PixelGlyph.dash, label: 'DASH', pressed: true),
          size: Vector2.all(112),
          position: Vector2(1130, 585),
          anchor: Anchor.center,
        );

  bool tapped;
  double _remaining = 0;
  double _cooldown = 0, _cooldownDuration = 1.6;
  Map<String, dynamic> checkpoint() =>
      {'remaining': _cooldown, 'duration': _cooldownDuration};
  void restoreCheckpoint(Map<String, dynamic> map) {
    _cooldown = ((map['remaining'] as num?)?.toDouble() ?? 0).clamp(0, 1.6);
    _cooldownDuration =
        ((map['duration'] as num?)?.toDouble() ?? 1.6).clamp(0.7, 1.6);
  }

  double get cooldownFraction => (_cooldown / _cooldownDuration).clamp(0, 1);
  void cancelDash() {
    tapped = false;
    _remaining = 0;
  }

  void reset() {
    tapped = false;
    _remaining = 0;
    _cooldown = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing) return;
    _cooldown = (_cooldown - dt).clamp(0, 1.6);
    if (!tapped) return;
    _remaining -= dt;
    if (_remaining <= 0) tapped = false;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (game.gameState.gameplayState != GameplayState.playing ||
        tapped ||
        _cooldown > 0) {
      return;
    }
    final movement = game.movementJoystick.relativeDelta;
    final aim = game.weaponJoystick.relativeDelta;
    game.myPlayer.dashDirection.setFrom(!movement.isZero()
        ? movement.normalized()
        : !aim.isZero()
            ? aim.normalized()
            : game.myPlayer.lastMovement);
    _cooldown =
        (1.6 - game.gameState.rank(PowerUp.quickstep) * 0.25).clamp(0.7, 1.6);
    _cooldownDuration = _cooldown;
    game.dashCount++;
    game.combat.onDash();
    tapped = true;
    _remaining = game.gameState.sprintTimeDistance / 1000;
    game.gameNotifier.triggerSprintInvincibility();
  }
}
