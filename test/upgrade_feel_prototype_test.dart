import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_integration_test.dart' show Quiet;

void main() {
  testWidgets(
    'six-family phone-scale actual runtime comparisons and held-clock safety',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final measurements = <Map<String, Object?>>[];
      final capture = Platform.environment['REGUN_UPGRADE_CLIPS'] == '1';
      final infusion = Platform.environment['REGUN_UPGRADE_INFUSION'] == '1';
      final sequences =
          Platform.environment['REGUN_UPGRADE_SEQUENCE_CLIPS'] == '1';
      await tester.runAsync(() async {
        for (final entry in {
          'Orbitron': 'assets/fonts/Orbitron-SemiBold.ttf',
          'PressStart2P': 'assets/fonts/PressStart2P-Regular.ttf',
        }.entries) {
          await (FontLoader(
            entry.key,
          )..addFont(rootBundle.load(entry.value))).load();
        }
        for (final arena in ArenaType.values) {
          for (final variant
              in Platform.environment['REGUN_UPGRADE_ALTERNATIVES'] == '1'
                  ? ['short', 'reduced']
                  : ['baseline', 'full']) {
            if ((infusion || sequences) && variant != 'full') continue;
            final mode = variant == 'baseline'
                ? UpgradeFeelMode.baseline
                : variant == 'short'
                ? UpgradeFeelMode.short
                : UpgradeFeelMode.full;
            for (final family in [
              'heavyLoad',
              'walkingSpeedIncrease',
              'scrapArmour',
              'hotShot',
              'ricochet',
              'sentry',
            ]) {
              if (infusion && family != 'heavyLoad') continue;
              if ((variant == 'short' || variant == 'reduced') &&
                  family != 'heavyLoad') {
                continue;
              }
              if (Platform.environment['REGUN_UPGRADE_SENTRY_ONLY'] == '1' &&
                  family != 'sentry') {
                continue;
              }
              final audio = Quiet();
              await tester.pumpWidget(
                ProviderScope(
                  key: UniqueKey(),
                  overrides: [soloudPlayProvider.overrideWithValue(audio)],
                  child: MaterialApp(
                    home: BaseView(
                      loadout: Loadout(
                        training: true,
                        arena: arena,
                        weapon: WeaponType.carbine,
                      ),
                      upgradeFeelMode: mode,
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
              LocalPreferences.shared.reducedMotion = variant == 'reduced';
              game.pauseEngine();
              game.update(2);
              game.update(1 / 60);
              game.random.state = 13;
              game.myPlayer.position.setZero();
              game.gameNotifier.advanceTime(3);
              final enemies = [
                Enemy2Component(
                  position: family == 'sentry'
                      ? Vector2(900, 700)
                      : Vector2(240, 0),
                ),
                Enemy2Component(
                  position: family == 'sentry'
                      ? Vector2(1000, 700)
                      : Vector2(370, 15),
                ),
              ];
              await game.world.addAll(enemies);
              await game.ready();
              final facing = switch (family) {
                'walkingSpeedIncrease' => Vector2(0, 1),
                'scrapArmour' => Vector2(-1, 0),
                'hotShot' => Vector2(0, -1),
                _ => Vector2(1, 0),
              };
              game.weaponJoystick.delta.setFrom(facing * 60);
              game.myPlayer.update(0);
              game.resetInput();
              final folder = Directory(
                'build/${sequences
                    ? 'upgrade-six-infusion-clips'
                    : infusion
                    ? 'upgrade-infusion-clips'
                    : 'upgrade-feel-clips'}/${arena.name}-$variant-$family',
              );
              if (capture) {
                await folder.create(recursive: true);
                await for (final file in folder.list()) {
                  if (file is File &&
                      RegExp(r'/[0-9]{4}\.png$').hasMatch(file.path)) {
                    await file.delete();
                  }
                }
              }
              Future<void> captureFrame(int frame) async {
                if (!capture) return;
                final recorder = ui.PictureRecorder(),
                    canvas = Canvas(recorder);
                game.render(canvas);
                final picture = recorder.endRecording();
                final image = await picture.toImage(844, 390);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${folder.path}/${frame.toString().padLeft(4, '0')}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
                picture.dispose();
              }

              final preRoll = infusion || sequences ? 24 : 0;
              for (var frame = 0; frame < preRoll; frame++) {
                game.update(1 / 30);
                await game.ready();
                await captureFrame(frame);
              }
              game.pauseGame();
              if (family == 'sentry') {
                game.gameNotifier.offerSupportPractice(SupportFamily.sentry);
              } else {
                game.gameNotifier.offerUpgradeFeelPractice(
                  PowerUp.values.byName(family),
                );
              }
              if (mode != UpgradeFeelMode.baseline) {
                final recipe = UpgradeArtLease.atlasFor(
                  family == 'sentry' ? 'support:sentry' : family,
                );
                await RegunArt.shared.acquire(recipe);
                RegunArt.shared.release(recipe);
              }
              final token = game.gameState.offerId;
              final before = game.gameState;
              if (family == 'sentry') {
                game.gameNotifier.chooseSupport(
                  game.gameNotifier.support.offer!.id,
                  offerId: token,
                );
              } else {
                game.gameNotifier.applyPowerUp(
                  PowerUp.values.byName(family),
                  offerId: token,
                );
              }
              expect(game.gameState.gameplayState, GameplayState.playing);
              expect(game.checkpoint()['upgradePulsePending'], isTrue);
              Map<String, dynamic>? heldSnapshot;
              if (mode == UpgradeFeelMode.full) {
                expect(game.presentationHeld, isTrue);
                final at = enemies.first.position.clone();
                final reload = game.gameNotifier.reloadRemainingSeconds;
                expect(enemies.first.position, at);
                expect(game.gameNotifier.reloadRemainingSeconds, reload);
                expect(
                  audio.sounds.where((s) => s == 'upgrade_pulse.wav'),
                  isEmpty,
                );
                expect(game.throwGrenade(), isFalse);
                expect(game.spawnShotgunBullets(), isFalse);
                final elapsed = game.upgradePresentation.elapsed;
                game.pauseGame();
                game.update(2);
                expect(game.upgradePresentation.elapsed, elapsed);
                game.resumeGame();
                heldSnapshot = game.checkpoint();
                expect(RunCheckpoint.valid(heldSnapshot), isTrue);
              }
              if (mode == UpgradeFeelMode.full) {
                expect(game.upgradePresentation.elapsed, 0);
              }
              final releaseFrame =
                  (game.upgradePresentation.duration * 30).ceil() + 5;
              final frames = family == 'sentry' ? 330 : 99;
              for (var frame = 0; frame < frames; frame++) {
                if (family == 'sentry' && frame == 270) {
                  // A controlled next opportunity AFTER landing crush. Runtime
                  // presentation never spawns targets or grants a guaranteed proc.
                  await game.world.add(
                    Enemy2Component(position: Vector2(470, 150)),
                  );
                  await game.ready();
                }
                if (frame == releaseFrame && !game.presentationHeld) {
                  if (family == 'walkingSpeedIncrease') {
                    game.movementJoystick.delta.setValues(60, 0);
                  } else if (family != 'sentry') {
                    game.weaponJoystick.delta.setValues(60, 0);
                  }
                  if (family == 'scrapArmour') {
                    game.setTrainingDamage(true);
                    game.damagePlayer();
                  }
                }
                game.update(1 / 30);
                await game.ready();
                await captureFrame(frame + preRoll);
              }
              measurements.add({
                'arena': arena.name,
                'mode': variant,
                'family': family,
                'balance': game.gameNotifier.weaponPower.snapshot?.hash,
                'beforeRank': family == 'sentry'
                    ? 0
                    : before.rank(PowerUp.values.byName(family)),
                'shots': game.shotsFired,
                'remainingHP': enemies
                    .map((e) => e.combatHealth.current)
                    .toList(),
                'firstUseObserved':
                    mode != UpgradeFeelMode.baseline &&
                    !game.upgradePresentation.firstUsePending,
                'firstOpportunityActiveSeconds':
                    mode != UpgradeFeelMode.baseline &&
                        !game.upgradePresentation.firstUsePending &&
                        game.upgradePresentation.activeAge < 20
                    ? game.upgradePresentation.activeAge -
                          game.upgradePresentation.useAge
                    : null,
                'pulseSounds': audio.sounds
                    .where((s) => s == 'upgrade_pulse.wav')
                    .length,
              });
              expect(
                audio.sounds.where((s) => s == 'upgrade_pulse.wav').length,
                1,
              );
              expect(game.presentationHeld, isFalse);
              if (heldSnapshot != null) {
                expect(game.restoreRun(heldSnapshot), isTrue);
                expect(game.presentationHeld, isFalse);
                expect(game.upgradePresentation.firstUsePending, isFalse);
              }
              await tester.pumpWidget(const SizedBox.shrink());
            }
          }
        }
        await File(
          'build/upgrade-feel-audit/${Platform.environment['REGUN_UPGRADE_SENTRY_ONLY'] == '1'
              ? 'sentry'
              : Platform.environment['REGUN_UPGRADE_ALTERNATIVES'] == '1'
              ? 'alternative'
              : 'prototype'}-runtime.json',
        ).writeAsString(jsonEncode(measurements));
        // Owner leases return to the baseline, including the prototype sheet.
        for (final atlas in UpgradeArtLease.familyAtlases.values) {
          expect(RegunArt.shared.contains(atlas), isFalse);
        }
        LocalPreferences.shared.reducedMotion = false;
      });
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  testWidgets(
    'hold freezes the entire checkpoint including live reload and grenade flight',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
            child: const MaterialApp(
              home: BaseView(
                loadout: Loadout(training: true),
                upgradeFeelMode: UpgradeFeelMode.full,
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
        game.update(.01);
        game.gameNotifier.advanceTime(3);
        game.gameNotifier.decreaseBullets();
        game.gameNotifier.reloadBullets();
        expect(game.throwGrenade(aim: Vector2(-1, 0)), isTrue);
        await game.ready();
        game.pauseGame();
        game.gameNotifier.offerUpgradeFeelPractice(PowerUp.heavyLoad);
        game.gameNotifier.applyPowerUp(
          PowerUp.heavyLoad,
          offerId: game.gameState.offerId,
        );
        final snapshot = game.checkpoint();
        expect(game.gameState.reloading, isTrue);
        game.update(.2);
        game.update(.1);
        expect(game.checkpoint(), snapshot);
        expect(game.upgradePresentation.elapsed, closeTo(.3, 1e-8));
        game.applicationActive = false;
        game.update(20);
        expect(game.upgradePresentation.elapsed, closeTo(.3, 1e-8));
        game.applicationActive = true;
        game.update(.8);
        game.update(.01);
        expect(game.presentationHeld, isFalse);
        expect(game.checkpoint()['upgradePulsePending'], isFalse);
        game.restartGame();
        expect(game.presentationHeld, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    },
  );
}
