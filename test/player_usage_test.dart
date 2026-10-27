import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';

void main() {
  test(
    'guest career usage settles once, persists, and resets with profile',
    () {
      final summary = jsonDecode(
        File('test/fixtures/run-record-v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final p = PlayerProfile();
      void settle() => p.settle(
        runId: summary['runId'],
        loadout: const Loadout(),
        kills: 35,
        score: 1250,
        seconds: 120,
        earnedScrap: 10,
        scorpions: 0,
        elites: 0,
        bosses: {},
        noHitBosses: {},
        foundFusions: {},
        enemies: {},
        trackedRun: summary,
      );
      settle();
      settle();
      expect(p.publicUsage.weapons['shotgun']!['runs'], 1);
      expect(p.publicUsage.upgrades['heavyLoad'], {'runs': 1, 'picks': 2});
      final copy = PlayerProfile.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(copy.publicUsage.toJson(), p.publicUsage.toJson());
      expect(PlayerProfile().publicUsage.weapons, isEmpty);
    },
  );
  test('old journal migration counts actual summaries once without fabricating legacy usage', () {
    final summary = jsonDecode(
      File('test/fixtures/run-record-v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final raw = PlayerProfile().toJson()..remove('publicUsage');
    raw['settledRuns'] = [summary['runId']];
    raw['runRecords'] = {
      summary['runId']: {
        'owner': 'guest',
        'status': 'personal_only',
        'summary': summary,
      },
    };
    final p = PlayerProfile.fromJson(raw);
    expect(p.publicUsage.weapons['shotgun']!['runs'], 1);
    expect(
      PlayerProfile.fromJson(p.toJson())
          .publicUsage
          .weapons['shotgun']!['runs'],
      1,
    );
    expect(
      PlayerProfile.fromJson({'schema': 3, 'bestScore': 999999})
          .publicUsage
          .weapons,
      isEmpty,
    );
  });
  test(
    'continued legacy summaries recover known weapon and accepted picks once',
    () {
      final summary = jsonDecode(
        File('test/fixtures/run-record-v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      summary['complete'] = false;
      final raw = PlayerProfile().toJson();
      (raw['publicUsage'] as Map).remove('coverage');
      raw['settledRuns'] = [summary['runId']];
      raw['runRecords'] = {
        summary['runId']: {
          'owner': 'guest',
          'status': 'personal_only',
          'summary': summary,
        },
      };
      final recovered = PlayerProfile.fromJson(raw);
      expect(recovered.publicUsage.weapons['shotgun']!['runs'], 1);
      expect(recovered.publicUsage.upgrades['heavyLoad']!['picks'], 2);
      final restored = PlayerProfile.fromJson(recovered.toJson());
      expect(restored.publicUsage.weapons['shotgun']!['runs'], 1);
      expect(restored.publicUsage.upgrades['heavyLoad']!['picks'], 2);
    },
  );
}
