import 'dart:math' as math;

import 'package:flame/components.dart' show Anchor;
import 'package:flutter/painting.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';

class LodestarBattleArt {
  const LodestarBattleArt(this.assets);
  final LodestarAssets assets;
  String _ground(String name, ArenaType arena) =>
      arena == ArenaType.foundry ? '${name}Foundry' : name;
  void floor(Canvas c, LodestarCombat f, ArenaType arena, bool reduced) {
    final grade = BossArt.ambient(arena), art = LodestarArt(assets);
    if (f.phase == LodestarPhase.warning) {
      final stride = math.max(1, (f.warnedSweep.length / 6).ceil());
      for (var i = 0; i < f.warnedSweep.length; i += stride) {
        final shape = f.warnedSweep[i];
        art.part(
          c,
          'metalScuff',
          (shape.a + shape.b) / 2,
          Size(
            (shape.b - shape.a).distance + shape.radius * 2,
            shape.radius * 4,
          ),
          LodestarCombat.heading(shape.b - shape.a),
          alpha: .55 + .3 * f.age / f.warning(f.move),
        );
      }
    }
    if ([
      LodestarPhase.underground,
      LodestarPhase.exitWarning,
      LodestarPhase.emerging,
    ].contains(f.phase)) {
      final closed = f.phase == LodestarPhase.emerging;
      art.part(
        c,
        closed ? _ground('burrowMound', arena) : _ground('burrowMouth', arena),
        f.entry,
        const Size(315, 280),
        0,
        alpha: closed ? (1 - f.age / 1.0).clamp(0.0, 1.0) : 1,
      );
    }
    if ([
          LodestarPhase.arrival,
          LodestarPhase.entry,
          LodestarPhase.emerging,
        ].contains(f.phase) ||
        (f.defeated && f.depths.any((d) => d > 0))) {
      final forming = f.phase == LodestarPhase.entry
          ? (f.age / .32).clamp(0.0, 1.0)
          : 1.0;
      art.part(
        c,
        f.sinking || f.phase == LodestarPhase.arrival
            ? _ground('burrowMouth', arena)
            : _ground('burrowExit', arena),
        f.mouth,
        const Size(315, 280),
        0,
        alpha: forming * f.wreckOpacity,
      );
      final crossing = f.rig.poses.any(
        (p) => f.depths[p.section.index] > 0 && f.depths[p.section.index] < 1,
      );
      if (crossing && !f.defeated) {
        art.part(
          c,
          _ground('burrowDust', arena),
          f.mouth,
          const Size(250, 210),
          0,
          alpha: reduced ? .18 : .33,
        );
      }
    }
    if (f.phase == LodestarPhase.exitWarning) {
      // A planted mound lifts where the committed head will break through.
      // No decal translates across the map and no hot cracks imply lava.
      final progress = (f.age / .95).clamp(0.0, 1.0);
      art.part(
        c,
        _ground('burrowMound', arena),
        f.exit,
        Size(
          280 + (reduced ? 0 : progress * 18),
          245 + (reduced ? 0 : progress * 12),
        ),
        0,
        alpha: .65 + .35 * progress,
      );
      art.part(
        c,
        _ground('burrowDust', arena),
        f.exit,
        const Size(300, 255),
        0,
        alpha: progress * .25,
      );
    }
    for (final s in f.shots.where((s) => s.shell)) {
      art.part(
        c,
        'impactMark',
        s.target,
        const Size(280, 280),
        0,
        alpha: .65 + .35 * (s.age / s.duration).clamp(0.0, 1.0),
      );
      c.drawOval(
        Rect.fromCenter(center: s.position, width: 25, height: 12),
        Paint()..color = const Color(0x700D100D),
      );
    }
    for (final m in f.mines) {
      if (m.removed) continue;
      if (m.trigger >= 0) {
        art.part(
          c,
          'impactMark',
          m.position,
          const Size(365, 365),
          0,
          alpha: .65 + .35 * (m.trigger / .85).clamp(0.0, 1.0),
        );
      }
      if (!m.flying) {
        LodestarArt(assets).part(
          c,
          'mine',
          m.position,
          const Size(38, 34),
          0,
          alpha: m.age > 11 ? ((12 - m.age)).clamp(0, 1) : 1,
        );
        // Quiet brass mechanical arm indicator; no electrical anchor effect.
        for (var n = 0; n < 4; n++) {
          final at = m.position + LodestarCombat.unit(n * math.pi / 2) * 21;
          AttackVfx.chip(
            c,
            at,
            3,
            m.armed ? const Color(0xffAF9E70) : const Color(0xff555B50),
          );
        }
      }
    }
    for (final b in f.bursts) {
      if (b.blast && !b.excavation) {
        AttackVfx.explosion(
          c,
          b.position,
          b.radius,
          progress: b.age / 1.1,
          ambient: grade,
          reducedMotion: reduced,
        );
      } else {
        art.part(
          c,
          _ground('burrowDust', arena),
          b.position,
          Size(b.radius * 2, b.radius * 1.7),
          0,
          alpha: (1 - b.age / 1.1) * .65,
        );
      }
    }
    for (final p in f.rig.poses) {
      final at = f.hits[p.section];
      if (!f.defeated &&
          !f.sections.living(p.section) &&
          at != null &&
          f.elapsed - at < 1.1) {
        art.part(
          c,
          p.section == LodestarSection.head ? 'headWreck' : 'weaponWreck',
          p.position,
          const Size(105, 80),
          p.yaw,
          alpha: (1 - (f.elapsed - at) / 1.1) * .7,
        );
      }
    }
  }

