import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
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
              loadout: Loadout(training: true),
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
    'Training button deploys complete Lodestar; damage, pause, recovery and defeat',
    (tester) async {
      final g = await mount(tester);
      g.pauseGame();
      await tester.pump();
      await tester.ensureVisible(find.text('BOSS PRACTICE'));
      await tester.tap(find.text('BOSS PRACTICE'));
      await tester.pump(const Duration(milliseconds: 300));
      final button = find.byKey(const Key('practice-boss-lodestar'));
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.runAsync(() async {
        final b = await ready(g);
        await advance(g, 4.5);
        expect(g.mechanicalTrial, MechanicalTrial.lodestar);
        expect(g.inputBlocked, isFalse);
        expect(b.fight.depths.every((d) => d == 0), isTrue);
        expect(g.bosses, isEmpty);
        expect(b.assets.arsenal, isNotNull);
        expect(
          b.assets.decodedBytes + RegunArt.shared.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
        );
        final old = b.fight.elapsed;
        g.pauseGame();
        await advance(g, 1);
        expect(b.fight.elapsed, old);
        g.resumeGame();
        final before = g.gameState.health;
        g.setTrainingDamage(true);
        g.gameNotifier.grantResumeGrace(milliseconds: 0);
        // Real contact, rather than directly calling damagePlayer.
        g.myPlayer.position.setValues(
          b.fight.rig.poses[1].position.dx,
          b.fight.rig.poses[1].position.dy,
        );
        await advance(g, .05);
        expect(g.gameState.health, lessThan(before));
        final preserved = b.combatHealth.current;
        g.gameNotifier.grantResumeGrace(milliseconds: 0);
        expect(
          g.damagePlayer(
            amount: g.gameState.health,
            cause: 'Lodestar training',
          ),
          isTrue,
        );
        expect(g.playerEntrance.active, isTrue);
        final frozen = b.fight.elapsed;
        await advance(g, .4);
        expect(b.fight.elapsed, frozen);
        await advance(g, 3);
        expect(g.playerEntrance.active, isFalse);
        expect(g.gameState.health, g.gameState.maxHealth);
        expect(b.combatHealth.current, preserved);
        final prior = b.combatHealth.current;
        g.combat.explode(
          Vector2(
            b.fight.rig.poses[2].position.dx,
            b.fight.rig.poses[2].position.dy,
          ),
          radius: 600,
          damage: 8,
          grenade: true,
          allowFragments: false,
        );
        expect(prior - b.combatHealth.current, closeTo(8 * 5 / 6, 1e-6));
        final dir = Directory('docs/validation/lodestar-pressure-2026-10-29')
          ..createSync(recursive: true);
        File('${dir.path}/art-budget.json').writeAsStringSync(
          jsonEncode({
            'owned': b.assets.decodedBytes,
            'shared': RegunArt.shared.decodedBytes,
            'combined': b.assets.decodedBytes + RegunArt.shared.decodedBytes,
            'limit': 32 * 1024 * 1024,
          }),
        );
        final rec = ui.PictureRecorder(), canvas = Canvas(rec);
        g.render(canvas);
        final pic = rec.endRecording(), im = await pic.toImage(844, 390);
        File('${dir.path}/native-fight.png').writeAsBytesSync(
          (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
        );
        im.dispose();
        pic.dispose();
        for (final s in [
          ...LodestarSection.values.where((s) => s.weapon),
          LodestarSection.head,
        ]) {
          final p = b.fight.rig.poses[s.index].position;
          b.receiveLocalDamage(100, point: p);
        }
        expect(b.fight.defeated, isTrue);
        expect(b.fight.shots, isEmpty);
        expect(b.fight.mines, isEmpty);
        await advance(g, 4.5);
        expect(b.fight.finished, isTrue);
        expect(g.gameState.kills, 0);
        g.practiceLodestar();
        final second = await ready(g);
        expect(second, isNot(same(b)));
        expect(b.assets.disposed, isTrue);
        g.practiceAriet();
        await g.ready();
        expect(second.retired, isTrue);
        expect(second.assets.decodedBytes, 0);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
