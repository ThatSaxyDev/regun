import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/accepted_upgrade.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/models/upgrade_animation_recipe.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

import 'support_integration_test.dart' show Quiet;

void main() {
  test(
    'every upgrade, fusion and support has a shared reaction on every survivor',
    () {
      expect(upgradeRewardIds, {
        ...PowerUp.values.map((p) => p.name),
        ...fusionRecipes.map((f) => f.id),
      });
      final ids = [
        ...upgradeRewardIds,
        'support:sentry:1:carbine',
        'support:aura:1:field',
      ];
      for (final character in CharacterType.values) {
        for (final id in ids) {
          final reward = AcceptedUpgrade(
            generation: 1,
            actor: 'solo',
            serial: 1,
            offerId: 1,
            source: 'xp',
            id: id,
            beforeRank: 0,
            afterRank: 1,
            balance: 'pinned',
            before: const {
              'Damage multiplier': 1,
              'Walking speed': 300,
              'Guard recharge (s)': 20,
              'Burn per tick': 0,
              'Extra bounces': 0,
            },
            after: const {
              'Damage multiplier': 1.35,
              'Walking speed': 330,
              'Guard recharge (s)': 17,
              'Burn per tick': .45,
              'Extra bounces': 1,
              'Battery (s)': 36,
              'Incoming (s)': 6,
            },
          );
          final c = UpgradePresentationController(mode: UpgradeFeelMode.full);
          expect(
            c.accept(
              reward,
              reducedMotion: false,
              rook: character == CharacterType.rook,
            ),
            isTrue,
            reason: '${character.name}/$id',
          );
          expect(c.holding, isTrue);
          expect(
            UpgradeArtLease.familyAtlases.values,
            contains(UpgradeArtLease.atlasFor(id)),
          );
          expect(AcceptedUpgrade.read(reward.toJson())!.id, id);
        }
      }
    },
  );
  testWidgets(
    'ordinary funded upgrade triggers and renders without any review options',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        for (final character in [CharacterType.rook, CharacterType.scrapper]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
              child: MaterialApp(
                home: BaseView(loadout: Loadout(character: character)),
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
          expect(game.upgradeFeelMode, UpgradeFeelMode.full);
          game.gameNotifier.increaseXP(
            game.gameState.noOfCoinsToUpgrade.ceil(),
          );
          expect(game.gameState.gameplayState, GameplayState.powerup);
          expect(find.textContaining('1100ms'), findsNothing);
          expect(find.text('UPGRADE FEEL · PLAYER REVIEW'), findsNothing);
          final chosen = game.gameState.powerUpChoices.first;
          game.gameNotifier.applyPowerUp(
            chosen,
            offerId: game.gameState.offerId,
          );
          expect(game.presentationHeld, isTrue);
          final checkpoint = game.checkpoint();
          expect(RunCheckpoint.valid(checkpoint), isTrue);
          game.update(.5);
          expect(game.checkpoint(), checkpoint);
          final recorder = ui.PictureRecorder();
          game.render(Canvas(recorder));
          recorder.endRecording().dispose();
          game.update(2);
          expect(game.upgradePresentation.releasing, isTrue);
          expect(game.upgradePresentation.releaseAge, 0);
          expect(game.checkpoint()['upgradePulsePending'], isFalse);
          game.update(.01);
          expect(game.presentationHeld, isFalse);
          expect(game.checkpoint()['upgradePulsePending'], isFalse);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
