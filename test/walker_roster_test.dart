import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

WalkerCombat fight() => WalkerCombat(
  rig: WalkerRig(
    barrelLength: 158,
    maxSpeed: 260,
    acceleration: 600,
    turnSpeed: 1.5,
    agileGait: true,
    bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
    footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
  ),
  clear: (_, _, _) => true,
  hurt: (_, _) {},
  signal: (_) {},
);
void main() {
  test('active roster replaces Mirror Saint with Walker and migrates retired identity', () {
    expect(BossKind.active, contains(BossKind.walker));
    expect(BossKind.active, isNot(contains(BossKind.saint)));
    expect(BossKind.active.length, 8);
    expect(BossKind.read('saint'), BossKind.walker);
  });
  test('native simulation consumes server-owned wire snapshots and agrees on mechanics', () {
    final fixtures = jsonDecode(
      File('test/fixtures/walker-hosted-v1.json').readAsStringSync(),
    ) as List;
    final native = fight()..player = const Offset(600, 0);
    var tick = 0;
    for (final raw in fixtures) {
      final goal = raw['tick'] as int;
      while (tick < goal) {
        native.advance(1 / 120);
        tick++;
      }
      final state = Map<String, dynamic>.from(raw['state'] as Map);
      expect(
        WalkerCombat.validState(state),
        isTrue,
        reason: 'server tick $goal',
      );
      final hosted = fight()..restore(state);
      expect(native.phase, hosted.phase, reason: 'phase at $goal');
      expect(native.shots, hosted.shots, reason: 'shots at $goal');
      expect(
        (native.rig.position - hosted.rig.position).distance,
        lessThan(.001),
        reason: 'root at $goal',
      );
      expect(native.clock, closeTo(hosted.clock, .00001));
    }
  });
  test('checkpoint preserves in-flight ordnance, recoil, attack schedule and random choices', () {
    final original = fight()..player = const Offset(600, 0);
    original.advance(12.345);
    final saved = original.toJson();
    expect(WalkerCombat.validState(saved), isTrue);
    final restored = fight()..restore(saved);
    for (var i = 0; i < 120 * 25; i++) {
      original.advance(1 / 120);
      restored.advance(1 / 120);
    }
    expect(restored.phase, original.phase);
    expect(restored.shots, original.shots);
    expect(restored.toJson(), original.toJson());
    original.beginDestruction();
    original.advance(1.2);
    final doomed = fight()..restore(original.toJson());
    doomed.advance(4);
    expect(doomed.detonations, 1);
    expect(doomed.finished, isTrue);
  });
  test(
    'invalid Walker snapshot fails validation instead of discarding the run',
    () {
      final f = fight()..player = const Offset(600, 0);
      f.advance(8);
      final raw = f.toJson();
      raw['phase'] = 'unknown';
      expect(WalkerCombat.validState(raw), isFalse);
    },
  );
}
