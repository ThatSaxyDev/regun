import 'package:regun/data/enemies.dart';
import 'dart:math';

/// Run time advances only during active play. Rendering slow motion cannot
/// create a backlog of encounters or stack bosses.
class EncounterDirector {
  double elapsed = 0;
  double _spawnElapsed = 0;
  double _nextBoss = 180;
  double _recoveryUntil = 0;
  bool bossActive = false;
  int bossesDefeated = 0;

  /// Combat population targets, independent of the emergency runtime cap.
  /// Pressure grows through roles/elites/cycles instead of unlimited bodies.
  int get populationLimit => min(60, 20 + elapsed ~/ 12);
  int get visibleLimit => min(44, 18 + elapsed ~/ 20);

  bool canReinforce({required int arena, required int visible}) =>
      arena < populationLimit && visible < visibleLimit;

  int get cycle => elapsed ~/ 600 + 1;
  double get healthScale {
    final completed = cycle - 1;
    return 1 + completed * 0.5 + pow(completed, 1.3) * 0.15;
  }

  Map<String, dynamic> toJson() => {
        'elapsed': elapsed,
        'spawnElapsed': _spawnElapsed,
        'nextBoss': _nextBoss,
        'recoveryUntil': _recoveryUntil,
        'bossActive': bossActive,
        'bossesDefeated': bossesDefeated,
      };

  void restore(Map<String, dynamic> json) {
    elapsed = (json['elapsed'] as num).toDouble();
    _spawnElapsed = (json['spawnElapsed'] as num).toDouble();
    _nextBoss = (json['nextBoss'] as num).toDouble();
    _recoveryUntil = (json['recoveryUntil'] as num).toDouble();
    bossActive = json['bossActive'] as bool;
    bossesDefeated = json['bossesDefeated'] as int;
    if (![elapsed, _spawnElapsed, _nextBoss, _recoveryUntil]
        .every((v) => v.isFinite && v >= 0)) {
      throw const FormatException('Invalid encounter clock');
    }
  }

  bool advance(double dt) {
    elapsed += dt;
    _spawnElapsed += dt;
    final interval = bossActive ? 2.8 : max(0.28, 0.8 - elapsed / 900);
    if (_spawnElapsed < interval) return false;
    _spawnElapsed = 0; // No catch-up burst after a long frame.
    return true;
  }

  bool get bossDue =>
      !bossActive && elapsed >= _nextBoss && elapsed >= _recoveryUntil;

  void beginBoss() {
    bossActive = true;
    final cycleStart = elapsed ~/ 600 * 600;
    _nextBoss = [180.0, 360.0, 600.0, 780.0]
        .map((t) => cycleStart + t)
        .firstWhere((t) => t > elapsed + 0.01);
  }

  void defeatBoss() {
    if (!bossActive) return;
    bossActive = false;
    bossesDefeated++;
    _recoveryUntil = elapsed + 60;
    // Missed requests coalesce rather than accumulating a boss queue.
    _nextBoss = max(_nextBoss, _recoveryUntil);
  }

  EnemyKind chooseEnemy(Random random) {
    final unlocked = [
      if (elapsed >= 110) EnemyKind.runner,
      if (elapsed >= 220) EnemyKind.shield,
      if (elapsed >= 270) EnemyKind.burster,
      if (elapsed >= 400) EnemyKind.nest,
      if (elapsed >= 460) EnemyKind.sentinel
    ];
    if (unlocked.isNotEmpty && random.nextDouble() < 0.35) {
      return unlocked[random.nextInt(unlocked.length)];
    }
    if (elapsed >= 65 && random.nextDouble() < 0.18) {
      return EnemyKind.ranged;
    }
    if (elapsed >= 25 && random.nextDouble() < 0.3) {
      return EnemyKind.mummy;
    }
    return EnemyKind.scorpion;
  }
}
