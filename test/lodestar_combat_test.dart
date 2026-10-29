import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';

LodestarCombat fight({bool Function(int, String)? hurt}) => LodestarCombat(
  rig: LodestarRig(),
  bounds: const Rect.fromLTRB(-2000, -1500, 2000, 1500),
  clear: (a, b, r) =>
      const Rect.fromLTRB(-2000, -1500, 2000, 1500).deflate(r).contains(a) &&
      const Rect.fromLTRB(-2000, -1500, 2000, 1500).deflate(r).contains(b),
  poseLegal: (_) => true,
  hurt: hurt ?? (_, __) => true,
  signal: (_) {},
);
void step(LodestarCombat f, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    f.advance(1 / 120);
  }
}

void surface(LodestarCombat f) {
  f.phase = LodestarPhase.travel;
  f.depths.fillRange(0, 6, 0);
  f.player = const Offset(0, 250);
}

void main() {
  test('every offensive mechanism completes a finite moving sequence', () {
    for (final m in LodestarMove.values) {
      final f = fight();
      surface(f);
      f.player = m == LodestarMove.tail
          ? const Offset(-520, 230)
          : m == LodestarMove.bite
          ? const Offset(250, 0)
          : const Offset(0, 250);
      expect(f.stage(m), isTrue, reason: m.name);
      for (var i = 0; i < 120 * 10; i++) {
        f.advance(1 / 120);
        expect(f.shots.length, lessThanOrEqualTo(20));
        expect(f.mines.length, lessThanOrEqualTo(2));
        expect(LodestarRig.connected(f.rig.poses), isTrue);
      }
      if (m != LodestarMove.burrow) {
        expect(f.releases[m] ?? 0, greaterThan(0), reason: m.name);
      }
      expect(f.phase, isNot(LodestarPhase.arrival));
    }
  });
  test('break cancels local unreleased attacks, feeder trims pending salvo, emitted shells finish', () {
    final f = fight();
    surface(f);
    expect(f.stage(LodestarMove.mortars), isTrue);
    step(f, .94);
    expect(f.shots.length, 1);
    final hit = f.sections.primary(
      LodestarSection.feeder,
      25,
      LodestarHitLedger(),
    );
    f.localDamage(hit);
    step(f, .8);
    expect(f.releases[LodestarMove.mortars], 1);
    expect(f.shots, isNotEmpty);
    step(f, 1);
    expect(f.shots, isEmpty);
    final b = fight();
    surface(b);
    expect(b.stage(LodestarMove.shards), isTrue);
    b.localDamage(
      b.sections.primary(LodestarSection.accelerator, 30, LodestarHitLedger()),
    );
    step(b, 1);
    expect(b.releases[LodestarMove.shards] ?? 0, 0);
  });
  test('mine arming, committed trigger, disarm and expiry are bounded, pause freezes all', () {
    var hits = 0;
    final f = fight(
      hurt: (_, __) {
        hits++;
        return true;
      },
    );
    surface(f);
    final mine = LodestarMine(const Offset(0, 250), const Offset(0, 250), 10);
    f.mines.add(mine);
    step(f, 1.49);
    expect(hits, 0);
    f.paused = true;
    final age = mine.age;
    step(f, 2);
    expect(mine.age, age);
    f.paused = false;
    step(f, .05);
    expect(mine.trigger, greaterThanOrEqualTo(0));
    f.player = const Offset(500, 250);
    step(f, 1);
    expect(f.mines, isEmpty);
    expect(hits, 0);
    final disarm = LodestarMine(Offset.zero, Offset.zero, 11);
    f.mines.add(disarm);
    expect(f.disarm(disarm), isTrue);
    expect(f.disarm(disarm), isFalse);
    final expiry = LodestarMine(Offset.zero, const Offset(0, -800), 12);
    f.mines.add(expiry);
    step(f, 14);
    expect(f.mines.contains(expiry), isFalse);
  });
  test(
    'burrow is head-led, fixed exit warning and sequential visible emergence',
    () {
      final f = fight();
      surface(f);
      expect(f.stage(LodestarMove.burrow), isTrue);
      step(f, 1.1);
      expect(f.depths.first, greaterThan(f.depths.last));
      for (var n = 0; n < 1200 && f.phase != LodestarPhase.exitWarning; n++) {
        f.advance(1 / 120);
      }
      expect(f.phase, LodestarPhase.exitWarning);
      final exit = f.exit;
      f.player = const Offset(-600, -300);
      step(f, .5);
      expect(f.exit, exit);
      step(f, .46);
      expect(f.phase, LodestarPhase.emerging);
      step(f, .4);
      expect(f.depths.first, lessThan(f.depths.last));
      step(f, 3);
      expect(f.depths.every((d) => d == 0), isTrue);
    },
  );
  test(
    'defeat disarms everything, no feeder grind or new releases, finite wreck',
    () {
      final f = fight();
      surface(f);
      f.shots.add(LodestarShot(Offset.zero, const Offset(500, 0), 1));
      f.mines.add(LodestarMine(Offset.zero, const Offset(0, 400), 2));
      for (final s in [
        ...LodestarSection.values.where((s) => s.weapon),
        LodestarSection.head,
      ]) {
        f.localDamage(f.sections.primary(s, 100, LodestarHitLedger()));
      }
      expect(f.defeated, isTrue);
      expect(f.sections.total, 0);
      expect(f.shots, isEmpty);
      expect(f.mines, isEmpty);
      step(f, 4.5);
      expect(f.finished, isTrue);
    },
  );
  test(
    'normal and enraged locomotion sustain actual moving-player pressure',
    () {
      for (final phaseTwo in [false, true]) {
        final f = fight();
        surface(f);
        if (phaseTwo) {
          for (final s in [
            LodestarSection.feeder,
            LodestarSection.mortars,
            LodestarSection.accelerator,
          ]) {
            f.localDamage(f.sections.primary(s, 100, LodestarHitLedger()));
          }
        }
        var moving = 0, eligible = 0;
        for (var i = 0; i < 120 * 30; i++) {
          final t = i / 120;
          f.player = Offset(math.cos(t * .22) * 420, math.sin(t * .22) * 350);
          f.playerVelocity = Offset(
            -math.sin(t * .22) * 92,
            math.cos(t * .22) * 77,
          );
          f.advance(1 / 120);
          if ([
            LodestarPhase.travel,
            LodestarPhase.recovery,
          ].contains(f.phase)) {
            eligible++;
            if (f.rig.speed > 40) moving++;
          }
        }
        expect(
          moving / eligible,
          greaterThan(.85),
          reason: 'enraged=$phaseTwo',
        );
      }
    },
  );
  test(
    'ground mask shares a fixed opening and excludes invisible body contact',
    () {
      final f = fight();
      surface(f);
      expect(f.stage(LodestarMove.burrow), isTrue);
      step(f, 1.1);
      expect(f.phase, LodestarPhase.entry);
      final p = f.rig.poses.first, cut = f.maskCut(f.depths.first);
      expect((p.socket(Offset(cut, 0)) - f.entry).distance, lessThan(.01));
      final hidden = p.socket(const Offset(160, 0));
      expect(
        f.partShapes(p).every((s) => s.contact(hidden, hidden) == null),
        isTrue,
      );
      for (final s in [LodestarSection.accelerator, LodestarSection.mortars]) {
        f.localDamage(f.sections.primary(s, 100, LodestarHitLedger()));
      }
      final frozenDepths = List<double>.of(f.depths);
      final hits = f.sections.primary(
        LodestarSection.head,
        100,
        LodestarHitLedger(),
      );
      f.localDamage(hits);
      expect(f.phase, LodestarPhase.destruction);
      final original = f.exit;
      step(f, 4.5);
      expect(f.finished, isTrue);
      expect(f.depths, frozenDepths);
      expect(f.exit, original);
    },
  );
  test('buried defeat and rejected committed exit never release a damaging replacement', () {
    var accepted = 0;
    final f = fight(
      hurt: (_, __) {
        accepted++;
        return true;
      },
    );
    surface(f);
    f.stage(LodestarMove.burrow);
    for (var n = 0; n < 1200 && f.phase != LodestarPhase.exitWarning; n++) {
      f.advance(1 / 120);
    }
    expect(f.phase, LodestarPhase.exitWarning);
    f.destroy();
    step(f, 4.5);
    expect(f.finished, isTrue);
    expect(accepted, 0);
    expect(f.shots, isEmpty);
    expect(f.mines, isEmpty);
  });
  test('terminal core explosion is visible once, paused by active clock and never damages player', () {
    final sounds = <String>[];
    var hits = 0;
    final f = LodestarCombat(
      rig: LodestarRig(),
      bounds: const Rect.fromLTRB(-2000, -1500, 2000, 1500),
      clear: (_, __, ___) => true,
      poseLegal: (_) => true,
      hurt: (_, __) {
        hits++;
        return true;
      },
      signal: sounds.add,
    );
    surface(f);
    for (final s in [
      LodestarSection.accelerator,
      LodestarSection.mortars,
      LodestarSection.head,
    ]) {
      f.localDamage(f.sections.primary(s, 1000, LodestarHitLedger()));
    }
    step(f, 1.5);
    expect(f.bursts.any((b) => b.blast && b.radius == 205), isFalse);
    f.paused = true;
    step(f, 2);
    expect(f.age, closeTo(1.5, .01));
    f.paused = false;
    step(f, .2);
    expect(f.bursts.any((b) => b.blast && b.radius == 205), isTrue);
    expect(sounds.where((s) => s == 'blast.wav'), hasLength(1));
    final saved = f.checkpoint();
    final restored = fight();
    restored.restore(saved, continueRun: true);
    step(restored, 3);
    expect(restored.finished, isTrue);
    expect(hits, 0);
    step(f, 3);
    expect(sounds.where((s) => s == 'blast.wav'), hasLength(1));
  });
  test('standing still faces sustained attacks without chasing the boss', () {
    var hits = 0;
    final f = fight(
      hurt: (_, __) {
        hits++;
        return true;
      },
    );
    surface(f);
    f.player = const Offset(200, 250);
    step(f, 30);
    expect(
      f.releases.values.fold<int>(0, (a, b) => a + b),
      greaterThanOrEqualTo(10),
    );
    expect(hits, greaterThanOrEqualTo(3));
  });
  test('optional presentation checkpoint values are validated and older saves remain readable', () {
    final f = fight();
    surface(f);
    final raw = f.checkpoint();
    expect(LodestarCombat.validCheckpoint(raw), isTrue);
    expect(
      LodestarCombat.validCheckpoint({
        ...raw,
        'releasedAt': {'unknown': 1},
      }),
      isFalse,
    );
    expect(
      LodestarCombat.validCheckpoint({
        ...raw,
        'deathMouth': [double.nan, 0],
      }),
      isFalse,
    );
    expect(
      LodestarCombat.validCheckpoint({...raw, 'shardYaw': double.infinity}),
      isFalse,
    );
    final old = Map<String, dynamic>.of(raw)
      ..remove('releasedAt')
      ..remove('deathMouth')
      ..remove('deathSinking')
      ..remove('shardYaw');
    expect(LodestarCombat.validCheckpoint(old), isTrue);
    fight().restore(old, continueRun: true);
  });
}
