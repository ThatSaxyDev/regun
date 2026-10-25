import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_integration_test.dart' show Quiet, SentryTarget;

Future<RegunGame> arena(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
      child: const MaterialApp(
        home: BaseView(loadout: Loadout(training: true)),
      ),
    ),
  );
  final game =
      tester
              .widget<RiverpodAwareGameWidget>(
                find.byType(RiverpodAwareGameWidget),
              )
              .game!
          as RegunGame;
  await game.loaded;
  await tester.pump();
  await game.ready();
  game.update(2);
  for (final e in game.liveEnemies.toList()) {
    e.removeFromParent();
  }
  await game.ready();
  return game;
}

SupportUnit mount(
  RegunGame game,
  String kind,
  ui.Offset at, {
  bool fresh = false,
}) {
  game.supportCombat.clear();
  game.supplyDrops.drop = null;
  game.myPlayer.position.setValues(at.dx, at.dy);
  final unit = SupportUnit(
    SupportCard(SupportFamily.sentry, 1, mount: kind),
    1,
    at,
  );
  if (!fresh) {
    unit.phase = 'deploying';
    unit.landed = true;
    unit.elapsed = .54;
  }
  game.supportCombat.runtime.units.add(unit);
  game.gameNotifier.support.busy.add('sentry');
  return unit;
}

void main() {
  testWidgets(
    'fresh sentry shots reach bodies across Float32 coordinates, headings and frame rates',
    (tester) async {
      await tester.runAsync(() async {
        final game = await arena(tester);
        final rows = <Map<String, dynamic>>[];
        for (final kind in ['carbine', 'burstRifle']) {
          for (final hz in [30, 60, 120]) {
            for (final at in [
              const ui.Offset(300, 300),
              const ui.Offset(-700, -600),
            ]) {
              for (final angle in [0.0, .6]) {
                final unit = mount(game, kind, at, fresh: true);
                final pivot = at + const ui.Offset(0, -42);
                final target = SentryTarget(
                  Vector2(
                    pivot.dx + math.cos(angle) * 330,
                    pivot.dy + math.sin(angle) * 330,
                  ),
                );
                await game.world.add(target);
                await game.ready();
                double? activeAt, hitAt;
                for (var i = 0; i < hz * 8; i++) {
                  game.supportCombat.advance(1 / hz);
                  if (unit.phase == 'active') activeAt ??= (i + 1) / hz;
                  if (target.combatHealth.current < 100) hitAt ??= (i + 1) / hz;
                }
                final label = '$kind/$hz/$at/$angle';
                expect(hitAt, isNotNull, reason: label);
                expect(hitAt! - activeAt!, lessThan(.65), reason: label);
                rows.add({
                  'mount': kind,
                  'hz': hz,
                  'x': at.dx,
                  'y': at.dy,
                  'heading': angle,
                  'shots': unit.shotsFired,
                  'damage': 100 - target.combatHealth.current,
                  'firstHitAfterActivation': hitAt - activeAt,
                });
                target.removeFromParent();
                await game.ready();
              }
            }
          }
        }
        await Directory('build/diagnostics').create(recursive: true);
        await File('build/diagnostics/sentry-flight-fixed.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(rows));
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'both mounts track actual walking scorpions and mummies at normal cadence',
    (tester) async {
      await tester.runAsync(() async {
        final game = await arena(tester);
        for (final kind in ['carbine', 'burstRifle']) {
          for (final mummy in [false, true]) {
            for (final hz in [30, 60, 120]) {
              final unit = mount(game, kind, const ui.Offset(300, 300));
              final SpriteAnimationComponent enemy = mummy
                  ? Enemy2Component(position: Vector2(630, 258))
                  : EnemyComponent(position: Vector2(630, 258));
              (enemy as CombatEnemy).restoreHealth(100, maximum: 100);
              await game.world.add(enemy);
              await game.ready();
              game.myPlayer.position.setValues(1100, 258);
              final start = enemy.position.clone();
              double? firstHit;
              for (var i = 0; i < hz * 2; i++) {
                game.enemyTactics.rebuild([enemy]);
                game.crowdOccupancy.rebuild([enemy], game.crowdRadius);
                game.supportCombat.advance(1 / hz);
                enemy.update(1 / hz);
                if ((enemy as CombatEnemy).combatHealth.current < 100) {
                  firstHit ??= (i + 1) / hz;
                }
              }
              expect(enemy.position.distanceTo(start), greaterThan(70));
              expect(firstHit, isNotNull, reason: '$kind mummy=$mummy hz=$hz');
              expect(firstHit!, lessThan(.65));
              expect(unit.shotsFired, greaterThan(kind == 'carbine' ? 15 : 8));
              expect(
                game.supportCombat.runtime.metrics['sentry_round'],
                greaterThan(15),
              );
              enemy.removeFromParent();
              await game.ready();
            }
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'sentry rejects grazing cover, changes target, and retains wall and range stops',
    (tester) async {
      await tester.runAsync(() async {
        final game = await arena(tester);
        for (final kind in ['carbine', 'burstRifle']) {
          final unit = mount(game, kind, const ui.Offset(300, 300));
          final blocked = SentryTarget(Vector2(630, 258)),
              clear = SentryTarget(Vector2(630, 100));
          await game.world.addAll([blocked, clear]);
          await game.ready();
          game.supplyDrops.drop = SupplyDrop(const ui.Offset(460, 312))
            ..phase = SupplyPhase.active;
          // A point ray clears this pod by two units; the five-unit round cannot.
          expect(
            game.supportCombat.blocked(
              const ui.Offset(300, 258),
              blocked.position.toOffset(),
              unit,
            ),
            false,
          );
          expect(
            game.supportCombat.blocked(
              const ui.Offset(300, 258),
              blocked.position.toOffset(),
              unit,
              clearance: 5,
            ),
            true,
          );
          unit.target = '${blocked.combatId}';
          for (var i = 0; i < 180; i++) {
            game.supportCombat.advance(1 / 60);
          }
          expect(blocked.combatHealth.current, 100);
          expect(clear.combatHealth.current, lessThan(100));
          expect(unit.target, '${clear.combatId}');
          clear.removeFromParent();
          await game.ready();
          // Bypass targeting to exercise a real obstructed round's flight stop.
          game.supportCombat.runtime.rounds.clear();
          game.supportCombat.traces.clear();
          unit.shot = 10;
          final round = SupportRound(
            1,
            kind,
            const ui.Offset(356, 258),
            const ui.Offset(1, 0),
            10,
            950,
            650,
          );
          game.supportCombat.runtime.rounds.add(round);
          for (var i = 0; i < 10; i++) {
            game.supportCombat.advance(1 / 60);
          }
          expect(game.supportCombat.runtime.rounds, isEmpty);
          expect(round.position.dx, closeTo(409, .002));
          expect(blocked.combatHealth.current, 100);
          blocked.removeFromParent();
          await game.ready();
          game.supplyDrops.drop = null;
          final ranged = SupportRound(
            1,
            kind,
            const ui.Offset(400, -300),
            const ui.Offset(1, 0),
            10,
            950,
            650,
          );
          game.supportCombat.runtime.rounds.add(ranged);
          for (var i = 0; i < 60; i++) {
            game.supportCombat.advance(1 / 60);
          }
          expect(game.supportCombat.runtime.rounds, isEmpty);
          expect(ranged.travel, closeTo(650, .000001));
          expect(ranged.position.dx, closeTo(1050, .002));
        }
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
}
