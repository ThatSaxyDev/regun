import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class _Audio extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String path) async {
    sounds.add(path);
  }
}

void main() {
  late ProviderContainer container;
  late GameNotifier notifier;
  late _Audio audio;
  GameState state() => container.read(gameNotifierProvider);
  setUp(() {
    audio = _Audio();
    container = ProviderContainer(
      overrides: [soloudPlayProvider.overrideWithValue(audio)],
    );
    notifier = container.read(gameNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'catalogue has forty-three ranked families and eight reachable recipes',
    () {
      expect(powerUps.length, 43);
      expect(powerUps.toSet().length, 43);
      expect(fusionRecipes.length, 8);
      for (final recipe in fusionRecipes) {
        expect(
          recipe.available(
            GameState(ranks: {recipe.first: 3, recipe.second: 2}),
          ),
          isTrue,
        );
        expect(
          recipe.available(
            GameState(ranks: {recipe.first: 2, recipe.second: 2}),
          ),
          isFalse,
        );
      }
    },
  );

  for (final weapon in WeaponType.values) {
    test(
      '${weapon.title} has its own magazine, reload clock and cue sequence',
      () {
        notifier.resetRun(loadout: Loadout(weapon: weapon));
        expect(state().noOfBullets, weapon.capacity);
        notifier.decreaseBullets();
        notifier.decreaseBullets();
        notifier.reloadBullets();
        final duration = weapon == WeaponType.shotgun ? 1400 : weapon.reloadMs;
        notifier.advanceTime((duration - 1) / 1000);
        expect(state().reloading, isTrue);
        notifier.advanceTime(0.001);
        expect(state().reloading, isFalse);
        expect(state().noOfBullets, weapon.capacity);
        if (weapon == WeaponType.shotgun) {
          expect(audio.sounds, [
            'reload_shotgun_shell.wav',
            'reload_shotgun_shell.wav',
            'reload_shotgun_pump.wav',
          ]);
        } else {
          expect(audio.sounds, [
            for (var i = 0; i < 3; i++) 'reload_${weapon.name}_$i.wav',
          ]);
        }
      },
    );
  }

  for (final recipe in fusionRecipes) {
    test(
      '${recipe.title} consumes only its current stable offer and survives JSON',
      () {
        notifier.prepareTrainingFusion(recipe);
        final offer = state().offerId;
        expect(state().evolutionChoices, contains(recipe.id));
        notifier.fuse(recipe.id, offerId: offer);
        expect(state().fused(recipe.id), isTrue);
        final after = state();
        notifier.fuse(recipe.id, offerId: offer);
        expect(identical(after, state()), isTrue);
        final restored = GameState.fromJson(
          jsonDecode(jsonEncode(state().toJson())) as Map<String, dynamic>,
        );
        expect(restored.ranks, after.ranks);
        expect(restored.evolutions, after.evolutions);
      },
    );
  }

  test('capped build always has a useful fallback and no duplicate offers', () {
    final capped = GameState(ranks: {for (final p in powerUps) p: p.maxRank});
    expect(eligiblePowerUps(capped), [PowerUp.salvage]);
  });

  test(
    'reroll and ban consume once; stale interactions cannot spend again',
    () {
      notifier.increaseXP(8);
      final token = state().offerId;
      notifier.reroll(offerId: token);
      expect(state().rerolls, 1);
      notifier.reroll(offerId: token);
      expect(state().rerolls, 1);
      final banned = state().powerUpChoices.first;
      notifier.ban(banned, offerId: state().offerId);
      expect(state().bans, 0);
      expect(state().banned, contains(banned));
      expect(state().powerUpChoices, isNot(contains(banned)));
    },
  );
}
