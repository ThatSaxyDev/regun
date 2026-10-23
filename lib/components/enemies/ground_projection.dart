import 'dart:ui';

import 'package:flame/components.dart';

/// A world sibling, never a child of the depth-sorted actor it belongs to.
/// This keeps committed floor art below every body at every world coordinate.
class GroundProjection extends PositionComponent {
  GroundProjection(this.owner, this.paintGround) : super(priority: -10);
  final PositionComponent owner;
  final void Function(Canvas) paintGround;
  @override
  void render(Canvas canvas) {
    if (!owner.isMounted || owner.isRemoving || owner.isRemoved) return;
    final origin = owner.position - owner.size / 2;
    canvas.save();
    canvas.translate(origin.x, origin.y);
    paintGround(canvas);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (owner.isRemoving || owner.isRemoved) removeFromParent();
  }
}
