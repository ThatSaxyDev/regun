import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Anchor;
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/walker_combat.dart';

class WalkerBattleArt {
  const WalkerBattleArt(this.assets);
  final WalkerAssets assets;

  void floor(Canvas c, WalkerCombat fight, ArenaType arena, bool reduced) {
    final grade = BossArt.ambient(arena), at = fight.rig.position;
    if (fight.phase == WalkerPhase.incoming ||
        fight.phase == WalkerPhase.descending) {
      final p = fight.phase == WalkerPhase.incoming ? fight.clock / 1.3 : 1.0;
      c.drawOval(
        Rect.fromCenter(
          center: at + const Offset(0, 40),
          width: 120 + 175 * p,
          height: 70 + 90 * p,
        ),
        Paint()..color = Color.fromRGBO(6, 9, 7, .18 + p * .35),
      );
      for (final x in [-1.0, 1.0]) {
        for (final y in [-1.0, 1.0]) {
          AttackVfx.stamp(
            c,
            0,
            at + Offset(x * 155, y * 125),
            75,
            height: 45,
            alpha: .5,
            grading: grade,
          );
        }
      }
    }
    if (fight.phase == WalkerPhase.landing) {
      for (final foot in fight.rig.legs) {
        AttackVfx.groundMaterial(
          c,
          1,
          foot.foot + WalkerCombat.visualOffset,
          115 + fight.clock * 50,
          height: 60,
          alpha: .6 * (1 - fight.clock / .8).clamp(0, 1),
          ambient: grade,
        );
      }
    }
    if (fight.phase == WalkerPhase.chargeLock ||
        fight.phase == WalkerPhase.charge ||
        fight.phase == WalkerPhase.brake) {
      for (final foot in fight.rig.legs) {
        AttackVfx.stamp(
          c,
          0,
          foot.foot + WalkerCombat.visualOffset,
          65,
          height: 24,
          alpha: .45,
          grading: grade,
        );
      }
    }
    if (fight.phase == WalkerPhase.chargeLock ||
        fight.phase == WalkerPhase.charge) {
      final center = fight.rushLanding;
      for (var i = 0; i < 16; i++) {
        AttackVfx.groundMaterial(
          c,
          1,
          center + WalkerCombat.unit(i * math.pi / 8) * WalkerCombat.rushRadius,
          48,
          height: 28,
          alpha: .6,
          ambient: grade,
        );
      }
    }
    if (fight.phase == WalkerPhase.failing) {
      final alpha = .35 + .35 * (fight.clock / 2.6).clamp(0, 1);
      // Material scuffs bracket the actual blast footprint. No flat colour disk.
      for (var i = 0; i < 24; i++) {
        final p =
            at + WalkerCombat.unit(i * math.pi / 12) * WalkerCombat.deathRadius;
        AttackVfx.groundMaterial(
          c,
          1,
          p,
          72,
          height: 48,
          alpha: alpha,
          ambient: grade,
        );
        c.drawRect(
          Rect.fromCenter(center: p, width: 5, height: 5),
          Paint()..color = Color.fromRGBO(207, 135, 81, alpha),
        );
      }
    }
    for (final blast in fight.blasts) {
      if (blast.landing) {
        final progress = (blast.age / .65).clamp(0.0, 1.0);
        for (var i = 0; i < 16; i++) {
          AttackVfx.groundMaterial(
            c,
            1,
            blast.position +
                WalkerCombat.unit(i * math.pi / 8) * blast.radius * progress,
            85,
            height: 50,
            alpha: .8 * (1 - progress),
            ambient: grade,
          );
        }
        continue;
      }
      AttackVfx.explosion(
        c,
        blast.position,
        blast.radius,
        progress: (blast.age / (blast.death ? 2.1 : .65)).clamp(0, 1),
        ambient: grade,
        reducedMotion: reduced,
      );
    }
  }

