import 'package:regun/models/accepted_upgrade.dart';
import 'package:regun/multiplayer/combat_state.dart';

/// A subscription baseline is a watermark, never a queue of past celebrations.
class OnlineUpgradeReceipts {
  String? _scope;
  final _seen = <String, int>{};
  final active = <String, AcceptedUpgrade>{};
  final releasing = <String, AcceptedUpgrade>{};
  final _armed = <String, AcceptedUpgrade>{};
  final _releaseAge = <String, double>{};
  double releaseAge(String actor) => _releaseAge[actor] ?? -1;
  final useLabels = <String, String>{};
  final _useSeen = <String, int>{};
  final _useAge = <String, double>{};
  void advanceActive(double dt) {
    for (final actor in releasing.keys.toList()) {
      final age = (_releaseAge[actor] ?? 0) + dt;
      if (age >= .24) {
        releasing.remove(actor);
        _releaseAge.remove(actor);
      } else {
        _releaseAge[actor] = age;
      }
    }
    for (final key in useLabels.keys.toList()) {
      final age = (_useAge[key] ?? 0) + dt;
      _useAge[key] = age;
      if (age >= .8) {
        useLabels.remove(key);
        _useAge.remove(key);
      }
    }
  }

  bool _initialized = false;
  void clear() {
    _scope = null;
    _seen.clear();
    active.clear();
    releasing.clear();
    _armed.clear();
    _releaseAge.clear();
    useLabels.clear();
    _useSeen.clear();
    _useAge.clear();
    _initialized = false;
  }

  void sync(String scope, OnlineMatch? match, Map<String, OnlineGun> guns) {
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    final initial = !_initialized;
    if (guns.isEmpty) return;
    _initialized = true;

    for (final entry in guns.entries) {
      final raw = entry.value.progress['acceptedReward'];
      if (raw is! Map) continue;
      try {
        final serial = raw['serial'];
        if (serial is! int) continue;
        if (initial) {
          _seen[entry.key] = serial;
          final priorUse = entry.value.progress['rewardUse'];
          _useSeen[entry.key] = priorUse is Map && priorUse['serial'] is int
              ? priorUse['serial'] as int
              : 0;
          continue;
        }
        final armed = _armed[entry.key];
        final age = raw['activeAge'];
        if (match?.phase == 'active' &&
            raw['released'] == true &&
            armed?.serial == serial &&
            age is num &&
            age >= 0 &&
            age < .24 &&
            entry.value.health > 0) {
          releasing[entry.key] = armed!;
          _releaseAge[entry.key] = age.toDouble();
          _armed.remove(entry.key);
        }
        if (entry.value.health <= 0) {
          _armed.remove(entry.key);
          releasing.remove(entry.key);
          _releaseAge.remove(entry.key);
        }
        final use = entry.value.progress['rewardUse'];
        if (match?.phase == 'active' &&
            entry.value.health > 0 &&
            use is Map &&
            use['age'] is num &&
            (use['age'] as num) >= 0 &&
            (use['age'] as num) <= 1.2 &&
            use['label'] is String &&
            (use['label'] as String).length <= 48 &&
            use['serial'] is int &&
            use['acceptedSerial'] is int &&
            (use['serial'] as int) > (_useSeen[entry.key] ?? 0) &&
            (use['acceptedSerial'] as int) <= (_seen[entry.key] ?? 0)) {
          _useSeen[entry.key] = use['serial'] as int;
          useLabels[entry.key] = use['label'] as String;
          _useAge[entry.key] = 0;
        }
        if (match?.phase != 'confirmation' ||
            raw['holdSerial'] != match?.data['confirmationSerial'] ||
            serial <= (_seen[entry.key] ?? 0)) {
          continue;
        }
        final receipt = AcceptedUpgrade.read({
          for (final k in [
            'schema',
            'actor',
            'serial',
            'offerId',
            'source',
            'id',
            'beforeRank',
            'afterRank',
            'balance',
            'before',
            'after',
          ])
            k: raw[k],
          'generation': int.tryParse('${raw['generation']}'),
        });
        _seen[entry.key] = serial;
        if (receipt != null) {
          active[entry.key] = receipt;
          _armed[entry.key] = receipt;
          releasing.remove(entry.key);
          _releaseAge.remove(entry.key);
        }
      } on FormatException {
        /* A missing cosmetic event never blocks simulation. */
      }
    }
    if (match?.phase != 'confirmation') active.clear();
  }
}
