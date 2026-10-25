import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/support_art.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Quiet extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String name) async {
    sounds.add(name);
  }

  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

class SentryTarget extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  SentryTarget(Vector2 at) : super(position: at, size: Vector2.all(40));
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initializeHealth(100);
  }

  @override
  void onCombatDeath() {}
}

void main() {
  testWidgets(
    'real native sentry is solid, fires physical support rounds, pauses/restores and cleans on Rush',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = Quiet();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
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
        // Active combat must not freeze when lazy presentation art is absent.
        expect(SupportArt.ready, false);
        final uncached =
            SupportUnit(
                const SupportCard(SupportFamily.sentry, 1),
                1,
                game.myPlayer.position.toOffset() + const Offset(200, 0),
              )
              ..phase = 'active'
              ..ammo = 24;
        game.supportCombat.runtime.units.add(uncached);
        game.gameNotifier.support.busy.add('sentry');
        game.update(.05);
        expect(uncached.life, greaterThan(0));
        game.supportCombat.clear();
        for (final name in SupportArt.atlases) {
          await RegunArt.shared.acquire(name);
        }
        game.pauseGame();
        game.practiceSupport(SupportFamily.sentry);
        final card = game.gameNotifier.support.offer!;
        game.gameNotifier.chooseSupport(
          card.id,
          offerId: game.gameState.offerId,
        );
        for (var i = 0; i < 132; i++) {
          game.update(.05);
          await game.ready();
        }
        final runtime = game.supportCombat.runtime, u = runtime.units.single;
        expect(u.phase, 'active');
        expect(game.geometry.solids.contains(u.footprint), true);
        for (final enemy in game.liveEnemies.toList()) {
          enemy.removeFromParent();
        }
        await game.ready();
        final victim = Enemy2Component(
          position: Vector2(u.position.dx + 300, u.position.dy - 42),
        );
        victim.restoreHealth(100, maximum: 100);
        await game.world.add(victim);
        await game.ready();
        final before = victim.combatHealth.current;
        for (var i = 0; i < 30; i++) {
          game.update(.05);
          await game.ready();
        }
        expect(runtime.metrics['sentry_round'] ?? 0, greaterThan(0));
        expect(victim.combatHealth.current, lessThan(before));
        expect(audio.sounds, contains('sentry_fire.wav'));
        // Close contacts used to remove every round before any render saw it.
        // Exercise both mounts around the full receiver, including lower corners.
        for (final enemy in game.liveEnemies.toList()) {
          enemy.removeFromParent();
        }
        await game.ready();
        for (final mount in ['carbine', 'burstRifle']) {
          final original = runtime.units.single;
          final unit =
              SupportUnit(
                  SupportCard(SupportFamily.sentry, 1, mount: mount),
                  original.serial,
                  original.position,
                )
                ..phase = 'active'
                ..landed = true
                ..ammo = 24;
          runtime.units[0] = unit;
          for (var angle = 0; angle < 32; angle++) {
            final heading = angle * math.pi / 8,
                direction = Vector2(math.cos(heading), math.sin(heading));
            final dummy = SentryTarget(
              Vector2(unit.position.dx, unit.position.dy - 42) +
                  direction * (angle < 16 ? 95 : 32),
            );
            await game.world.add(dummy);
            await game.ready();
            game.geometry.constrain(dummy.position, 30);
            final actual =
                dummy.position -
                Vector2(unit.position.dx, unit.position.dy - 42);
            unit
              ..heading = math.atan2(actual.y, actual.x)
              ..target = null
              ..query = 0
              ..blocked = 0
              ..shot = 0
              ..burstWait = 0
              ..burst = 0
              ..ammo = 24
              ..reload = 0;
            runtime.rounds.clear();
            game.supportCombat.traces.clear();
            game.supportCombat.advance(.1);
            expect(
              dummy.combatHealth.current,
              lessThan(100),
              reason: '$mount heading $angle',
            );
            expect(runtime.rounds, isEmpty);
            expect(game.supportCombat.traces, isNotEmpty);
            dummy.removeFromParent();
            await game.ready();
          }
        }
        // Exercise the real scorpion/mummy updates, not just ideal steering.
        // Keep the sentry planted throughout: no shooting or expiry can free them.
        for (final mummy in [false, true]) {
          for (var side = 0; side < 16; side++) {
            final angle = side * math.pi / 8;
            final axis = Vector2(math.cos(angle), math.sin(angle));
            final center = Vector2(
              runtime.units.single.position.dx,
              runtime.units.single.position.dy - 22,
            );
            final at = center + axis * 45;
            final PositionComponent enemy = mummy
                ? Enemy2Component(position: at)
                : EnemyComponent(position: at);
            await game.world.add(enemy);
            await game.ready();
            final target = center - axis * 240;
            game.myPlayer.position.setFrom(target);
            for (var frame = 0; frame < 720; frame++) {
              game.enemyTactics.rebuild([enemy]);
              game.crowdOccupancy.rebuild([enemy], game.crowdRadius);
              enemy.update(1 / 60);
            }
            expect(
              enemy.position.distanceTo(target),
              lessThan(100),
              reason:
                  '${mummy ? 'mummy' : 'scorpion'} contact heading $side at ${enemy.position}',
            );
            enemy.removeFromParent();
            await game.ready();
          }
        }
        for (final mummy in [false, true]) {
          final origin = runtime.units.single.position;
          final blockers = <SentryTarget>[];
          for (final x in [-150.0, -40.0, 70.0]) {
            final blocker = SentryTarget(
              Vector2(origin.dx + x, origin.dy - 120),
            )..size = Vector2.all(116);
            blockers.add(blocker);
            await game.world.add(blocker);
          }
          final PositionComponent enemy = mummy
              ? Enemy2Component(
                  position: Vector2(origin.dx - 200, origin.dy - 22),
                )
              : EnemyComponent(
                  position: Vector2(origin.dx - 200, origin.dy - 22),
                );
          await game.world.add(enemy);
          await game.ready();
          final target = Vector2(origin.dx + 320, origin.dy - 22);
          game.myPlayer.position.setFrom(target);
          for (var frame = 0; frame < 1200; frame++) {
            game.enemyTactics.rebuild([...blockers, enemy]);
            game.crowdOccupancy.rebuild([...blockers, enemy], game.crowdRadius);
            enemy.update(1 / 60);
          }
          expect(
            enemy.position.distanceTo(target),
            lessThan(100),
            reason:
                '${mummy ? 'mummy' : 'scorpion'} blocked corner at ${enemy.position}',
          );
          enemy.removeFromParent();
          for (final blocker in blockers) {
            blocker.removeFromParent();
          }
          await game.ready();
        }
        final savedUnit = runtime.units.single;

        game.pauseGame();
        final life = savedUnit.life;
        game.update(8);
        expect(savedUnit.life, life);
        final snapshot = game.checkpoint();
        game.restartGame();
        await game.ready();
        expect(game.restoreRun(snapshot), true);
        expect(game.gameState.gameplayState, GameplayState.paused);
        expect(game.supportCombat.runtime.units.single.life, life);
        expect(game.geometry.solids.length, 1);
        game.startBossRush();
        expect(game.supportCombat.runtime.units, isEmpty);
        expect(game.supportCombat.runtime.rounds, isEmpty);
        for (final name in SupportArt.atlases) {
          RegunArt.shared.release(name);
        }
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'support rounds obey Shield Warden armour without primary perks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
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
        final shield = ArenaEnemy(EnemyKind.shield, position: Vector2(150, 0))
          ..restoreHealth(100, maximum: 100);
        await game.world.add(shield);
        await game.ready();

        // Compare opposed directions rather than relying on a hidden initial facing.
        game.supportCombat.hit(
          shield,
          10,
          'sentry_round',
          ballistic: true,
          direction: Vector2(1, 0),
        );
        final first = 100 - shield.combatHealth.current;
        game.supportCombat.hit(
          shield,
          10,
          'sentry_round',
          ballistic: true,
          direction: Vector2(-1, 0),
        );
        final second = 100 - first - shield.combatHealth.current;
        expect([first, second]..sort(), [3, 10]);
        expect(shield.marked, false);
        expect(shield.burning, false);
        expect(shield.lastHitWasSecondary, true);
        expect(shield.incomingSupportBallistic, false);
        for (final name in SupportArt.atlases) {
          await RegunArt.shared.acquire(name);
        }
        game.pauseGame();
        game.practiceSupport(SupportFamily.aura);
        final aura = game.gameNotifier.support.offer!;
        game.gameNotifier.chooseSupport(
          aura.id,
          offerId: game.gameState.offerId,
        );
        shield.position.setFrom(game.myPlayer.position + Vector2(60, 0));
        for (var i = 0; i < 30; i++) {
          game.update(.05);
          await game.ready();
        }
        expect(game.supportCombat.runtime.metrics['aura'] ?? 0, greaterThan(0));
        expect(shield.lastHitWasSecondary, true);
        for (final name in SupportArt.atlases) {
          RegunArt.shared.release(name);
        }
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'render authored sentry phases and all head quadrants at gameplay size',
    (tester) async {
      await tester.runAsync(() async {
        final font = FontLoader('PressStart2P')
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
        await font.load();
        await RegunArt.shared.load();
        for (final n in SupportArt.atlases) {
          await RegunArt.shared.acquire(n);
        }
        final recorder = ui.PictureRecorder();
        // Render into one inspectable storyboard, with a floor crop behind each unit.
        final out = Canvas(recorder);
        const config = SupportConfig({});
        final phases = [
          'following',
          'warning',
          'falling',
          'deploying',
          'active',
          'active',
          'active',
          'breaking',
        ];
        for (var i = 0; i < 8; i++) {
          out.save();
          out.translate((i % 4) * 260.0, (i ~/ 4) * 260.0);
          out.clipRect(const Rect.fromLTWH(0, 0, 260, 260));
          out.drawRect(
            const Rect.fromLTWH(0, 0, 260, 260),
            Paint()..color = const Color(0xff292C27),
          );
          final u =
              SupportUnit(
                  SupportCard(
                    SupportFamily.sentry,
                    1,
                    mount: i % 2 == 0 ? 'carbine' : 'burstRifle',
                  ),
                  1,
                  const Offset(130, 190),
                )
                ..phase = phases[i]
                ..elapsed = (i == 2
                    ? .5
                    : i == 3
                    ? .3
                    : i == 7
                    ? .6
                    : 1)
                ..heading = i * 1.1
                ..recoil = i == 4 ? .08 : 0;
          SupportArt.floor(
            out,
            u,
            config,
            ambient: BossArt.ambient(ArenaType.breach),
          );
          SupportArt.body(
            out,
            u,
            config,
            ambient: BossArt.ambient(ArenaType.breach),
          );
          out.restore();
        }
        final aura =
            SupportUnit(
                const SupportCard(SupportFamily.aura, 2),
                2,
                const Offset(520, 520),
              )
              ..phase = 'active'
              ..life = 2;
        SupportArt.floor(
          out,
          aura,
          config,
          ambient: BossArt.ambient(ArenaType.breach),
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(1040, 740),
            bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/support-storyboard.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        for (final n in SupportArt.atlases) {
          RegunArt.shared.release(n);
        }
      });
    },
  );
}