  void body(
    Canvas c,
    WalkerCombat fight, {
    bool reduced = false,
    ColorFilter? flash,
  }) {
    if (fight.phase == WalkerPhase.incoming) return;
    final art = WalkerArt(assets, flashFilter: flash);
    if (fight.phase.index >= WalkerPhase.detonation.index) {
      art.part(c, 'wreck', fight.rig.position, 224, angle: fight.rig.yaw);
      return;
    }
    c.save();
    if (reduced && fight.phase == WalkerPhase.descending) {
      c.saveLayer(
        null,
        Paint()
          ..color = Color.fromRGBO(
            255,
            255,
            255,
            (fight.clock / .9).clamp(0, 1),
          ),
      );
    }
    c.translate(
      WalkerCombat.visualOffset.dx,
      WalkerCombat.visualOffset.dy - (reduced ? 0 : fight.descent),
    );
    art.paint(c, fight.rig, combat: fight);
    if (fight.phase == WalkerPhase.descending ||
        fight.phase == WalkerPhase.chargeLock ||
        fight.phase == WalkerPhase.charge ||
        fight.phase == WalkerPhase.brake ||
        fight.phase == WalkerPhase.failing) {
      for (final side in [-1.0, 1.0]) {
        final nozzle = fight.rig
            .point(Offset(-73, side * 30), fight.rig.height - 6)
            .projected;
        final large = fight.phase == WalkerPhase.charge;
        AttackVfx.stamp(
          c,
          18 + (fight.elapsed * 12).floor() % 3,
          nozzle - WalkerCombat.unit(fight.rig.yaw) * (large ? 40 : 15),
          large ? 115 : 62,
          height: large ? 55 : 35,
          alpha: reduced ? .55 : .8,
          material: AttackMaterial.ember,
          anchor: Anchor.center,
        );
      }
    }
    if (reduced && fight.phase == WalkerPhase.descending) c.restore();
    c.restore();
    for (final cannon in [false, true]) {
      if (fight.phase !=
              (cannon ? WalkerPhase.cannonLock : WalkerPhase.rotaryLock) &&
          (cannon || fight.phase != WalkerPhase.burstLock)) {
        continue;
      }
      final from = fight.muzzle(cannon);
      final dir = WalkerCombat.unit(
        cannon ? fight.cannonYaw : fight.rig.turretYaw,
      );
      var lo = 0.0, hi = 1150.0;
      for (var i = 0; i < 12; i++) {
        final mid = (lo + hi) / 2;
        if (fight.clear(from, from + dir * mid, 0)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      c.drawLine(
        from,
        from + dir * lo,
        Paint()
          ..color = const Color(0xffC96B50)
              .withValues(alpha: .48 + .3 * (fight.clock / 1.2).clamp(0, 1))
          ..strokeWidth = 1.8
          ..isAntiAlias = false,
      );
    }
  }

  void ordnance(Canvas c, WalkerCombat fight, ArenaType arena, bool reduced) {
    final art = WalkerArt(assets);
    for (final round in fight.rounds) {
      if (round.kind == WalkerRoundKind.rocket) {
        art.part(c, 'rocket', round.position, 48, angle: round.heading);
        if (!reduced) {
          AttackVfx.stamp(
            c,
            18 + (round.age * 12).floor() % 3,
            round.position - WalkerCombat.unit(round.heading) * 31,
            round.pursuing ? 45 : 25,
            height: 18,
            alpha: .7,
            anchor: Anchor.center,
            material: AttackMaterial.ember,
          );
        }
      } else {
        c.save();
        c.translate(round.position.dx, round.position.dy);
        c.rotate(round.heading);
        final cannon = round.kind == WalkerRoundKind.cannon;
        c.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: cannon ? 31 : 21,
            height: cannon ? 15 : 7,
          ),
          Paint()..color = const Color(0xff171B16),
        );
        c.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: cannon ? 25 : 17,
            height: cannon ? 10 : 4,
          ),
          Paint()
            ..color = cannon
                ? const Color(0xff8E957F)
                : const Color(0xffDBB474),
        );
        c.drawRect(
          Rect.fromLTWH(cannon ? 7 : 5, cannon ? -3 : -1, 4, cannon ? 6 : 2),
          Paint()..color = const Color(0xffECE0B1),
        );
        c.restore();
      }
    }
    for (final blast in fight.blasts) {
      if (blast.age > .45) continue;
      AttackVfx.stamp(
        c,
        18 + (blast.age * 12).floor() % 3,
        blast.position,
        blast.death ? 420 : 130,
        height: blast.death ? 310 : 96,
        alpha: (1 - blast.age / .45).clamp(0, 1) * (reduced ? .45 : .75),
        material: AttackMaterial.ember,
        anchor: Anchor.center,
      );
    }
  }
}
