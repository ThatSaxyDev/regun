import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/systems/upgrade_offer_policy.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/notifiers/game_notifier.dart';

void main() {
  test('Dart and server share deterministic version1 offer fixtures', () {
    final fixture = jsonDecode(
      File('test/fixtures/upgrade-offers-v1.json').readAsStringSync(),
    ) as Map;
    expect(fixture['version'], UpgradeOfferPolicy.version);
    for (final c in fixture['cases'] as List) {
      var i = 0;
      final selected = UpgradeOfferPolicy.choose(
        eligible: List<String>.from(c['eligible']),
        ranks: Map<String, int>.from(c['ranks']),
        special: Set<String>.from(c['special']),
        luck: (c['luck'] as num).toDouble(),
        recent: List<String>.from(c['recent']),
        random: () => (c['random'][i++] as num).toDouble(),
      );
      expect(selected, c['expected'], reason: c['name']);
    }
  });
  test(
    'capacity weights are .35 then .20 without the ordinary owned boost',
    () {
      double weight(
        String id,
        int rank, {
        bool recent = false,
        bool special = false,
        double luck = 0,
      }) => UpgradeOfferPolicy.weight(
        id,
        rank: rank,
        special: special,
        luck: luck,
        recent: recent,
      );
      for (final id in ['dashCapacity', 'grenadeCapacity']) {
        expect(weight(id, 0), .35);
        expect(weight(id, 1), .20);
        expect(weight(id, 1, recent: true), closeTo(.07, 1e-12));
      }
      expect(weight('heavyLoad', 1), 1.5);
      expect(weight('hotShot', 0, special: true, luck: 2), 1.7);
      expect(weight('heavyLoad', 0, recent: true), .35);
    },
  );
  test('40000 opening draws show rarer capacity and fewer immediate repeats without exclusions', () {
    final random = RunRandom(941);
    final counts = <String, int>{}, repeatCounts = <String, int>{};
    const pool = [
      'heavyLoad',
      'fastReload',
      'fieldMedic',
      'dashCapacity',
      'grenadeCapacity',
    ];
    for (var i = 0; i < 40000; i++) {
      for (final entry in [
        (counts, <String>[]),
        (repeatCounts, ['heavyLoad']),
      ]) {
        final chosen = UpgradeOfferPolicy.choose(
          eligible: pool,
          ranks: {},
          special: {},
          luck: 0,
          recent: entry.$2,
          random: random.nextDouble,
        );
        expect(chosen.toSet().length, 3);
        entry.$1.update(chosen.first, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final id in ['dashCapacity', 'grenadeCapacity']) {
      expect(counts[id]! / counts['heavyLoad']!, inInclusiveRange(.30, .40));
    }
    expect(repeatCounts['heavyLoad']!, lessThan(counts['heavyLoad']! * .55));
    expect(repeatCounts['heavyLoad']!, greaterThan(0));
  });
  test(
    'Continue restores history and RNG; old checkpoints keep legacy selection',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.resetRun(seed: 813);
      notifier.increaseXP(100);
      final snapshot = notifier.checkpoint();
      expect(snapshot['offerPolicy'], 1);
      expect(
        snapshot['recentOffers'],
        container
            .read(gameNotifierProvider)
            .powerUpChoices
            .map((p) => p.name)
            .toList(),
      );
      notifier.reroll(offerId: container.read(gameNotifierProvider).offerId);
      final expected = container.read(gameNotifierProvider).powerUpChoices;
      notifier.restoreCheckpoint(snapshot);
      notifier.playGame();
      notifier.reroll(offerId: container.read(gameNotifierProvider).offerId);
      expect(container.read(gameNotifierProvider).powerUpChoices, expected);
      final old = Map<String, dynamic>.from(snapshot)
        ..remove('offerPolicy')
        ..remove('recentOffers');
      notifier.restoreCheckpoint(old);
      expect(notifier.checkpoint()['offerPolicy'], 0);
      notifier.playGame();
      notifier.reroll(offerId: container.read(gameNotifierProvider).offerId);
      final legacy = container.read(gameNotifierProvider).powerUpChoices;
      notifier.restoreCheckpoint({...old, 'offerPolicy': 0});
      notifier.playGame();
      notifier.reroll(offerId: container.read(gameNotifierProvider).offerId);
      expect(container.read(gameNotifierProvider).powerUpChoices, legacy);
      for (final invalid in [
        {'offerPolicy': 1.0},
        {'offerPolicy': 2},
        {
          'recentOffers': ['bad'],
        },
        {
          'recentOffers': ['heavyLoad', 'heavyLoad'],
        },
        {
          'recentOffers': [
            'heavyLoad',
            'fastReload',
            'fieldMedic',
            'quickstep',
          ],
        },
      ]) {
        expect(
          () => notifier.restoreCheckpoint({...snapshot, ...invalid}),
          throwsFormatException,
        );
      }
    },
  );
}
