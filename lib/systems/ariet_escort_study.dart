import 'dart:ui';
import 'dart:math' as math;

import 'package:regun/systems/walker_rig.dart';

/// Geometry adapter for the proposed escort, NOT an enemy/combat profile.
/// Every query maps the real Walker rig, not only its painted silhouette.
/// Production ownership, AI, health, hits and deployment remain a later slice.
class ArietEscortStudy {
  ArietEscortStudy({this.scale = combatScale, this.folded = false})
    : rig = WalkerRig(
        barrelLength: 158,
        foldedReach: folded ? .28 : .72,
        foldedAnkleZ: folded ? 72 : 24,
        foldedKneeDown: folded,
      ) {
    rig.folded = folded;
    rig.trackTurret = false;
    rig.turretPitch = folded ? -.6 : 0;
    if (folded) rig.turretYaw = math.pi / 2;
    if (folded) {
      // Folded underside study: feet/pistons physically tuck, gun stows across the deck.
      rig.height = 48;
    }
  }
  static const combatScale = .55;
  final double scale;
  final bool folded;
  final WalkerRig rig;
  static const fullBodyRadius = 88.0;
  static const sharedHPProposal = 50;
  double get bodyRadius => fullBodyRadius * scale;
  double get upperLength => WalkerRig.upperLength * scale;
  double get lowerLength => WalkerRig.lowerLength * scale;
  double get muzzleClearance => 13 * scale;
  Offset point(Offset p) => p * scale;
  WalkerPoint spatial(WalkerPoint p) => p * scale;
  WalkerLegPose pose(WalkerLeg leg) {
    final original = rig.pose(leg);
    return WalkerLegPose(
      spatial(original.hip),
      spatial(original.knee),
      spatial(original.ankle),
    );
  }

  WalkerPoint get muzzle => spatial(rig.muzzle);
  Offset foot(WalkerLeg leg) => pose(leg).ankle.ground;

  // Art envelope measured against the current Walker parts at the tucked pose.
  Rect get cargoEnvelope => Rect.fromCenter(
    center: Offset.zero,
    width: 220 * scale,
    height: 180 * scale,
  );
}
