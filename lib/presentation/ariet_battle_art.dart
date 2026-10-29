import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Anchor;
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/ariet_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/walker_rig.dart';

class ArietBattleArt {
  const ArietBattleArt(this.assets);
  final ArietAssets assets;
  void floor(Canvas c, ArietCombat f, ArenaType arena, bool reduced) {
    final grade = BossArt.ambient(arena), at = f.rig.position;
    c.save();
    c.translate(at.dx, at.dy + 12);
    c.rotate(f.rig.yaw);
    for (final (centre, width, height) in [
      (Offset.zero, 326.0, 155.0),
      (const Offset(-8, -142), 218.0, 86.0),
      (const Offset(-8, 142), 218.0, 86.0),
    ]) {
      // Broad, restrained penumbra and a faint inner core stay on the floor.
      // The aircraft's lift is never added to its ground shadow position.
      for (final (spread, alpha) in [(18.0, .09), (0.0, .22)]) {
        c.drawOval(
          Rect.fromCenter(
            center: centre,
            width: width + spread,
            height: height + spread,
          ),
          Paint()..color = const Color(0xff0C120F).withValues(alpha: alpha),
        );
      }
    }
    c.restore();
    if (f.phase == ArietPhase.incoming || f.phase == ArietPhase.descent) {
      AttackVfx.floorArea(c, 0, at, 320, alpha: .6, ambient: grade);
    }
    if ([
      ArietPhase.strafeLock,
      ArietPhase.strafe,
      ArietPhase.strafeBrake,
    ].contains(f.phase)) {
      final d = f.routeEnd - f.routeStart,
          side = Offset(-f.routeHeading.dy, f.routeHeading.dx);
      final steps = (d.distance / 85).ceil().clamp(1, 16);
      for (var i = 0; i <= steps; i++) {
        final p = Offset.lerp(f.routeStart, f.routeEnd, i / steps)!;
        for (final sign in [-1.0, 1.0]) {
          AttackVfx.groundMaterial(
            c,
            1,
            p + side * 95 * sign,
            27,
            height: 16,
            alpha: .55,
            ambient: grade,
          );
        }
      }
      AttackVfx.floorArea(c, 0, f.routeEnd, 130, alpha: .6, ambient: grade);
    }
    for (final target in f.flakTargets) {
      AttackVfx.floorArea(c, 0, target, 162, alpha: .8, ambient: grade);
    }
    if (f.phase == ArietPhase.seekerLock) {
      AttackVfx.floorArea(c, 0, f.locked, 100, alpha: .65, ambient: grade);
    }
    for (final shape in f.exhaust) {
      final steps = ((shape.b - shape.a).distance / 40).ceil().clamp(1, 4);
      for (var i = 0; i <= steps; i++) {
        final p = Offset.lerp(shape.a, shape.b, i / steps)!;
        if (f.phase == ArietPhase.exhaust) {
          AttackVfx.groundMaterial(
            c,
            0,
            p,
            shape.radius * 2,
            height: shape.radius * 1.4,
            alpha: reduced ? .5 : .8,
            ambient: grade,
          );
        } else {
          AttackVfx.floorArea(
            c,
            0,
            p,
            shape.radius * 2,
            alpha: .8,
            ambient: grade,
          );
        }
      }
    }
    for (final drop in f.drops) {
      if (drop.aborted || drop.activated) continue;
      AttackVfx.floorArea(c, 0, drop.landing, 145, alpha: .75, ambient: grade);
      if (drop.origin != null) {
        c.drawOval(
          Rect.fromCenter(center: drop.shadowPosition, width: 112, height: 55),
          Paint()..color = const Color(0x550D130F),
        );
      }
    }
    for (final i in f.impacts) {
      if (i.rocketHeading != null) continue;
      if (i.dust) {
        AttackVfx.groundMaterial(
          c,
          0,
          i.position,
          i.radius * 2,
          height: i.radius,
          alpha: .6 * (1 - i.age / .65),
          ambient: grade,
        );
      } else {
        AttackVfx.explosion(
          c,
          i.position,
          i.radius,
          progress: i.age / .65,
          ambient: grade,
          reducedMotion: reduced,
        );
      }
    }
  }

