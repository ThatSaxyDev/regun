import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Validate disk input before touching a live world; malformed primaries can
/// fall back to the previous completed file without affecting permanent progress.
class RunCheckpoint {
  static bool valid(Map<String, dynamic> map) {
    try {
      if (![1, 2].contains(map['schema']) ||
          map['id'] is! String ||
          (map['id'] as String).isEmpty) {
        return false;
      }
      Loadout.fromJson(Map<String, dynamic>.from(map['loadout'] as Map));
      final state =
          GameState.fromJson(Map<String, dynamic>.from(map['state'] as Map));
      if (state.health <= 0 ||
          state.maxHealth < state.health ||
          state.maxHealth > 10000 ||
          state.noOfBullets < 0 ||
          state.noOfBullets > state.maxBullets ||
          state.maxBullets > 100 ||
          state.maxBullets < 1 ||
          state.xP < 0 ||
          !state.noOfCoinsToUpgrade.isFinite ||
          state.noOfCoinsToUpgrade < 1 ||
          state.noOfCoinsToUpgrade > 1e12 ||
          !state.movementSpeed.isFinite ||
          state.movementSpeed <= 0 ||
          state.movementSpeed > 1500 ||
          !state.bulletSpeed.isFinite ||
          state.bulletSpeed <= 0 ||
          state.bulletSpeed > 2000 ||
          !state.shotDamage.isFinite ||
          state.shotDamage <= 0 ||
          state.shotDamage > 20 ||
          state.pendingCores < 0 ||
          state.pendingCores > 8 ||
          state.evolutions.length > 2 ||
          state.ranks.entries
              .any((e) => e.value < 0 || e.value > e.key.maxRank) ||
          state.evolutions.any((id) => !fusionRecipes.any((r) => r.id == id))) {
        return false;
      }
      bool number(dynamic value, double max) =>
          value is num && value.isFinite && value >= 0 && value <= max;
      bool point(dynamic value) =>
          value is List &&
          value.length == 2 &&
          value.every((v) => v is num && v.isFinite && v.abs() <= 1e7);
      if (!point(map['player']) ||
          !point(map['lastMovement']) ||
          !point(map['aim'])) {
        return false;
      }
      for (final key in [
        'activeSeconds',
        'reloadElapsedMs',
        'reloadDurationMs',
        'nextReloadSoundMs'
      ]) {
        if (!number(map[key], 1e9)) return false;
      }
      if (state.reloading && (map['reloadDurationMs'] as num) <= 0) {
        return false;
      }
      final enemies = map['enemies'] as List, drops = map['drops'] as List;
      if (enemies.length > 122 || drops.length > 80) return false;
      var bosses = 0;
      for (final raw in enemies) {
        final enemy = raw as Map;
        final id = enemy['kind'];
        if (!EnemyKind.values.any((e) => e.name == id) &&
            !BossKind.values.any((e) => e.name == id)) {
          return false;
        }
        if (BossKind.values.any((e) => e.name == id)) bosses++;
        if (!point([enemy['x'], enemy['y']]) ||
            !number(enemy['health'], 1e6) ||
            (enemy['health'] as num) <= 0 ||
            !number(enemy['maximum'], 1e6) ||
            (enemy['health'] as num) > (enemy['maximum'] as num)) {
          return false;
        }
      }
      if (bosses > (map['schema'] == 2 ? 2 : 1)) return false;
      for (final raw in drops) {
        final drop = raw as Map;
        if (!point([drop['x'], drop['y']]) ||
            drop['value'] is! int ||
            (drop['value'] as int) <= 0 ||
            (drop['value'] as int) > 1000000000) {
          return false;
        }
      }
      return true;
    } on Object {
      return false;
    }
  }
}
