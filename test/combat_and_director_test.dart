import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/systems/encounter_director.dart';

void main() {
  test('health rejects invalid damage and emits exactly one lethal transition',
      () {
    final health = CombatHealth(6);
    expect(health.damage(double.nan), DamageResult.ignored);
    expect(health.damage(-2), DamageResult.ignored);
    expect(health.damage(1), DamageResult.hit);
    expect(health.current, 5);
    expect(health.damage(20), DamageResult.killed);
    expect(health.current, 0);
    expect(health.damage(20), DamageResult.ignored);
  });

  test('director coalesces missed bosses and enforces recovery', () {
    final director = EncounterDirector();
    director.advance(180);
    expect(director.bossDue, isTrue);
    director.beginBoss();
    director.advance(600);
    expect(director.bossDue, isFalse);
    director.defeatBoss();
    expect(director.bossesDefeated, 1);
    director.defeatBoss();
    expect(director.bossesDefeated, 1);
    director.advance(59);
    expect(director.bossDue, isFalse);
    director.advance(1);
    expect(director.bossDue, isTrue);
  });

  for (final size in [
    const Size(568, 270),
    const Size(750, 330),
    const Size(1024, 720)
  ]) {
    for (final mirrored in [false, true]) {
      test('controls stay separate and inside $size mirrored=$mirrored', () {
        final layout = ControlLayout(
            leftHanded: mirrored, size: 112, inset: 160, bottom: 140);
        final geometry = layout.geometry(size);
        for (final point in [
          geometry.movement,
          geometry.aim,
          geometry.dash,
          geometry.reload
        ]) {
          expect(point.dx, greaterThanOrEqualTo(28));
          expect(point.dx, lessThanOrEqualTo(size.width - 28));
          expect(point.dy, greaterThanOrEqualTo(28));
          expect(point.dy, lessThanOrEqualTo(size.height - 28));
        }
        expect((geometry.dash - geometry.aim).distance, greaterThan(84));
        expect((geometry.dash - geometry.reload).distance, greaterThan(56));
        expect(geometry.dash.dx > size.width / 2, !mirrored);
        expect(geometry.reload.dx > size.width / 2, !mirrored);
        expect((geometry.reload - geometry.aim).distance, greaterThan(84));
      });
    }
  }
}