  void body(Canvas c, LodestarCombat f, bool reduced, {int? section}) {
    final art = LodestarArt(assets), poses = f.rig.poses;
    if (f.finished) return;
    for (var i = 0; i < 5; i++) {
      if (section != null && i != section) continue;
      final alpha = f.depths[i] >= 1 && f.depths[i + 1] >= 1
          ? 0.0
          : f.wreckOpacity;
      if (alpha <= 0) continue;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
      if (f.depths[i] > 0 || f.depths[i + 1] > 0) {
        c.translate(f.mouth.dx, f.mouth.dy);
        c.rotate(f.course);
        c.clipRect(
          f.sinking
              ? const Rect.fromLTRB(-10000, -10000, 0, 10000)
              : const Rect.fromLTRB(0, -10000, 10000, 10000),
        );
        c.rotate(-f.course);
        c.translate(-f.mouth.dx, -f.mouth.dy);
      }
      art.coupling(c, f.rig.couplings[i]);
      c.restore();
    }
    // Individual parts depth sort, never one enclosing body circle or six
    // independent damage/proc owners. Ground siblings stay below all actors.
    final order = poses.toList()
      ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (final p in order) {
      if (section != null && p.section.index != section) continue;
      final depth = f.depths[p.section.index];
      if (depth >= 1) continue;
      if (!c.getLocalClipBounds().inflate(180).contains(p.position)) continue;
      c.save();
      if (f.defeated) {
        c.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(255, 255, 255, f.wreckOpacity),
        );
      }
      if (depth > 0) {
        c.translate(f.mouth.dx, f.mouth.dy);
        c.rotate(f.course);
        c.clipRect(
          f.sinking
              ? const Rect.fromLTRB(-10000, -10000, 0, 10000)
              : const Rect.fromLTRB(0, -10000, 10000, 10000),
        );
        c.rotate(-f.course);
        c.translate(-f.mouth.dx, -f.mouth.dy);
      }
      final collapse = f.collapse(p.section);
      final live = !f.defeated
          ? f.sections.living(p.section)
          : f.shutdownIntact(p.section) && collapse < 1;
      final stamp = f.hits[p.section],
          flash = stamp == null
              ? 0.0
              : (1 - (f.elapsed - stamp) / .24).clamp(0.0, 1.0);
      art.carriage(
        c,
        p,
        broken: !live,
        signedTravel: f.rig.rollerTravel,
        feeder: live && p.section == LodestarSection.feeder,
        mechanism: live ? f.feederProgress : 0,
        flash: reduced ? 0 : flash,
      );
      if (f.defeated && collapse > 0) {
        art.part(
          c,
          p.section == LodestarSection.head ? 'headWreck' : 'weaponWreck',
          p.position + Offset(0, reduced ? 0 : collapse * 5),
          const Size(108, 80),
          p.yaw,
          alpha: collapse,
        );
      }
      if (live) {
        c.save();
        if (f.defeated) {
          c.translate(p.position.dx, p.position.dy);
          if (!reduced) c.scale(1, 1 - collapse * .18);
          c.translate(-p.position.dx, -p.position.dy);
          c.saveLayer(
            null,
            Paint()..color = Color.fromRGBO(255, 255, 255, 1 - collapse),
          );
        }
        final firing =
            f.phase == LodestarPhase.firing && f.owner(f.move) == p.section;
        final warning =
            f.phase == LodestarPhase.warning && f.owner(f.move) == p.section;
        final double recoil = f.weaponKick(f.move) * 9;
        switch (p.section) {
          case LodestarSection.head:
            if (f.sections.coreExposed) {
              // Open the existing armored shell into two planted halves. The
              // exposed mechanical core remains visible without a flashing light.
              c.save();
              c.translate(p.position.dx, p.position.dy);
              c.rotate(p.yaw);
              art.part(c, 'cutter', const Offset(20, 0), const Size(70, 42), 0);
              for (var n = -2; n <= 2; n++) {
                AttackVfx.chip(
                  c,
                  Offset(20 + n * 6, 0),
                  6,
                  const Color(0xffE4B886),
                );
              }
              final opening = reduced
                  ? 1.0
                  : ((f.elapsed - f.coreOpenedAt) / .45).clamp(0.0, 1.0);
              for (final side in [-1.0, 1.0]) {
                c.save();
                c.translate(0, side * 18 * opening);
                c.clipRect(
                  Rect.fromLTRB(
                    -100,
                    side < 0 ? -100 : 0,
                    120,
                    side < 0 ? 0 : 100,
                  ),
                );
                art.part(
                  c,
                  'head',
                  const Offset(16, 0),
                  const Size(144, 120),
                  0,
                );
                c.restore();
              }
              c.restore();
            } else {
              art.part(
                c,
                'head',
                p.socket(const Offset(16, 0)),
                const Size(144, 120),
                p.yaw,
              );
            }
            final boring =
                f.phase == LodestarPhase.entry ||
                f.phase == LodestarPhase.underground ||
                (f.phase == LodestarPhase.emerging && depth > 0) ||
                (warning && f.move == LodestarMove.burrow);
            if (boring) {
              art.part(
                c,
                'cutter',
                p.socket(const Offset(48, 0)),
                const Size(70, 40),
                p.yaw,
              );
              if (!reduced) {
                for (var tooth = 0; tooth < 4; tooth++) {
                  AttackVfx.chip(
                    c,
                    p.socket(
                      Offset(
                        31 + tooth * 12,
                        ((f.elapsed * 45 + tooth * 4) % 24) - 12,
                      ),
                    ),
                    3,
                    const Color(0xffA6A28C),
                  );
                }
              }
            }
            final opening = boring
                ? 0.0
                : warning
                ? .35 * (f.age / .8).clamp(0, 1)
                : firing
                ? .35 * (1 - f.age / .24).clamp(0, 1)
                : .09;
            for (final side in [-1.0, 1.0]) {
              final at = p.socket(Offset(27, side * 19));
              c.save();
              c.translate(at.dx, at.dy);
              c.rotate(p.yaw + side * opening);
              c.scale(1, side);
              art.part(c, 'jaw', const Offset(28, 0), const Size(79, 32), 0);
              c.restore();
            }
          case LodestarSection.accelerator:
            final yaw = (warning || firing)
                ? f.shardYaw
                : LodestarCombat.heading(f.player - p.position);
            art.part(
              c,
              'shards',
              p.position - LodestarCombat.unit(yaw) * recoil,
              const Size(100, 62),
              yaw.toDouble(),
            );
            if (warning) {
              final charge = (f.age / f.warning(f.move)).clamp(0.0, 1.0);
              for (var n = 0; n < 3; n++) {
                AttackVfx.chip(
                  c,
                  p.position + LodestarCombat.unit(yaw) * (n * 12 - 15),
                  4,
                  Color.lerp(
                    const Color(0xff4B4C3C),
                    const Color(0xffD4BA83),
                    charge,
                  )!,
                );
              }
            }
            if (f.muzzleLit(LodestarMove.shards)) {
              AttackVfx.stamp(
                c,
                18,
                p.position + LodestarCombat.unit(yaw) * 69,
                40,
                alpha: .85,
                material: AttackMaterial.ember,
                anchor: Anchor.center,
              );
            }
          case LodestarSection.mortars:
            final yaw = LodestarCombat.heading(
              (warning || firing ? f.aim : f.player) - p.position,
            );
            art.part(c, 'mortarBase', p.position, const Size(88, 74), yaw);
            for (var tube = 0; tube < 2; tube++) {
              final local = Offset(-f.mortarRecoil(tube), tube == 0 ? -20 : 20);
              final mount =
                  p.position +
                  LodestarCombat.unit(yaw) * local.dx +
                  LodestarCombat.unit(yaw + math.pi / 2) * local.dy -
                  Offset(0, math.sin(f.mortarElevation) * 14);
              art.part(
                c,
                'mortarTube',
                mount,
                Size(82 * math.cos(f.mortarElevation), 33),
                yaw,
              );
              if (f.elapsed -
                      (f.mortarRecoil(tube) > 0
                          ? f.elapsed - .16 * (1 - f.mortarRecoil(tube) / 9)
                          : -1000) <
                  .09) {
                AttackVfx.stamp(
                  c,
                  18,
                  f.mortarSocket(tube),
                  46,
                  alpha: .85,
                  material: AttackMaterial.ember,
                  anchor: Anchor.center,
                );
              }
            }
          case LodestarSection.feeder:
            if (f.sections.living(LodestarSection.mortars) &&
                f.move == LodestarMove.mortars &&
                [
                  LodestarPhase.warning,
                  LodestarPhase.firing,
                ].contains(f.phase)) {
              final to = f.rig.poses[2].position;
              final progress = f.feederProgress;
              art.part(
                c,
                'shell',
                Offset.lerp(p.position, to, progress)!,
                const Size(28, 12),
                LodestarCombat.heading(to - p.position),
              );
            }
            break;
          case LodestarSection.mines:
            art.part(
              c,
              'projector',
              p.position,
              const Size(105, 66),
              LodestarCombat.heading(
                (warning || firing ? f.aim : f.player) - p.position,
              ),
            );
            if (warning) {
              final yaw = LodestarCombat.heading(f.aim - p.position);
              art.part(
                c,
                'mine',
                p.position + LodestarCombat.unit(yaw) * 38,
                const Size(30, 26),
                yaw,
              );
            }
          case LodestarSection.tail:
            art.part(
              c,
              'tail',
              p.socket(const Offset(-24, 0)),
              const Size(142, 76),
              p.yaw + math.pi,
            );
        }
      }
      if (live) {
        if (f.defeated) c.restore();
        c.restore();
      }
      if (f.defeated) c.restore();
      c.restore();
      if (!f.defeated && stamp != null && f.elapsed - stamp < .7) {
        final hp = f.sections.integrity(p.section);
        final label = TextPainter(
          text: TextSpan(
            text: p.section == LodestarSection.head && !f.sections.coreExposed
                ? 'ARMORED'
                : hp <= 0
                ? 'DISABLED'
                : '${p.section.name.toUpperCase()} ${hp.ceil()}',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 15,
              color: Color(0xffE5CAA0),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(c, p.position - Offset(label.width / 2, 75));
      }
    }
  }

  void ordnance(Canvas c, LodestarCombat f, ArenaType arena, bool reduced) {
    final art = LodestarArt(assets), grade = BossArt.ambient(arena);
    if ([
      LodestarPhase.arrival,
      LodestarPhase.entry,
      LodestarPhase.emerging,
    ].contains(f.phase)) {
      // The near stone lip occludes the machinery at the real mouth, providing
      // depth without making an exposed, damaging section transparent.
      c.save();
      c.translate(f.mouth.dx, f.mouth.dy);
      c.rotate(f.course);
      c.clipRect(const Rect.fromLTRB(-180, -160, -90, 160));
      c.rotate(-f.course);
      art.part(
        c,
        f.sinking || f.phase == LodestarPhase.arrival
            ? _ground('burrowMouth', arena)
            : _ground('burrowExit', arena),
        Offset.zero,
        const Size(315, 280),
        0,
      );
      c.restore();
    }
    for (final b in f.bursts.where((b) => b.excavation && b.age < .5)) {
      final t = (b.age / .5).clamp(0.0, 1.0);
      art.part(
        c,
        _ground('burrowDust', arena),
        b.position,
        Size(b.radius * (reduced ? 1.8 : 1.5 + t * .5), b.radius * 1.5),
        0,
        alpha: (1 - t) * .4,
      );
    }
    for (final s in f.shots) {
      final height = s.shell
          ? math.sin(math.pi * (s.age / s.duration).clamp(0, 1)) * 115
          : 0.0;
      final at = s.position - Offset(0, height);
      art.part(
        c,
        'shell',
        at,
        s.shell ? const Size(36, 18) : const Size(28, 8),
        LodestarCombat.heading(s.target - s.from),
      );
    }
    for (final m in f.mines.where((m) => m.flying && !m.removed)) {
      final height = math.sin(math.pi * m.age / .8) * 70;
      art.part(
        c,
        'mine',
        m.position - Offset(0, height),
        const Size(38, 34),
        reduced ? 0 : m.age * 3,
      );
    }
    for (final b in f.bursts.where(
      (b) => b.blast && !b.excavation && b.age < .45,
    )) {
      // Visible above-actor hot core; planted dust/scorch lives in floor().
      AttackVfx.stamp(
        c,
        18,
        b.position,
        b.radius * 1.1,
        alpha: (1 - b.age / .45) * .85,
        material: AttackMaterial.ember,
        anchor: Anchor.center,
        grading: grade,
      );
    }
  }
}
