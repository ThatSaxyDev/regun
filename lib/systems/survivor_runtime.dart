import 'dart:math' as math;

import 'package:regun/data/loadout.dart';

/// Simulation-owned passive clocks and once-per-release ledgers. No wall time.
class SurvivorRuntime {
  double reloadCharge = 0, dashWindow = 0, dashGate = 0;
  double emberGate = 0, chainGate = 0, healGate = 0, rest = .8;
  double continuousGate = 0, wireGate = 0;
  int triage = 0, coil = 0, wire = 0, sequence = 0;
  int reloads = 0,
      grenadeKills = 0,
      burningKills = 0,
      chainVictims = 0,
      healed = 0;
  final _hitReleases = <int>{}, _chainVictims = <int>{};
  int lastRelease = 0;
  double releaseBonus = 0;
  void advance(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    reloadCharge = math.max(0, reloadCharge - dt);
    dashWindow = math.max(0, dashWindow - dt);
    dashGate = math.max(0, dashGate - dt);
    emberGate = math.max(0, emberGate - dt);
    chainGate = math.max(0, chainGate - dt);
    healGate = math.max(0, healGate - dt);
    continuousGate = math.max(0, continuousGate - dt);
    wireGate = math.max(0, wireGate - dt);
    rest = math.min(10, rest + dt);
  }

  void completedReload(CharacterType character) {
    reloads++;
    if (character == CharacterType.flint) reloadCharge = 4;
  }

  void landedDash(CharacterType character) {
    if (character == CharacterType.vesper && dashGate <= 0) {
      dashWindow = 1;
      dashGate = 4;
    }
  }

  /// Captured once before the release. A missed shot still spends its charge.
  double release(
    CharacterType character,
    double measured, {
    bool continuous = false,
  }) {
    lastRelease = ++sequence;
    releaseBonus = math.min(
      .60,
      (character == CharacterType.flint && reloadCharge > 0 ? .20 : 0) +
          (character == CharacterType.vesper && dashWindow > 0 ? .18 : 0) +
          (rest >= .8 - 1e-8 ? .08 * measured : 0),
    );
    reloadCharge = 0;
    rest = 0;
    if (_hitReleases.length > 512) _hitReleases.remove(_hitReleases.first);
    return 1 + releaseBonus;
  }

  bool qualifyingHit(int release, {bool continuous = false}) {
    if (release <= 0 || !_hitReleases.add(release)) return false;
    if (continuous && continuousGate > 0) return false;
    if (continuous) continuousGate = .5;
    return true;
  }

  bool coilHit() {
    coil = math.min(5, coil + 1);
    if (coil < 5 || chainGate > 0) return false;
    coil = 0;
    chainGate = .8;
    return true;
  }

  void chainVictim(int id) {
    if (_chainVictims.add(id)) chainVictims++;
  }

  void forgetVictim(int id) => _chainVictims.remove(id);

  bool get triageReady => triage >= 15 && healGate <= 0;
  void kill() => triage = math.min(15, triage + 1);
  Map<String, dynamic> toJson() => {
    'reloadCharge': reloadCharge,
    'dashWindow': dashWindow,
    'dashGate': dashGate,
    'emberGate': emberGate,
    'chainGate': chainGate,
    'healGate': healGate,
    'rest': rest,
    'continuousGate': continuousGate,
    'wireGate': wireGate,
    'triage': triage,
    'coil': coil,
    'wire': wire,
    'sequence': sequence,
    'reloads': reloads,
    'grenadeKills': grenadeKills,
    'burningKills': burningKills,
    'chainVictims': chainVictims,
    'healed': healed,
    'chainOwners': _chainVictims.toList(),
    'hitReleases': _hitReleases.toList(),
  };
  void restore(Map<String, dynamic> m) {
    double n(String key, double max) {
      final v = m[key] ?? 0;
      if (v is! num || !v.isFinite || v < 0 || v > max) {
        throw FormatException('Invalid passive $key');
      }
      return v.toDouble();
    }

    int i(String k, int max) {
      final v = n(k, max.toDouble());
      if (v != v.roundToDouble()) throw FormatException('Invalid counter $k');
      return v.toInt();
    }

    reloadCharge = n('reloadCharge', 4);
    dashWindow = n('dashWindow', 1);
    dashGate = n('dashGate', 4);
    emberGate = n('emberGate', 1);
    chainGate = n('chainGate', .8);
    healGate = n('healGate', 12);
    rest = n('rest', 10);
    continuousGate = n('continuousGate', .5);
    wireGate = n('wireGate', 1);
    triage = i('triage', 15);
    coil = i('coil', 5);
    wire = i('wire', 3);
    sequence = i('sequence', 1000000000);
    reloads = i('reloads', 1000000000);
    grenadeKills = i('grenadeKills', 1000000000);
    burningKills = i('burningKills', 1000000000);
    chainVictims = i('chainVictims', 1000000000);
    healed = i('healed', 1000000000);
    final owners = m['chainOwners'] ?? <int>[];
    if (owners is! List ||
        owners.length > 100000 ||
        owners.any((v) => v is! int || v < 1 || v > 1000000000)) {
      throw const FormatException('Invalid chain owners');
    }
    _chainVictims
      ..clear()
      ..addAll(owners.cast<int>());
    final releases = m['hitReleases'] ?? <int>[];
    if (releases is! List ||
        releases.length > 513 ||
        releases.any((v) => v is! int || v < 1 || v > sequence)) {
      throw const FormatException('Invalid release ledger');
    }
    _hitReleases
      ..clear()
      ..addAll(releases.cast<int>());
    lastRelease = 0;
    releaseBonus = 0;
  }
}
