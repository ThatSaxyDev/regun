import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/systems/expedition_signature.dart';

class ExpeditionEffectArt {
  static void paint(
    Canvas canvas,
    ExpeditionCue cue,
    double radius,
    double progress, {
    required ColorFilter ambient,
    required bool reduced,
  }) {
    final age = progress.clamp(0.0, 1.0);
    final fade = 1.0 - age;
    final travel = reduced ? .7 : .36 + .64 * (1 - math.pow(1 - age, 3));
    switch (cue) {
      case ExpeditionCue.fusePrimer:
        AttackVfx.groundMaterial(
          canvas,
          1,
          Offset.zero,
          72,
          height: 44,
          alpha: .65,
          ambient: ambient,
        );
        AttackVfx.stamp(
          canvas,
          2,
          const Offset(0, -8),
          37,
          alpha: .94,
          grading: ambient,
        );
        AttackVfx.chip(
          canvas,
          const Offset(1, -10),
          7,
          const Color(0xffef9e58),
        );
      case ExpeditionCue.fuse:
      case ExpeditionCue.flash:
        final fuse = cue == ExpeditionCue.fuse;
        AttackVfx.groundMaterial(
          canvas,
          1,
          Offset.zero,
          radius * (fuse ? 1.95 : 1.45),
          height: radius * .88,
          alpha: .75 * fade,
          ambient: ambient,
        );
        AttackVfx.stamp(
          canvas,
          18 + (age * 5).floor(),
          Offset(0, -radius * (fuse ? .23 : .12)),
          radius * (fuse ? 1.35 : .94),
          height: radius * (fuse ? 1.24 : .64),
          alpha: fade,
          material: AttackMaterial.ember,
          grading: ambient,
        );
        _debris(canvas, radius, travel, fade, const Color(0xffeeb47a), 7);
      case ExpeditionCue.slag:
        final hold = ((1 - age) * 4).clamp(0.0, 1.0);
        AttackVfx.groundMaterial(
          canvas,
          1,
          Offset.zero,
          radius * 2,
          height: radius * 1.55,
          alpha: .93 * hold,
          ambient: ambient,
        );
        for (final p in const [
          Offset(-.45, .24),
          Offset(.31, -.34),
          Offset(.27, .35),
        ]) {
          AttackVfx.stamp(
            canvas,
            18 + (reduced ? 2 : (age * 15).floor() % 3),
            p * radius,
            radius * .83,
            height: radius * .54,
            alpha: .85 * hold,
            material: AttackMaterial.ember,
            grading: ambient,
          );
        }
      case ExpeditionCue.fracture:
      case ExpeditionCue.breach:
      case ExpeditionCue.backlash:
        final fracture = cue == ExpeditionCue.fracture;
        final weights = fracture
            ? const [1.0, .75, .87, .68]
            : const [.9, .58, .76];
        final spread = (reduced ? .94 : travel).toDouble();
        AttackVfx.groundMaterial(
          canvas,
          1,
          Offset.zero,
          radius * 1.4,
          height: radius * .72,
          alpha: .26 * fade,
          ambient: ambient,
        );
        for (final (i, weight) in weights.indexed) {
          final angle = .38 + i * math.pi * 2 / weights.length;
          final axis = Offset(math.cos(angle), math.sin(angle));
          final side = Offset(-axis.dy, axis.dx);
          final step = radius * weight * spread;
          final split = [
            Offset.zero,
            axis * step * .32 + side * step * .12,
            axis * step * .51 - side * step * .04,
            axis * step * .76 + side * step * .10,
            axis * step,
          ];
          _fracture(canvas, split, fade, width: fracture ? 7 : 4);
          AttackVfx.stamp(
            canvas,
            1 + (age * 4).floor(),
            axis * step * .76,
            radius * .40,
            alpha: fade * .68,
            grading: ambient,
          );
        }
        _debris(
          canvas,
          radius,
          travel,
          fade,
          const Color(0xffbda78d),
          fracture ? 8 : 5,
        );
      case ExpeditionCue.frost:
      case ExpeditionCue.shatter:
        final shards = cue == ExpeditionCue.shatter;
        AttackVfx.floorArea(
          canvas,
          5,
          Offset.zero,
          radius * 2,
          alpha: .74 * fade,
          ambient: ambient,
        );
        for (final p in const [
          Offset(-.42, -.26),
          Offset(.42, -.14),
          Offset(.08, .30),
        ]) {
          AttackVfx.stamp(
            canvas,
            6 + (age * 5).floor(),
            p * radius * travel,
            radius * (shards ? .68 : .55),
            alpha: fade,
            material: AttackMaterial.glass,
          );
        }
        _debris(canvas, radius, travel, fade, const Color(0xffb9d8da), 6);
      case ExpeditionCue.curtain:
        AttackVfx.groundMaterial(
          canvas,
          2,
          Offset.zero,
          radius * 1.65,
          height: radius * .73,
          alpha: .38 * fade,
          ambient: ambient,
        );
        _debris(canvas, radius, travel, fade, const Color(0xffb8b6a4), 9);
      case ExpeditionCue.thunder:
      case ExpeditionCue.deadeye:
      case ExpeditionCue.quickdraw:
        final extent = radius * .29;
        AttackVfx.stamp(
          canvas,
          2,
          Offset.zero,
          extent * 2,
          alpha: .78 * fade,
          grading: ambient,
        );
        final tint = cue == ExpeditionCue.quickdraw
            ? const Color(0xffe7be80)
            : const Color(0xffb5d5d7);
        _debris(canvas, extent, travel, fade, tint, 6);
      case ExpeditionCue.blood:
      case ExpeditionCue.quickdrawChamber:
        // The survivor's green recovery marks are painted by CombatEffect.
        break;
    }
  }

