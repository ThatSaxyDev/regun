import 'dart:math' as math;
import 'dart:convert';

import 'package:regun/components/enemies/enemy_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/game.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/mummy_walk.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String sound) async {}
  @override
  Future<void> playMusic(String sound) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool value) {}
}

void main() {
  testWidgets(
    'stationary Training crowd has living blocked poses without mirror jitter',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
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
        game.myPlayer.position.setZero();
        final actors = <SpriteAnimationComponent>[];
        for (var i = 0; i < 36; i++) {
          final a = (i % 12) * math.pi / 6, radius = 180.0 + (i ~/ 12) * 120;
          final at = Vector2(math.cos(a) * radius, math.sin(a) * radius);
          final SpriteAnimationComponent e = i % 3 == 0
              ? EnemyComponent(position: at)
              : Enemy2Component(position: at);
          actors.add(e);
          await game.world.add(e);
          await game.ready();
        }
        final rows = {
          for (var i = 0; i < actors.length; i++)
            i: <String, dynamic>{
              'kind': actors[i] is Enemy2Component ? 'mummy' : 'scorpion',
              'frames': <int>{},
              'flips': 0,
              'travel': 0.0,
              'attackFrames': 0,
              'walkingFrames': 0,
              'maxStep': 0.0,
            },
        };
        for (var frame = 0; frame < 2400; frame++) {
          game.enemyTactics.rebuild(actors);
          game.crowdOccupancy.rebuild(actors, game.crowdRadius);
          for (var i = 0; i < actors.length; i++) {
            final e = actors[i],
                before = e.position.clone(),
                flipped = e.isFlippedHorizontally;
            e.update(1 / 60);
            if (frame >= 1800) {
              final r = rows[i]!;
              final move = e.position.distanceTo(before);
              r['travel'] += move;
              r['maxStep'] = math.max(r['maxStep'] as double, move);
              (r['frames'] as Set<int>).add(e.animationTicker!.currentIndex);
              if (flipped != e.isFlippedHorizontally) r['flips']++;
              if (e is Enemy2Component) {
                r[e.isAttacking ? 'attackFrames' : 'walkingFrames']++;
              }
            }
          }
        }
        for (var i = 0; i < actors.length; i++) {
          final e = actors[i], r = rows[i]!;
          r['frames'] = (r['frames'] as Set<int>).toList();
          r['blocked'] = e is Enemy2Component && e.walk.blocked;
          r['distance'] = e.position.length;
          r['x'] = e.position.x;
          r['y'] = e.position.y;
        }
        final mummies = actors.whereType<Enemy2Component>().toList();
        final still = mummies.where((e) => e.walk.blocked).toList();
        expect(still.length, greaterThanOrEqualTo(10));
        for (final e in still) {
          expect(e.animation, same(e.blockedAnimation));
          expect(e.playing, false);
          expect(e.isAttacking, false);
        }
        final maxFlips = rows.values
            .where((r) => r['kind'] == 'mummy')
            .map((r) => r['flips'] as int)
            .reduce(math.max);
        expect(maxFlips, lessThanOrEqualTo(2));
        expect(game.gameState.health, 6);
        final stance = still.first.walk.stanceScale(reducedMotion: false);
        still.first.update(.1);
        expect(
          still.first.walk.stanceScale(reducedMotion: false),
          isNot(stance),
        );
        expect(still.first.walk.stanceScale(reducedMotion: true), 1);
        // A fully still attacker must still cycle; no-damage Training should not suppress it.
        for (final e in actors) {
          e.removeFromParent();
        }
        await game.ready();
        final attacker = Enemy2Component(position: Vector2(20, 0));
        await game.world.add(attacker);
        await game.ready();
        attacker.position.setValues(20, 0);
        final attackSet = <int>{};
        var attackFlips = 0;
        for (var i = 0; i < 180; i++) {
          final f = attacker.isFlippedHorizontally;
          attacker.update(1 / 60);
          attackSet.add(attacker.animationTicker!.currentIndex);
          if (f != attacker.isFlippedHorizontally) attackFlips++;
        }
        final attack = {
          'frames': attackSet.toList(),
          'isAttacking': attacker.isAttacking,
          'time': attacker.timeSinceLastAttack,
          'health': game.gameState.health,
          'trainingDamage': game.trainingDamage,
          'flips': attackFlips,
        };
        final walk = MummyWalk();
        walk.follow(ui.Offset.zero, walking: true);
        var jitterFlips = 0;
        for (var i = 0; i < 120; i++) {
          final f = walk.left;
          walk.follow(ui.Offset(i.isEven ? .02 : 0, 0), walking: true);
          if (f != walk.left) jitterFlips++;
        }
        expect(jitterFlips, 0);
        expect(attackSet, {0, 1});
        expect(attacker.isAttacking, true);
        await Directory('build/diagnostics').create(recursive: true);
        await File('build/diagnostics/mummy-fixed-crowd-2026-10-25.json')
            .writeAsString(
              jsonEncode({
                'crowdLast10Seconds': rows.values.toList(),
                'stationaryAttacker': attack,
                'tinyWalkJitterFlips': jitterFlips,
              }),
            );
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
}
