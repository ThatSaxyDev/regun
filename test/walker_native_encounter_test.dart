import 'dart:io';
import 'dart:math' as math;

import 'package:regun/components/weapons/bullet_component.dart';

import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/walker_boss.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/walker_combat.dart';
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
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'normal Training boss selector runs Walker from sky drop through damaging destruction and replacement',
    (tester) async {
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
      game.pauseGame();
      await tester.pump();
      await tester.ensureVisible(find.text('BOSS PRACTICE'));
      await tester.pump();
      await tester.tap(find.text('BOSS PRACTICE'));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('practice-boss-walker'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      game.random.state = 427;
      await tester.tap(button);
      await tester.pump();
      for (var i = 0; i < 200 && game.walkerCandidate?.prepared != true; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      late WalkerBoss boss;
      await tester.runAsync(() async {
        await game.ready();
        game.pauseEngine();
        boss = game.walkerCandidate!;
        expect(boss.prepared, isTrue);
        expect(game.bossReveal.active, isFalse);
        expect(game.bossRush, isFalse);
        expect(game.walkerTrial, isTrue);
        expect(
          game.trainingDamage,
          isFalse,
          reason: 'Normal Training preserves its visit setting',
        );
        expect(game.liveEnemies.whereType<WalkerBoss>(), hasLength(1));
        expect(
          boss.assets.decodedBytes + RegunArt.shared.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
        );
      });
      final capture = Platform.environment['REGUN_WALKER_FIGHT_CAPTURE'] == '1';
      Process? encoder;
      Future<String>? errors;
      await tester.runAsync(() async {
        if (capture) {
          Directory('build/walker-fight').createSync(recursive: true);
          encoder = await Process.start('ffmpeg', [
            '-y',
            '-loglevel',
            'error',
            '-f',
            'image2pipe',
            '-framerate',
            '15',
            '-i',
            '-',
            '-an',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-movflags',
            '+faststart',
            'build/walker-fight/native.mp4',
          ]);
          errors = encoder!.stderr.transform(systemEncoding.decoder).join();
        }
        Future<void> frame() async {
          if (encoder == null) return;
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec));
          final pic = rec.endRecording(), im = await pic.toImage(844, 390);
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          encoder!.stdin.add(bytes!.buffer.asUint8List());
          await encoder!.stdin.flush();
          im.dispose();
          pic.dispose();
        }

        final seen = <WalkerPhase>{};
        for (var i = 0; i < 30 * 50; i++) {
          game.update(1 / 30);
          if (i % 6 == 0) await game.ready();
          seen.add(boss.fight.phase);
          if (i.isEven) await frame();
        }
        for (final phase in [
          WalkerPhase.descending,
          WalkerPhase.landing,
          WalkerPhase.burstFire,
          WalkerPhase.rotaryFire,
          WalkerPhase.cannonFire,
          WalkerPhase.rocketFire,
          WalkerPhase.charge,
        ]) {
          expect(seen, contains(phase));
        }
        expect(boss.fight.shots, greaterThan(5));
        // Real primary ammunition must damage the actual chassis.
        game.myPlayer.position.setFrom(boss.position - Vector2(280, 0));
        final hp = boss.combatHealth.current;
        for (var i = 0; i < 120; i++) {
          final aim = boss.position - game.myPlayer.position;
          game.weaponJoystick.delta.setFrom(aim.normalized() * 80);
          game.update(1 / 60);
          if (i % 6 == 0) await game.ready();
        }
        expect(boss.combatHealth.current, lessThan(hp));
        game.resetInput();
        // Real primary projectiles intercept owned missiles without enemy rewards.
        boss.fight.phase = WalkerPhase.recovery;
        boss.fight.clock = 0;
        boss.fight.rounds.clear();
        final rocket = WalkerRound(
          WalkerRoundKind.rocket,
          game.myPlayer.position.toOffset() + const Offset(170, 0),
          math.pi,
          aim: game.myPlayer.position.toOffset(),
        );
        boss.fight.rounds.add(rocket);
        final killsBeforeRocket = game.gameState.kills;
        game.myPlayer.aimDirection.setValues(1, 0);
        final bullet = BulletComponent(
          position: game.myPlayer.position + Vector2(50, 0),
          direction: Vector2(1, 0),
          speed: 1500,
          maxTravelDistance: 300,
        );
        game.world.add(bullet);
        await game.ready();
        for (var i = 0; i < 20 && !rocket.removed; i++) {
          game.update(1 / 120);
          await game.ready();
        }
        expect(rocket.removed, isTrue);
        expect(boss.fight.rounds.contains(rocket), isFalse);
        expect(boss.fight.blasts, isNotEmpty);
        expect(game.gameState.kills, killsBeforeRocket);
        // Actual charge contact deals two HP with Training damage enabled.
        game.setTrainingDamage(true);
        game.gameNotifier.advanceTime(3);
        boss.fight.rounds.clear();
        boss.fight.blasts.clear();
        boss.rig.carryTo(Offset.zero);
        boss.position.setZero();
        game.myPlayer.position.setValues(260, 0);
        boss.rig.yaw = 0;
        boss.fight.phase = WalkerPhase.chargeLock;
        boss.fight.clock = 1.44;
        boss.fight.chargeDistance = 0;
        boss.fight.chargeDirection = const Offset(1, 0);
        final beforeRam = game.gameState.health;
        for (var i = 0; i < 60; i++) {
          game.update(1 / 120);
        }
        expect(game.gameState.health, beforeRam - 2);
        game.gameNotifier.advanceTime(3);
        // A near miss of the hull still takes damage from the actual landing area.
        game.gameNotifier.resetHealth();
        boss.fight.rounds.clear();
        boss.fight.blasts.clear();
        boss.rig.carryTo(Offset.zero);
        boss.position.setZero();
        boss.rig.yaw = boss.rig.desiredYaw = 0;
        boss.fight.phase = WalkerPhase.chargeLock;
        boss.fight.clock = 1.44;
        boss.fight.locked = const Offset(540, 0);
        boss.fight.chargeDirection = const Offset(1, 0);
        game.myPlayer.position.setValues(750, 170);
        final beforeLanding = game.gameState.health;
        for (
          var i = 0;
          i < 360 && boss.fight.phase != WalkerPhase.recovery;
          i++
        ) {
          game.update(1 / 120);
        }
        expect(boss.fight.blasts.any((b) => b.landing), isTrue);
        expect(game.gameState.health, beforeLanding - 2);
        game.gameNotifier.resetHealth();
        game.gameNotifier.advanceTime(3);
        // Fatal transition has no occult departure, picker, heal or profile reward.
        final kills = game.gameState.kills;
        boss.takeDamage(boss.combatHealth.maximum);
        expect(boss.fight.phase, WalkerPhase.failing);
        expect(boss.fight.rounds, isEmpty);
        expect(game.gameState.kills, kills);
        game.myPlayer.position.setFrom(boss.position + Vector2(350, 0));
        game.setTrainingDamage(true);
        final health = game.gameState.health;
        game.pauseGame();
        final age = boss.fight.clock;
        game.update(5);
        expect(boss.fight.clock, age);
        game.resumeGame();
        game.pauseEngine();
        for (var i = 0; i < 30 * 7; i++) {
          game.update(1 / 30);
          if (i % 6 == 0) await game.ready();
          if (i.isEven) await frame();
        }
        expect(boss.fight.finished, isTrue);
        expect(boss.fight.detonations, 1);
        expect(game.gameState.health, health - 3);
        expect(game.gameState.kills, kills);
        if (encoder != null) {
          await encoder!.stdin.close();
          expect(await encoder!.exitCode, 0, reason: await errors!);
        }
      });
      final owned = boss.assets;
      game.practiceBoss(BossKind.shadow);
      for (var i = 0; i < 200 && game.activeBoss?.isMounted != true; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      expect(game.walkerCandidate, isNull);
      expect(game.walkerTrial, isFalse);
      expect(owned.decodedBytes, 0);
      expect(game.activeBoss, isNotNull);
      game.practiceWalker();
      for (var i = 0; i < 200 && game.walkerCandidate?.prepared != true; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      expect(game.walkerCandidate!.prepared, isTrue);
      expect(game.trainingDamage, isTrue);
      final pending = game.walkerCandidate!;
      game.practiceWalker();
      game.practiceBoss(BossKind.demon);
      for (var i = 0; i < 200 && game.activeBoss?.isMounted != true; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      expect(pending.assets.decodedBytes, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