  static void _fracture(
    Canvas canvas,
    List<Offset> split,
    double fade, {
    required double width,
  }) {
    final wall = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xff211a17).withValues(alpha: .90 * fade);
    final lip = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xffad987b).withValues(alpha: .69 * fade);
    final recessed = Path(), exposed = Path();
    void chip(Path path, List<Offset> corners) =>
        path.addPolygon(corners.map(AttackVfx.snap).toList(), true);

    for (var index = 0; index < split.length - 1; index++) {
      final start = split[index], end = split[index + 1];
      final delta = end - start, length = delta.distance;
      if (length < 5) continue;
      final axis = delta / length, side = Offset(-axis.dy, axis.dx);
      final segments = (length / 8).ceil();
      for (var part = 0; part < segments; part++) {
        final at = start + delta * (part / segments);
        final next = start + delta * ((part + 1) / segments);
        final turn = (part + index).isEven ? 1.0 : -1.0;
        final debris = side * width * (.55 + (part % 3) * .18) * turn;
        chip(recessed, [
          at - debris,
          at + debris,
          next + debris * .35,
          next - debris * .65,
        ]);
        if ((part + 2 * index) % 3 != 1) {
          chip(exposed, [
            at + debris,
            at + debris * 1.7,
            next + debris * .72,
            next + debris * .30,
          ]);
        }
      }
    }
    canvas.drawPath(recessed, wall);
    canvas.drawPath(exposed, lip);
  }

  static void _debris(
    Canvas canvas,
    double radius,
    double travel,
    double fade,
    Color ink,
    int count,
  ) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2.39996;
      final length = radius * travel * (.34 + (i % 4) * .15);
      final point = Offset(
        math.cos(angle) * length,
        math.sin(angle) * length * .76,
      );
      AttackVfx.chip(
        canvas,
        point + const Offset(2, 5),
        7,
        const Color(0xff211915).withValues(alpha: fade * .72),
      );
      AttackVfx.chip(
        canvas,
        point,
        4 + (i % 3) * 2,
        ink.withValues(alpha: fade),
      );
    }
  }
}
