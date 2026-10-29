import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/systems/lodestar/lodestar_target.dart';

void main() {
  test(
    'six stable integrity records, permanent local break, feeder trims loading',
    () {
      final s = LodestarSections();
      expect(s.total, 240);
      expect(s.mortarSalvo, 3);
      final hits = s.primary(LodestarSection.feeder, 30, LodestarHitLedger());
      expect(hits.single.amount, 25);
      expect(hits.single.broke, isTrue);
      expect(s.mortarSalvo, 1);
      expect(s.generation(LodestarSection.feeder), 1);
      expect(s.generation(LodestarSection.mortars), 1);
      final unused = LodestarHitLedger();
      expect(s.primary(LodestarSection.feeder, 100, unused), isEmpty);
      // Ruins neither absorb the shot nor spend its owner ledger.
      expect(s.primary(LodestarSection.mortars, 4, unused).single.amount, 4);
      expect(s.mortarSalvo, 1);
      s.primary(LodestarSection.mortars, 36, LodestarHitLedger());
      expect(s.mortarSalvo, 0);
      expect(s.living(LodestarSection.accelerator), isTrue);
    },
  );
  test('one primary ownership across pierce, ricochet and chained sections; pellets independent', () {
    final s = LodestarSections(), shot = LodestarHitLedger();
    expect(s.primary(LodestarSection.accelerator, 4, shot).single.amount, 4);
    for (final section in LodestarSection.values) {
      expect(s.primary(section, 4, shot), isEmpty);
    }
    expect(s.total, 236);
    for (var pellet = 0; pellet < 3; pellet++) {
      s.primary(LodestarSection.accelerator, 1.7, LodestarHitLedger());
    }
    expect(s.total, closeTo(230.9, 1e-9));
    // The same release may still hit a genuinely separate encounter owner.
    final other = LodestarSections();
    expect(other.primary(LodestarSection.tail, 4, shot), hasLength(1));
  });
  test('one blast budget across all six and overkill redistribution, deterministic and deduplicated', () {
    final s = LodestarSections();
    final blast = LodestarHitLedger();
    final hits = s.blast(
      [...LodestarSection.values, LodestarSection.head],
      12,
      blast,
    );
    expect(hits, hasLength(6));
    expect(hits.fold<double>(0, (sum, h) => sum + h.amount), 10);
    expect(s.blast(LodestarSection.values, 12, blast), isEmpty);
    s.primary(LodestarSection.feeder, 22, LodestarHitLedger());
    final split = s.blast(
      [LodestarSection.feeder, LodestarSection.mortars],
      8,
      LodestarHitLedger(),
    );
    expect(split.first.section, LodestarSection.feeder);
    expect(split.first.amount, 1);
    expect(split.last.amount, 7);
    expect(s.mortarSalvo, 1);
  });
  test(
    'exposed head ends fight once without grinding surviving auxiliary HP',
    () {
      final s = LodestarSections();
      for (final part in [
        ...LodestarSection.values.where((s) => s.weapon),
        LodestarSection.head,
      ]) {
        s.primary(part, 1000, LodestarHitLedger());
      }
      expect(s.defeated, isTrue);
      expect(s.total, 0);
      expect(s.living(LodestarSection.feeder), isFalse);
      final generations = [
        for (final p in LodestarSection.values) s.generation(p),
      ];
      expect(
        s.blast(LodestarSection.values, 100, LodestarHitLedger()),
        isEmpty,
      );
      expect([
        for (final p in LodestarSection.values) s.generation(p),
      ], generations);
    },
  );
  test(
    'head armor consumes releases; feeder does not unlock core; two weapons do',
    () {
      final s = LodestarSections(), ledger = LodestarHitLedger();
      expect(s.primary(LodestarSection.head, 1000, ledger).single.amount, 0);
      expect(s.integrity(LodestarSection.head), 80);
      expect(s.primary(LodestarSection.tail, 3, ledger), isEmpty);
      s.primary(LodestarSection.feeder, 1000, LodestarHitLedger());
      s.primary(LodestarSection.accelerator, 1000, LodestarHitLedger());
      expect(s.coreExposed, isFalse);
      s.primary(LodestarSection.mortars, 1000, LodestarHitLedger());
      expect(s.coreExposed, isTrue);
      s.primary(LodestarSection.head, 79, LodestarHitLedger());
      expect(s.defeated, isFalse);
      s.primary(LodestarSection.head, 1, LodestarHitLedger());
      expect(s.defeated, isTrue);
      expect(s.total, 0);
      expect(s.living(LodestarSection.tail), isFalse);
      expect(
        s.integrity(LodestarSection.tail),
        35,
      ); // retained only for wreck art
    },
  );
  test('one blast cannot both unlock and kill armored core', () {
    final s = LodestarSections();
    s.blast(LodestarSection.values, 10000, LodestarHitLedger());
    expect(s.coreExposed, isTrue);
    expect(s.integrity(LodestarSection.head), 80);
    expect(s.defeated, isFalse);
  });
  test('invalid/empty queries never consume a release', () {
    final s = LodestarSections(), ledger = LodestarHitLedger();
    for (final amount in [double.nan, double.infinity, -1.0, 0.0]) {
      expect(s.primary(LodestarSection.head, amount, ledger), isEmpty);
      expect(s.blast(LodestarSection.values, amount, ledger), isEmpty);
    }
    expect(s.blast([], 3, ledger), isEmpty);
    expect(s.primary(LodestarSection.head, 3, ledger).single.amount, 0);
  });
  test('first swept living section and cumulative contact distance survive ruined gaps', () {
    final rig = LodestarRig(head: const Offset(260, 0)),
        sections = LodestarSections();
    final target = LodestarTarget(rig, sections);
    final first = target.firstContact(
      const Offset(-600, 0),
      const Offset(600, 0),
    )!;
    expect(first.section, LodestarSection.tail);
    expect(first.distance, closeTo(298, .01));
    sections.primary(LodestarSection.tail, 100, LodestarHitLedger());
    final next = target.firstContact(
      const Offset(-600, 0),
      const Offset(600, 0),
    )!;
    expect(next.section, LodestarSection.mines);
    expect(next.distance, closeTo(402, .01));
    expect(
      target.firstContact(const Offset(0, 90), const Offset(500, 90)),
      isNull,
    );
  });
  test('blast edge contacts respect per-section cover and exclude ruins', () {
    final rig = LodestarRig(head: const Offset(260, 0)), s = LodestarSections();
    final target = LodestarTarget(rig, s);
    final all = target
        .blastSections(Offset.zero, 500, visible: (_, _) => true)
        .toList();
    expect(all, LodestarSection.values);
    final exposed = target
        .blastSections(
          Offset.zero,
          500,
          visible: (_, surface) => surface.dx >= 0,
        )
        .toList();
    expect(exposed, [
      LodestarSection.head,
      LodestarSection.accelerator,
      LodestarSection.mortars,
    ]);
    final hits = s.blast(exposed, 8, LodestarHitLedger());
    expect(hits.fold<double>(0, (a, b) => a + b.amount), closeTo(16 / 3, 1e-9));
    final p = rig.poses[3].position;
    expect(
      target.blastSections(
        p + const Offset(0, 60),
        15,
        visible: (_, _) => true,
      ),
      contains(LodestarSection.feeder),
    );
    s.primary(LodestarSection.feeder, 100, LodestarHitLedger());
    expect(target.blastSections(p, 15, visible: (_, _) => true), isEmpty);
  });
}
