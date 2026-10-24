import 'package:regun/models/solo_recovery.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/systems/survivor_runtime.dart';
import 'package:regun/systems/arsenal_system.dart';
import 'package:regun/systems/freeze_state.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/systems/dash_reserve.dart';
import 'package:regun/systems/supply_drops.dart';
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
      if (map.containsKey('weaponAccessVersion') &&
          ![1, 2].contains(map['weaponAccessVersion'])) {
        return false;
      }
      if (map.containsKey('offerPolicy') &&
          (map['offerPolicy'] is! int ||
              ![0, 1].contains(map['offerPolicy']))) {
        return false;
      }
      if (map.containsKey('recentOffers')) {
        final history = map['recentOffers'];
        if (history is! List ||
            history.length > 3 ||
            history.toSet().length != history.length ||
            history.any(
              (id) => id is! String || !PowerUp.values.any((p) => p.name == id),
            )) {
          return false;
        }
      }
      final loadout = Loadout.fromJson(
        Map<String, dynamic>.from(map['loadout'] as Map),
      );
      final power = WeaponPowerBalance.read(
        map['weaponPowerBalance'],
        map['balanceSnapshot'],
      );
      if (map['arsenal'] case final Map raw) {
        if (WeaponPowerBalance.read(raw['powerBalance']).revision !=
            power.revision) {
          return false;
        }
        ArsenalSystem.validate(
          Map<String, dynamic>.from(raw),
          loadout.weapon,
          power: power,
        );
      }
      if (map.containsKey('buildBalance') &&
          ![1, 2].contains(map['buildBalance'])) {
        return false;
      }
      if (map.containsKey('survivorRuntime') &&
          map['survivorRuntime'] is! Map) {
        return false;
      }
      if (map['survivorRuntime'] case final Map raw) {
        SurvivorRuntime().restore(Map<String, dynamic>.from(raw));
      }
      if (map.containsKey('dashCount') &&
          (map['dashCount'] is! int ||
              map['dashCount'] < 0 ||
              map['dashCount'] > 1000000000)) {
        return false;
      }
      final ids = <int>{};
      for (final actor in map['enemies'] as List) {
        if (actor['cinder'] != null &&
            (actor['cinder'] is! num ||
                !(actor['cinder'] as num).isFinite ||
                actor['cinder'] < 0 ||
                actor['cinder'] > 1)) {
          return false;
        }
        if (actor['cinderTick'] != null &&
            (actor['cinderTick'] is! num ||
                !(actor['cinderTick'] as num).isFinite ||
                actor['cinderTick'] < 0 ||
                actor['cinderTick'] > .5)) {
          return false;
        }
        if (actor['combatId'] case final int id) {
          if (id < 1 || id > 1000000000 || !ids.add(id)) return false;
        }
        if (actor['freeze'] case final Map raw) {
          FreezeState().restore(Map<String, dynamic>.from(raw));
        }
      }
      if (map.containsKey('burstRecovery')) {
        final value = map['burstRecovery'];
        if (value is! num || !value.isFinite || value < 0 || value > .6) {
          return false;
        }
      }
      if (map.containsKey('supplyDrops')) {
        SupplyDrops().restore(
          Map<String, dynamic>.from(map['supplyDrops'] as Map),
        );
      }
      if (map.containsKey('upgradePulsePending') &&
          map['upgradePulsePending'] is! bool) {
        return false;
      }
      if (map.containsKey('dash')) {
        DashReserve().restore(Map<String, dynamic>.from(map['dash'] as Map));
      }
      if (map.containsKey('grenadeInventory')) {
        GrenadeInventory().restore(
          Map<String, dynamic>.from(map['grenadeInventory'] as Map),
        );
      }
      if (map.containsKey('grenadeProjectiles')) {
        final shots = map['grenadeProjectiles'] as List;
        if (shots.length > 4) return false;
        for (final raw in shots) {
          final data = Map<String, dynamic>.from(raw as Map);
          GrenadeFlight.restore(data);
          if ([
                data['damage'],
                data['radius'],
              ].any((v) => v is! num || !v.isFinite) ||
              (data['damage'] as num) <= 0 ||
              (data['damage'] as num) > 30 ||
              (data['radius'] as num) < 100 ||
              (data['radius'] as num) > 300) {
            return false;
          }
        }
      }
      final state = GameState.fromJson(
        Map<String, dynamic>.from(map['state'] as Map),
      ).copyWith(upgradeStrengths: power.upgradeStrengths);
      final recovery = map['recovery'] is Map
          ? SoloRecovery.fromJson(map['recovery'] as Map)
          : null;
      final deadRecovery =
          recovery != null &&
          !loadout.training &&
          ['offered', 'requested', 'ended'].contains(recovery.stage);
      if ((state.health <= 0 && !deadRecovery) ||
          state.health < 0 ||
          state.health > 1000000 ||
          state.maxHealth <= 0 ||
          state.maxHealth > 10000 ||
          state.noOfBullets < 0 ||
          state.noOfBullets > state.maxBullets ||
          state.maxBullets >
              (loadout.weapon == WeaponType.beltRepeater ? 128 : 100) ||
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
          state.ranks.entries.any(
            (e) => e.value < 0 || e.value > e.key.maxRank,
          ) ||
          state.evolutions.any((id) => !fusionRecipes.any((r) => r.id == id))) {
        return false;
      }
      if (map['grenadeInventory'] case final Map raw) {
        if ((raw['capacity'] ?? 2) != state.grenadeCapacity) return false;
      }
      if (map['dash'] case final Map raw) {
        if ((raw['capacity'] ?? 1) != state.dashCapacity) return false;
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
        'nextReloadSoundMs',
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
