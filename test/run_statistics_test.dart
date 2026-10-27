import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/models/run_statistics.dart';
import 'package:regun/notifiers/game_notifier.dart';

void main() {
  test(
    'old checkpoints have unknown coverage and corrupt counters fail closed',
    () {
      expect(RunStatistics.read(null).complete, false);
      expect(
        () => RunStatistics.read({
          'schema': 1,
          'complete': true,
          'picks': {'heavyLoad': -1},
          'support': {},
        }),
        throwsFormatException,
      );
    },
  );
  test('accepted selections count once across restore, stale selection and restart', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(gameNotifierProvider.notifier)..resetRun();
    final snapshot = n.checkpoint();
    snapshot['state'] = c
        .read(gameNotifierProvider)
        .copyWith(
          gameplayState: GameplayState.powerup,
          powerUpChoices: [PowerUp.heavyLoad],
          offerId: 42,
        )
        .toJson();
    n.restoreCheckpoint(snapshot);
    n.playGame();
    n.applyPowerUp(PowerUp.heavyLoad, offerId: 42);
    n.applyPowerUp(PowerUp.heavyLoad, offerId: 42);
    expect(n.runStatistics.picks, {'heavyLoad': 1});
    n.restoreCheckpoint(n.checkpoint());
    expect(n.runStatistics.picks, {'heavyLoad': 1});
    n.resetRun();
    expect(n.runStatistics.picks, isEmpty);
  });
  test('settlement journal survives owner-scoped profile roundtrip with unchanged summary', () {
    final summary = jsonDecode(
      File('test/fixtures/run-record-v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final profile = PlayerProfile();
    profile.runRecords[summary['runId']] = {
      'owner': 'guest',
      'status': 'local',
      'summary': summary,
    };
    final copy = PlayerProfile.fromJson(
      jsonDecode(jsonEncode(profile.toJson())),
    );
    expect(copy.runRecords, profile.runRecords);
    expect(copy.runRecords.values.single['owner'], 'guest');
    expect(WeaponType.values.any((w) => w.name == summary['weapon']), true);
  });
}
