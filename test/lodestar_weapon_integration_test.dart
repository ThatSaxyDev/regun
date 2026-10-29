import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/components/weapons/bullet_component.dart';
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
    'all24 actual weapon releases damage local sections once; restart cancels pending assets',
    (tester) async {
      final g = await mount(tester);
      g.practiceLodestar();
      await tester.pump();
      for (var i = 0; i < 200 && g.lodestarCandidate?.prepared != true; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() async {
        final b = await ready(g);
        await advance(g, 4.5);
        g.setTrainingDamage(false);
        for (final weapon in WeaponType.values) {
          g.pauseGame();
          expect(await g.changeTrainingWeapon(weapon), isTrue);
          g.resumeGame();
          g.pauseEngine();
          final original = b.fight;
          b.fight =
              LodestarCombat(
                  rig: LodestarRig(head: const Offset(520, 0)),
                  bounds: original.bounds,
                  clear: original.clear,
                  poseLegal: original.poseLegal,
                  hurt: original.hurt,
                  signal: original.signal,
                )
                ..phase = LodestarPhase.travel
                ..paused = true;
          b.fight.depths.fillRange(0, 6, 0);
          b.combatHealth.current = 240;
          b.burnRemaining = b.cinderRemaining = 0;
          b.lastSection = null;
          b.position.setValues(260, 0);
          g.myPlayer.position.setValues(-300, 0);
          await advance(g, weapon.firesOnRelease ? .4 : 1.1, held: true);
          if (weapon.firesOnRelease) g.arsenal!.releaseAim(Vector2(.5, 0));
          g.weaponJoystick.delta.setZero();
          await advance(g, 2);
          expect(b.combatHealth.current, lessThan(240), reason: weapon.name);
          expect(
            b.assets.decodedBytes + RegunArt.shared.decodedBytes,
            lessThanOrEqualTo(32 * 1024 * 1024),
            reason: weapon.name,
          );
          g.arsenal!.clearField();
          for (final p
              in g.world.children.whereType<BulletComponent>().toList()) {
            p.removeFromParent();
          }
          await g.ready();
        }
        g.practiceLodestar();
        final pending = g.lodestarCandidate!;
        g.restartGame();
        expect(pending.retired, isTrue);
        final next = await ready(g);
        expect(next, isNot(same(pending)));
        expect(pending.assets.disposed, isTrue);
        g.practiceWalker();
        await g.ready();
        expect(next.retired, isTrue);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
