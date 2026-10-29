import 'dart:ui';

import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';

/// A query result keeps section and first swept distance together. Future native
/// adapters must carry this through ballistics/procs, not query a root circle.
class LodestarContact {
  const LodestarContact(this.section, this.distance);
  final LodestarSection section;
  final double distance;
}

class LodestarTarget {
  const LodestarTarget(this.rig, this.sections);
  final LodestarRig rig;
  final LodestarSections sections;

  LodestarContact? firstContact(Offset from, Offset to, {double padding = 0}) {
    if (!padding.isFinite ||
        padding < 0 ||
        !from.dx.isFinite ||
        !from.dy.isFinite ||
        !to.dx.isFinite ||
        !to.dy.isFinite) {
      return null;
    }
    LodestarContact? first;
    for (final pose in rig.poses) {
      if (!sections.living(pose.section)) continue;
      final d = pose.footprint().contact(from, to, padding: padding);
      if (d != null && (first == null || d < first.distance)) {
        first = LodestarContact(pose.section, d);
      }
    }
    return first;
  }

  Iterable<LodestarSection> blastSections(
    Offset center,
    double radius, {
    required bool Function(Offset from, Offset surface) visible,
  }) sync* {
    if (!radius.isFinite ||
        radius < 0 ||
        !center.dx.isFinite ||
        !center.dy.isFinite) {
      return;
    }
    for (final pose in rig.poses) {
      if (!sections.living(pose.section)) continue;
      final body = pose.footprint();
      if (body.distance(center) > radius) continue;
      final axis = body.b - body.a;
      final t = axis.distanceSquared == 0
          ? 0.0
          : (((center - body.a).dx * axis.dx + (center - body.a).dy * axis.dy) /
                    axis.distanceSquared)
                .clamp(0.0, 1.0);
      final nearest = body.a + axis * t, direction = center - nearest;
      final surface = direction.distance <= body.radius
          ? center
          : nearest + direction / direction.distance * body.radius;
      if (visible(center, surface)) yield pose.section;
    }
  }
}
