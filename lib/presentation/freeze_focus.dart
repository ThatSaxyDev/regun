import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:regun/game.dart';

/// Shared charcoal focus: the action stays clear, the arena gently recedes.
/// Paint-only, simulation-clock fades. Never captures input or changes exposure.
class FreezeFocus {
  static double envelope(double elapsed, double duration) {
    if (duration <= 0) return 0;
    final t = math.min(
      (elapsed / (duration * .22)).clamp(0.0, 1.0),
      ((duration - elapsed) / (duration * .25)).clamp(0.0, 1.0),
    );
    return t * t * (3 - 2 * t);
  }

  static void paint(
    Canvas canvas,
    Rect bounds,
    Offset center,
    double radius,
    double amount, {
    required bool reducedMotion,
  }) {
    if (amount <= 0) return;
    final alpha = amount * (reducedMotion ? .24 : .48);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          center,
          radius,
          [
            const Color(0x00161b18),
            Color.fromRGBO(17, 24, 20, alpha * .22),
            Color.fromRGBO(13, 19, 16, alpha),
          ],
          const [.32, .65, 1],
        ),
    );
  }
}

class FreezeFocusView extends Component with HasGameReference<RegunGame> {
  FreezeFocusView() : super(priority: 40);
  @override
  void render(Canvas canvas) {
    final upgrade = game.upgradePresentation, reveal = game.bossReveal;
    if (!upgrade.holding && !reveal.active) return;
    final target = game.myPlayer.position.clone();
    if (reveal.active && !reveal.reduced) {
      target.setZero();
      for (final actor in reveal.actors) {
        target.add(actor.position);
      }
      target.scale(1 / reveal.actors.length);
    }
    final age = reveal.active ? reveal.elapsed : upgrade.elapsed;
    final duration = reveal.active ? reveal.duration : upgrade.duration;
    final center = game.camera.viewfinder.localToGlobal(target).toOffset();
    FreezeFocus.paint(
      canvas,
      Offset.zero & game.camera.viewport.virtualSize.toSize(),
      center,
      (reveal.active ? (reveal.actors.length > 1 ? 650.0 : 340.0) : 230.0) *
          game.camera.viewfinder.zoom,
      FreezeFocus.envelope(age, duration),
      reducedMotion: game.preferences.reducedMotion,
    );
  }
}
