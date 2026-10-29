// Diagnostic: flutter test tool/crowd_native_probe_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('record real mummy pack around one scorpion', (tester) async {
    // Opt-in Flutter test kept under tool/ to avoid running on every verify.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(
            home: BaseView(
              loadout: Loadout(training: true),
              reviewControlledSpawns: true,
            ),
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
      game.pauseEngine();
      game.update(2);
      await game.ready();
      for (final e in game.liveEnemies.toList()) {
        e.removeFromParent();
      }
      await game.ready();
      game.myPlayer.position.setValues(-300, 0);
      final scorpion = EnemyComponent(position: Vector2.zero());
      await game.world.add(scorpion);
      await game.ready();
      final random = math.Random(19);
      final mummies = <Enemy2Component>[];
      for (var i = 0; i < 36; i++) {
        final e = Enemy2Component(
          position: Vector2(
            100 + random.nextDouble() * 600,
            -350 + random.nextDouble() * 700,
          ),
        );
        mummies.add(e);
        await game.world.add(e);
        await game.ready();
      }
      final samples = <Map<String, dynamic>>[];
      for (var frame = 0; frame <= 1800; frame++) {
        // Move the real player along a bounded straight retreat, then hold.
        // No joystick intent: this isolates packing from common predictive lead.
        game.myPlayer.position.setValues(
          -300 - math.min(frame / 60 * 38, 760),
          0,
        );
        if (frame % 300 == 0) {
          final nearest = <double>[];
          for (final a in mummies) {
            nearest.add(
              mummies
                  .where((b) => b != a)
                  .map((b) => a.position.distanceTo(b.position))
                  .reduce(math.min),
            );
          }
          nearest.sort();
          samples.add({
            'seconds': frame / 60,
            'target': [game.myPlayer.position.x, game.myPlayer.position.y],
            'scorpion': [scorpion.position.x, scorpion.position.y],
            'positions': [
              for (final a in mummies) [a.position.x, a.position.y],
            ],
            'nearestMedian': nearest[nearest.length ~/ 2],
            'blockedMummies': mummies.where((a) => a.walk.blocked).length,
            'meleeMummies': mummies.where((a) => a.isAttacking).length,
          });
        }
        game.update(1 / 60);
        if (frame % 60 == 0) await game.ready();
      }
      await Directory('build/diagnostics').create(recursive: true);
      await File('build/diagnostics/crowd-native-mixed-2026-10-29.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(samples));
      stdout.writeln(
        'Mixed native pack: ${samples.map((s) => '${s['seconds']}s nearest=${(s['nearestMedian'] as double).toStringAsFixed(2)} blocked=${s['blockedMummies']} melee=${s['meleeMummies']}').join('; ')}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}
