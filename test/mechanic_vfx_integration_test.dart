import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/mechanic_vfx.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/models/upgrade_animation_recipe.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

import 'support_integration_test.dart' show Quiet;

void main() {
  test(
    'accepted mechanic feedback settles across generations, pause and restore',
    () {
      final f = MechanicFeedback();
      f.sync(1, 30, 0);
      expect(f.healAge, -1);
      f.onlineShots(80, acceptedPerks: 3);
      expect(f.spent, 0, reason: 'initial server snapshot is a watermark');
      f.onlineShots(81, acceptedPerks: 3);
      expect(f.spent, 3);
      f.sync(1, 31, 0);
      expect(f.healAge, 0);
      f.sync(1, 31, 0);
      expect(f.healAge, 0);
      f.sync(1, 31, .7);
      expect(f.healAge, .7);
      f.sync(2, 50, 0);
      expect(f.healAge, -1);
      expect(f.spent, 0);
    },
  );
  test('infusion gestures match power semantics without recolouring medicine as fire', () {
    for (final id in ['quickTrigger', 'fastReload', 'sureFoot']) {
      expect(upgradeAnimationRecipe(id), 'walkingSpeedIncrease');
    }
    for (final id in ['staticCharge', 'fieldMedic', 'support:aura:8:field']) {
      expect(
        upgradeAnimationRecipe(id),
        'hotShot',
        reason: 'cupped energy acceptance',
      );
      expect(upgradeInfusionColor(id), isNot(upgradeInfusionColor('hotShot')));
    }
    expect(upgradeAnimationRecipe('lastShell'), 'heavyLoad');
    expect(upgradeAnimationRecipe('targetingLink'), 'ricochet');
    expect(upgradeAnimationRecipe('orbitDrone'), 'support:sentry');
  });
  testWidgets(
    'real mark/freeze/thaw/chains/healing and readiness across both floors',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['REGUN_MECHANIC_CLIPS'] == '1';
      await tester.runAsync(() async {
        for (final arena in ArenaType.values) {
          for (final reduced in [false, true]) {
            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
                child: MaterialApp(
                  home: BaseView(
                    loadout: Loadout(
                      training: true,
                      arena: arena,
                      weapon: WeaponType.arcCaster,
                    ),
                    reviewControlledSpawns: true,
                  ),
                ),
              ),
            );
            final g =
                tester
                        .widget<RiverpodAwareGameWidget>(
                          find.byType(RiverpodAwareGameWidget),
                        )
                        .game!
                    as RegunGame;
            await g.loaded;
            await tester.pump();
            await g.ready();
            g.pauseEngine();
            g.update(2);
            g.update(.01);
            g.preferences.reducedMotion = reduced;
            g.myPlayer.position.setZero();
            g.setTrainingDamage(true);
            final snapshot = g.gameNotifier.checkpoint();
            snapshot['state'] = g.gameState
                .copyWith(
                  ranks: {
                    PowerUp.targetingLink: 1,
                    PowerUp.exposedSeam: 1,
                    PowerUp.lastShell: 1,
                    PowerUp.breachLoader: 1,
                    PowerUp.measuredShot: 1,
                    PowerUp.hotShot: 1,
                  },
                  lastShellRank: 1,
                  breachRank: 1,
                )
                .toJson();
            g.gameNotifier.restoreCheckpoint(snapshot);
            g.resumeGame();
            g.update(.01);
            final a = Enemy2Component(position: Vector2(260, -75));
            final b = Enemy2Component(position: Vector2(380, 20));
            await g.world.addAll([a, b]);
            await g.ready();
            final folder = Directory(
              'build/mechanic-vfx/${arena.name}-${reduced ? 'reduced' : 'normal'}',
            );
            if (capture) await folder.create(recursive: true);
            for (var frame = 0; frame < 135; frame++) {
              if (frame == 15) {
                expect(
                  a.freeze(),
                  isTrue,
                  reason: 'freeze accepted ${arena.name} reduced=$reduced',
                );
                expect(
                  a.freeze(),
                  isFalse,
                  reason: 'presentation cannot refresh crowd control',
                );
                expect(g.hitEnemy(a, .1), isTrue, reason: 'real hit accepted');
                expect(a.marked, isTrue, reason: 'target mark');
                expect(a.burning, isTrue, reason: 'burn');
                expect(
                  b.combatHealth.current,
                  lessThan(b.combatHealth.maximum),
                );
                await g.ready();
                expect(
                  g.world.children.whereType<CombatEffect>().where(
                    (f) => f.endpoint != null,
                  ),
                  isNotEmpty,
                );
              }
              if (frame == 35) {
                expect(
                  g.damagePlayer(),
                  isTrue,
                  reason: 'health loss after resume grace',
                );
                final before = g.gameState.health;
                g.gameNotifier.heal();
                expect(g.gameState.health, before + 1);
                expect(g.gameNotifier.recoveredHealth, 1);
                g.gameNotifier.heal(100);
                final recovered = g.gameNotifier.recoveredHealth;
                g.gameNotifier.heal();
                expect(
                  g.gameNotifier.recoveredHealth,
                  recovered,
                  reason: 'full health never emits healing',
                );
              }
              if (frame == 65) {
                while (g.gameState.noOfBullets > 1) {
                  g.gameNotifier.decreaseBullets();
                }
                expect(g.readyPerkFlags & 1, 1);
              }
              if (frame == 75) {
                g.weaponJoystick.delta.setValues(80, 0);
                g.spawnShotgunBullets();
                g.weaponJoystick.delta.setZero();
                expect(g.myPlayer.mechanicFeedback.spent & 1, 1);
                expect(
                  g.readyPerkFlags,
                  0,
                  reason: 'empty/reload cannot show empowered readiness',
                );
              }
              g.update(1 / 30);
              await g.ready();
              if (capture) {
                final rec = ui.PictureRecorder();
                g.render(Canvas(rec));
                final pic = rec.endRecording();
                final im = await pic.toImage(844, 390);
                final bytes = await im.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${folder.path}/${frame.toString().padLeft(4, '0')}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                im.dispose();
                pic.dispose();
              }
            }
            expect(a.freezeHeld, isFalse);
            g.pauseGame();
            final age = g.myPlayer.mechanicFeedback.healAge;
            g.update(3);
            expect(g.myPlayer.mechanicFeedback.healAge, age);
            g.preferences.reducedMotion = false;
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'remapped infusion uses normal accepted choices and one recovery release',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['REGUN_MECHANIC_CLIPS'] == '1';
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
            child: const MaterialApp(
              home: BaseView(
                loadout: Loadout(training: true),
                reviewControlledSpawns: true,
              ),
            ),
          ),
        );
        final g =
            tester
                    .widget<RiverpodAwareGameWidget>(
                      find.byType(RiverpodAwareGameWidget),
                    )
                    .game!
                as RegunGame;
        await g.loaded;
        await tester.pump();
        await g.ready();
        g.pauseEngine();
        g.update(2);
        g.update(.01);
        g.myPlayer.position.setZero();
        final folder = Directory('build/mechanic-vfx/remapped-infusions');
        if (capture) await folder.create(recursive: true);
        var index = 0;
        for (final choice in [
          PowerUp.fieldMedic,
          PowerUp.staticCharge,
          PowerUp.lastShell,
          PowerUp.fastReload,
        ]) {
          for (var frame = 0; frame < 90; frame++) {
            if (frame == 15) {
              g.pauseGame();
              g.gameNotifier.offerUpgradeFeelPractice(choice);
              final packet = UpgradeArtLease.atlasFor(choice.name);
              await RegunArt.shared.acquire(packet);
              RegunArt.shared.release(packet);
              final xp = g.gameState.xP;
              g.gameNotifier.applyPowerUp(choice, offerId: g.gameState.offerId);
              expect(g.presentationHeld, isTrue);
              expect(g.gameState.xP, xp);
              expect(g.checkpoint()['upgradePulsePending'], isTrue);
            }
            g.update(1 / 30);
            await g.ready();
            if (capture) {
              final rec = ui.PictureRecorder();
              g.render(Canvas(rec));
              final pic = rec.endRecording();
              final im = await pic.toImage(844, 390);
              final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
              await File(
                '${folder.path}/${index.toString().padLeft(4, '0')}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              im.dispose();
              pic.dispose();
            }
            index++;
          }
          expect(g.presentationHeld, isFalse);
          expect(g.checkpoint()['upgradePulsePending'], isFalse);
          expect(g.gameState.rank(choice), 1);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    },
  );
}
