import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playMusic(String path) async {}
  @override
  void pauseMusic(bool paused) {}
  @override
  void configure({required double music, required double sfx}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  WidgetTester? activeTester;
  Future<RegunGame> mount(WidgetTester tester) async {
    activeTester = tester;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(
            home: BaseView(
              loadout: Loadout(training: true, arena: ArenaType.foundry),
              reviewControlledSpawns: true,
            ),
          ),
        ),
      );
      game =
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
    });
    return game;
  }

  Future<LodestarBoss> ready(RegunGame g) async {
    for (var i = 0; i < 100 && g.lodestarCandidate?.prepared != true; i++) {
      await activeTester!.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      g.update(1 / 120);
    }
    await g.ready().timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        throw StateError(
          'ready trial=${g.mechanicalTrial} prepared=${g.lodestarCandidate?.prepared} mounted=${g.lodestarCandidate?.isMounted} loaded=${g.lodestarCandidate?.isLoaded} sheet=${g.lodestarCandidate?.assets.sheet != null} arsenal=${g.lodestarCandidate?.assets.arsenal != null} retired=${g.lodestarCandidate?.retired} entrance=${g.playerEntrance.active}',
        );
      },
    );
    expect(g.lodestarCandidate?.prepared, isTrue);
    g.pauseEngine();
    return g.lodestarCandidate!;
  }

  Future<void> advance(RegunGame g, double seconds, {bool held = false}) async {
    for (var t = 0.0; t < seconds - 1e-8; t += .025) {
      g.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
      g.update((seconds - t).clamp(0, .025));
      await g.ready();
    }
  }

  testWidgets(
    'real Foundry cover supports sustained pursuit against continuous movement',
    (tester) async {
      final g = await mount(tester);
      g.practiceLodestar();
      await tester.pump();
      for (var i = 0; i < 200 && g.lodestarCandidate?.prepared != true; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.runAsync(() async {
        final b = await ready(g);
        await advance(g, 4.5);
        var eligible = 0, moving = 0;
        final phases = <LodestarPhase>{};
        for (var n = 0; n < 1200; n++) {
          final t = n * .025;
          g.movementJoystick.delta.setValues(
            70 * math.cos(t * .25),
            70 * math.sin(t * .25),
          );
          g.update(.025);

          await g.ready();
          phases.add(b.fight.phase);
          if ([
            LodestarPhase.travel,
            LodestarPhase.recovery,
          ].contains(b.fight.phase)) {
            eligible++;
            if (b.fight.rig.speed > 40) moving++;
          }
          expect(LodestarRig.connected(b.fight.rig.poses), isTrue);
        }
        final dir = Directory('docs/validation/lodestar-training-2026-10-29')
          ..createSync(recursive: true);
        File('${dir.path}/foundry-pressure.json').writeAsStringSync(
          jsonEncode({
            'activeSeconds': 30,
            'eligibleFrames': eligible,
            'movingFrames': moving,
            'movingFraction': moving / eligible,
            'releases': {
              for (final entry in b.fight.releases.entries)
                entry.key.name: entry.value,
            },
            'phases': phases.map((p) => p.name).toList(),
          }),
        );
        expect(moving / eligible, greaterThan(.85));
        expect(
          b.fight.releases.values.fold<int>(0, (a, b) => a + b),
          greaterThan(5),
        );
        expect(phases, contains(LodestarPhase.firing));
        expect(g.runtimeCounts['enemies'], 1);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
