import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/upgrade_details.dart';

void main() {
  test('brief offers keep meaningful counts, timing and healing limits', () {
    String brief(PowerUp p, [GameState? state]) => upgradeDetails(
      p,
      state ?? GameState(),
      WeaponType.shotgun,
      brief: true,
    );
    expect(brief(PowerUp.heavyLoad), 'Damage bonus 0% to 35%');
    expect(
      brief(PowerUp.heavyLoad, GameState(ranks: {PowerUp.heavyLoad: 7})),
      'Damage bonus 145% to 155%',
    );
    expect(brief(PowerUp.fastReload), 'Full reload 3.2s to 2s');
    expect(brief(PowerUp.maxBulletsIncrease), contains('5 to 7'));
    expect(brief(PowerUp.numberOfBulletsPerShotIncrease), 'Projectiles 3 to 5');
    expect(brief(PowerUp.fieldMedic), contains('6s cooldown'));
    expect(brief(PowerUp.executioner), contains('Below 35% HP'));
    expect(brief(PowerUp.grenadeRecharge), contains('18s to 16.5s'));
  });

  test('world units move to Details; late Scattershot describes spread', () {
    for (final p in [
      PowerUp.scavenger,
      PowerUp.luckyFind,
      PowerUp.grenadeRadius,
    ]) {
      expect(upgradeDescription(p), isNotEmpty);
      expect(
        upgradeDetails(p, GameState(), WeaponType.shotgun, brief: true),
        isEmpty,
      );
      expect(upgradeDetails(p, GameState(), WeaponType.shotgun), isNotEmpty);
    }
    expect(
      upgradeDescription(PowerUp.numberOfBulletsPerShotIncrease, rank: 3),
      contains('spread'),
    );
    expect(
      upgradeDetails(
        PowerUp.numberOfBulletsPerShotIncrease,
        GameState(ranks: {PowerUp.numberOfBulletsPerShotIncrease: 3}),
        WeaponType.shotgun,
        brief: true,
      ),
      contains('Count stays 9'),
    );
  });
}
