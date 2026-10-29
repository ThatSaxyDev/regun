import 'dart:ui';

import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/systems/target_shape.dart';

/// One shared HP owner, explicit empty spaces between hull/pods.
class ArietHull {
  static const enclosingRadius = 270.0;
  static Iterable<TargetCapsule> regions(ArietRig rig) sync* {
    TargetCapsule local(Offset a, Offset b, double radius) =>
        TargetCapsule(rig.air(a), rig.air(b), radius);
    yield local(const Offset(-88, 0), const Offset(80, 0), 76);
    for (final side in [-1.0, 1.0]) {
      yield local(Offset(-77, side * 142), Offset(60, side * 142), 39);
      yield local(Offset(-10, side * 76), Offset(-10, side * 142), 11);
    }
    for (var i = 0; i < 2; i++) {
      final from = rig.noseSocket(i);
      yield TargetCapsule(
        from,
        from +
            ArietRig.rotate(
              const Offset(ArietRig.rotaryLength, 0),
              rig.rotaryYaw[i],
            ),
        11,
      );
    }
    yield TargetCapsule(
      rig.cannonSocket,
      rig.cannonSocket +
          ArietRig.rotate(
            const Offset(ArietRig.cannonLength, 0),
            rig.cannonYaw,
          ),
      18,
    );
    yield TargetCapsule(
      rig.flakSocket,
      rig.flakSocket +
          ArietRig.rotate(const Offset(ArietRig.flakLength, 0), rig.flakYaw),
      16,
    );
  }
}