  void _payload(
    Canvas c,
    Offset at,
    double yaw,
    double unpack, {
    double alpha = 1,
  }) {
    final p = unpack.clamp(0.0, 1.0), eased = p * p * (3 - 2 * p);
    final rig =
        WalkerRig(
            foldedReach: .28 + .72 * eased,
            foldedAnkleZ: 72 * (1 - eased),
            foldedKneeDown: true,
            foldedPoleAngle: eased * math.pi,
            barrelLength: 158,
          )
          ..folded = true
          ..trackTurret = false
          ..yaw = yaw
          ..turretYaw = yaw + math.pi / 2
          ..turretPitch = -.6 * (1 - eased)
          ..height = 48 + 40 * eased;
    for (final l in rig.legs) {
      l.foot = rig.ground(l.rest * rig.foldedReach);
      l.footYaw = yaw + math.atan2(l.rest.dy, l.rest.dx);
    }
    c.save();
    c.translate(at.dx, at.dy + rig.height * .7 * .675);
    c.scale(.675);
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    }
    WalkerArt(assets.walker).paint(c, rig, groundShadows: false);
    if (alpha < 1) c.restore();
    c.restore();
  }

  void body(
    Canvas c,
    ArietCombat f,
    bool reduced,
    ColorFilter? flash, {
    ArenaType arena = ArenaType.breach,
  }) {
    if (f.phase == ArietPhase.incoming || f.finished) return;
    final rig = f.rig;
    c.save();
    if (f.phase == ArietPhase.wreck) {
      c.saveLayer(
        null,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, (2 - f.clock).clamp(0, 1)),
      );
    }
    if (reduced && f.phase == ArietPhase.descent) {
      c.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, f.clock.clamp(0, 1)),
      );
    }
    c.translate(0, reduced ? 0 : -f.descent);
    if (!f.deploymentSpent && f.drops.isEmpty && !f.defeated) {
      for (var i = 0; i < 2; i++) {
        _payload(c, rig.cargoReleaseSocket(i), rig.yaw, 0);
      }
    }
    for (final d in f.drops) {
      if (d.aborted || d.activated) continue;
      if (d.origin == null) {
        _payload(c, rig.cargoReleaseSocket(d.id - 1), rig.yaw, 0);
      } else {
        final at = reduced ? d.landing : d.position;
        _payload(
          c,
          at,
          rig.yaw,
          ((d.age - .9) / .5).clamp(0, 1),
          alpha: reduced ? d.fall : 1,
        );
      }
    }
    final art = ArietArt(
      assets,
      flashFilter:
          flash ??
          (f.defeated
              ? const ColorFilter.mode(Color(0xff615B4A), BlendMode.modulate)
              : null),
    );
    art.paint(
      c,
      rig,
      groundShadows: false,
      noseAngles: f.noseYaw,
      noseRecoil: f.recoil,
      cannonRecoil: f.cannonRecoil,
      flakRecoil: f.flakRecoil,
      launcherFlash: f.launcherFlash,
      launcherCell: f.launcherCell,
    );
    if (f.defeated) {
      for (final sign in [-1, 1]) {
        AttackVfx.stamp(
          c,
          1,
          rig.project(Offset(-10, sign * 110.0)),
          75,
          alpha: .5,
          material: AttackMaterial.stone,
          anchor: Anchor.center,
        );
      }
    }
    if (f.phase == ArietPhase.wreck) c.restore();
    if (reduced && f.phase == ArietPhase.descent) c.restore();
    c.restore();
    if ([ArietPhase.cannonLock, ArietPhase.cannon].contains(f.phase)) {
      final from = f.cannonMuzzle, dir = ArietCombat.unit(rig.cannonYaw);
      var lo = 0.0, hi = 1000.0;
      for (var n = 0; n < 12; n++) {
        final m = (lo + hi) / 2;
        if (f.clear(from, from + dir * m, 0)) {
          lo = m;
        } else {
          hi = m;
        }
      }
      final count = (lo / 45).ceil().clamp(1, 28);
      for (var i = 1; i <= count; i++) {
        AttackVfx.groundMaterial(
          c,
          1,
          from + dir * (lo * i / count),
          24,
          height: 12,
          alpha: .7,
          ambient: BossArt.ambient(arena),
        );
      }
    }
    for (var i = 0; i < 2; i++) {
      if (f.flash[i] > 0) {
        AttackVfx.stamp(
          c,
          18,
          f.noseMuzzle(i),
          35,
          height: 20,
          material: AttackMaterial.ember,
          anchor: Anchor.center,
        );
      }
    }
    if (f.flakFlash > 0) {
      AttackVfx.stamp(
        c,
        18,
        f.flakMuzzle,
        46,
        height: 25,
        material: AttackMaterial.ember,
        anchor: Anchor.center,
      );
    }
    if (f.launcherFlash > 0) {
      AttackVfx.stamp(
        c,
        18,
        rig.launcherSocket,
        50,
        height: 35,
        material: AttackMaterial.ember,
        anchor: Anchor.center,
      );
    }
    if (f.cannonFlash > 0) {
      AttackVfx.stamp(
        c,
        18,
        f.cannonMuzzle,
        62,
        height: 32,
        material: AttackMaterial.ember,
        anchor: Anchor.center,
      );
    }
  }

  void rounds(Canvas c, ArietCombat f, ArenaType arena, bool reduced) {
    for (final spent in f.impacts) {
      final angle = spent.rocketHeading;
      if (angle == null) continue;
      final p = (spent.age / .4).clamp(0.0, 1.0);
      ArietArt(assets).engineSprite(
        c,
        2,
        spent.position - ArietCombat.unit(angle) * 24,
        32 + p * 28,
        height: 24 + p * 16,
        angle: angle + math.pi,
        alpha: .4 * (1 - p),
      );
      WalkerArt(assets.walker)
          .part(c, 'rocket', spent.position, 64, angle: angle, alpha: 1 - p);
    }
    for (final r in f.rounds) {
      if (r.seeker) {
        final d = ArietCombat.unit(r.heading);
        ArietArt(assets).engineSprite(
          c,
          0,
          r.position - d * 28,
          30,
          height: 13,
          angle: r.heading + math.pi,
          alpha: .8,
          jet: true,
        );
        WalkerArt(assets.walker)
            .part(c, 'rocket', r.position, 64, angle: r.heading);
        continue;
      }
      if (r.fragment) {
        ArietArt(assets).part(c, 'pylon', r.position, 18, 9, angle: r.heading);
        continue;
      }
      c.save();
      c.translate(r.position.dx, r.position.dy);
      c.rotate(r.heading);
      final width = r.cannon ? 30.0 : 18.0, height = r.cannon ? 13.0 : 6.0;
      c.drawRect(
        Rect.fromCenter(
          center: const Offset(0, 1),
          width: width + 4,
          height: height + 4,
        ),
        Paint()..color = const Color(0xff24251E),
      );
      c.drawRect(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        Paint()
          ..color = r.cannon
              ? const Color(0xffC09A69)
              : const Color(0xffD9C08A),
      );
      c.drawRect(
        Rect.fromLTWH(-width / 2 + 2, -1, width - 5, 2),
        Paint()..color = const Color(0xffEEE0BA),
      );
      c.restore();
    }
  }
}
