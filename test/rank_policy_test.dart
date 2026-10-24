import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/systems/rank_curve.dart';
import 'package:regun/systems/rank_effect_values.dart';

void main() {
  test('915 shared API/mobile projection cases cover every offered family', () {
    final fixture = jsonDecode(
      File('test/fixtures/rank-effects-v1.json').readAsStringSync(),
    );
    expect(fixture['catalogId'], LiveBalance.catalogId);
    final values = Map<String, num>.from(fixture['values']);
    final seen = <String>{};
    for (final c in fixture['cases']) {
      seen.add(c['id']);
      final actual = RankEffects.values(
        c['id'],
        c['rank'],
        values,
        weapon: c['weapon'],
        survivor: c['survivor'],
      );
      expect(actual.keys.toSet(), (c['effects'] as Map).keys.toSet());
      for (final e in actual.entries) {
        expect(
          e.value,
          closeTo(c['effects'][e.key], 1e-8),
          reason:
              '${c['id']} ${c['rank']} ${c['weapon']} ${c['survivor']} ${e.key}',
        );
      }
    }
    expect(seen, powerUps.map((p) => p.name).toSet());
  });
  test(
    'milestones preserve I–III and VIII through all legal curve extremes',
    () {
      for (final iv in [.5, 1.4, 2.0]) {
        for (final viii in [.5, 1.6, 2.0]) {
          final v = <String, num>{
            'ranks.meta.policy': 1,
            'ranks.heavyLoad.iv': iv,
            'ranks.heavyLoad.viii': viii,
          };
          for (final rank in [1, 2, 3, 8]) {
            expect(
              RankCurve.total(rank, 'heavyLoad', .35, .1, v),
              closeTo(RankCurve.total(rank, 'heavyLoad', .35, .1, {}), 1e-10),
            );
          }
          for (var r = 1; r <= 8; r++) {
            expect(
              RankCurve.total(r, 'heavyLoad', 1, .3, v),
              greaterThan(RankCurve.total(r - 1, 'heavyLoad', 1, .3, v)),
            );
          }
        }
      }
    },
  );
  test('real grants follow pinned curves and Continue never picks up a newer release', () {
    final previous = BalanceRepository.shared.current;
    addTearDown(() => BalanceRepository.shared.current = previous);
    BalanceRepository.shared.current = LiveBalance.bundled;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(gameNotifierProvider.notifier)..resetRun();
    void grant(PowerUp p) {
      final saved = notifier.checkpoint();
      saved['state'] = c
          .read(gameNotifierProvider)
          .copyWith(
            gameplayState: GameplayState.powerup,
            powerUpChoices: [p],
            offerId: c.read(gameNotifierProvider).offerId + 1,
          )
          .toJson();
      notifier.restoreCheckpoint(saved);
      notifier.playGame();
      notifier.applyPowerUp(p, offerId: c.read(gameNotifierProvider).offerId);
    }

    for (var rank = 1; rank <= 8; rank++) {
      grant(PowerUp.heavyLoad);
      final s = c.read(gameNotifierProvider);
      expect(
        s.shotDamage,
        closeTo(
          s.rankValues(
            PowerUp.heavyLoad,
            rank,
            WeaponType.shotgun,
            CharacterType.rook,
            notifier.weaponPower,
          )['Damage multiplier']!,
          1e-8,
        ),
      );
    }
    final saved = notifier.checkpoint();
    BalanceRepository.shared.current = LiveBalance.create(20, {
      ...LiveBalance.bundled.values,
      'ranks.heavyLoad.iv': 2,
      'ranks.heavyLoad.viii': .5,
    });
    notifier.restoreCheckpoint(saved);
    expect(c.read(gameNotifierProvider).rankCurves['ranks.heavyLoad.iv'], 1.4);
    notifier.resetRun();
    expect(c.read(gameNotifierProvider).rankCurves['ranks.heavyLoad.iv'], 2);
  });
  test('exhausted survivor and weapon effects stop being offered under the new policy', () {
    final power = WeaponPowerBalance.live(LiveBalance.bundled);
    GameState s(Map<PowerUp, int> ranks) => GameState(
      ranks: ranks,
      rankCurves: power.rankCurves,
      upgradeStrengths: power.upgradeStrengths,
    );
    expect(
      eligiblePowerUps(
        s({PowerUp.fastReload: 4}),
        character: CharacterType.flint,
        power: power,
      ),
      isNot(contains(PowerUp.fastReload)),
    );
    expect(
      eligiblePowerUps(
        s({PowerUp.grenadeRecharge: 7}),
        character: CharacterType.fuse,
        power: power,
      ),
      isNot(contains(PowerUp.grenadeRecharge)),
    );
    expect(
      eligiblePowerUps(
        s({PowerUp.staticCharge: 3}),
        weapon: WeaponType.arcCaster,
        power: power,
      ),
      isNot(contains(PowerUp.staticCharge)),
    );
    expect(
      eligiblePowerUps(
        s({PowerUp.faradayReserve: 5}),
        weapon: WeaponType.arcCaster,
        power: power,
      ),
      isNot(contains(PowerUp.faradayReserve)),
    );
    expect(
      eligiblePowerUps(
        s({PowerUp.faradayReserve: 5}),
        weapon: WeaponType.arcCaster,
        character: CharacterType.coil,
        power: power,
      ),
      contains(PowerUp.faradayReserve),
    );
    expect(
      eligiblePowerUps(
        GameState(ranks: {PowerUp.fastReload: 3}),
        character: CharacterType.flint,
      ),
      contains(PowerUp.fastReload),
    );
  });
}
