import 'package:flame/components.dart';

/// Keep the footfall phase when a looping action changes facing. Flame normally
/// creates a new ticker at frame zero whenever the animation object changes.
void switchLoopFacing(
    SpriteAnimationComponent component, SpriteAnimation next) {
  final old = component.animation;
  if (identical(old, next)) return;
  final ticker = component.animationTicker;
  final duration = ticker?.totalDuration() ?? 0;
  final phase = duration > 0 && old?.loop == true
      ? ((ticker!.elapsed % duration) / duration)
      : 0.0;
  component.animation = next;
  if (next.loop && phase > 0) {
    component.animationTicker!
        .update(phase * component.animationTicker!.totalDuration());
  }
}
