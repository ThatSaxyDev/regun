import 'package:regun/models/boss_history.dart';
import 'package:regun/data/enemies.dart';

import 'dart:math';

/// Run time advances only during active play. Rendering slow motion cannot
/// create a backlog of encounters or stack bosses.
class EncounterDirector {
  EncounterDirector({Map<String, int>? bossWins})
    : _openingWins = bossWins == null
          ? null
          : Map.unmodifiable(BossHistory.read(bossWins));
  Map<String, int>? _openingWins;

  double elapsed = 0;
  double _spawnElapsed = 0;
  double _nextBoss = 180;
  double _recoveryUntil = 0;
  bool bossActive = false;
  int bossesDefeated = 0;
  final _bossBag = <BossKind>[];
  BossKind? _lastBoss;
  BossKind chooseBoss(Random random) {
    if (_bossBag.isEmpty) {
      _bossBag.addAll(BossKind.active);
      _bossBag.shuffle(random);
      final openingWins = _openingWins;
      if (openingWins != null) {
        final fewestWins = _bossBag
            .map((boss) => openingWins[boss.name] ?? 0)
            .reduce(min);
        final leastBeaten = _bossBag
            .where((boss) => (openingWins[boss.name] ?? 0) == fewestWins)
            .toList();
        // Two tickets per boss, plus one for each tied at the fewest wins.
        if (leastBeaten.length < _bossBag.length) {
          final baseTickets = 2 * _bossBag.length;
          final ticket = random.nextInt(baseTickets + leastBeaten.length);
          final openingIndex = ticket < baseTickets
              ? ticket ~/ 2
              : _bossBag.indexOf(leastBeaten[ticket - baseTickets]);
          final openingBoss = _bossBag[openingIndex];
          _bossBag[openingIndex] = _bossBag.first;
          _bossBag[0] = openingBoss;
        }
        _openingWins = null;
      }
      if (_bossBag.first == _lastBoss) {
        final first = _bossBag.removeAt(0);
        _bossBag.add(first);
      }
    }
    return _lastBoss = _bossBag.removeAt(0);
  }

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
    'bossBag': _bossBag.map((kind) => kind.name).toList(),
    'lastBoss': _lastBoss?.name,
    if (_openingWins != null) 'openingBossWins': _openingWins,
  };

  void restore(Map<String, dynamic> json) {
    final history = json['openingBossWins'];
    if (history != null && !BossHistory.valid(history)) {
      throw const FormatException('Invalid boss history');
    }
    _openingWins = history == null
        ? null
        : Map.unmodifiable(BossHistory.read(history));
    elapsed = (json['elapsed'] as num).toDouble();
    _spawnElapsed = (json['spawnElapsed'] as num).toDouble();
    _nextBoss = (json['nextBoss'] as num).toDouble();
    _recoveryUntil = (json['recoveryUntil'] as num).toDouble();
    bossActive = json['bossActive'] as bool;
    bossesDefeated = json['bossesDefeated'] as int;
    _bossBag.clear();
    _bossBag.addAll(
      (json['bossBag'] as List? ?? []).map((id) => BossKind.read(id as String)),
    );
    _lastBoss = json['lastBoss'] == null
        ? null
        : BossKind.read(json['lastBoss'] as String);
    if (![
      elapsed,
      _spawnElapsed,
      _nextBoss,
      _recoveryUntil,
    ].every((v) => v.isFinite && v >= 0)) {
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
    _nextBoss = [
      180.0,
      360.0,
      600.0,
      780.0,
    ].map((t) => cycleStart + t).firstWhere((t) => t > elapsed + 0.01);
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
      if (elapsed >= 460) EnemyKind.sentinel,
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
