import 'package:regun/models/upgrade_animation_recipe.dart';

import 'dart:math' as math;

import 'package:regun/models/accepted_upgrade.dart';

/// Normal play uses full; baseline/short are internal comparison options.
enum UpgradeFeelMode { baseline, short, full }

/// Anticipate, receive, hold the absorption crest, contain, then settle.
/// Shared by native and authoritative-online renderers.
int upgradeInfusionFrame(double progress, [String family = 'heavyLoad']) {
  const ends = [.08, .23, .42, .62, .84, 1.0];
  final contained = const {
    'support:sentry',
    'ricochet',
  }.contains(upgradeAnimationRecipe(family));
  for (var i = 0; i < ends.length; i++) {
    if (progress < ends[i]) return contained && i == 5 ? 4 : i;
  }
  return contained ? 4 : 5;
}

int upgradeReleaseFrame(String family, double age) => age >= .12
    ? 7
    : const {
        'support:sentry',
        'ricochet',
      }.contains(upgradeAnimationRecipe(family))
    ? 5
    : 6;

/// Separate active-presentation clock: never advances the simulation while held.
/// No Timer, game-state mutation, art dependency or gameplay effect lives here.
class UpgradePresentationController {
  UpgradePresentationController({this.mode = UpgradeFeelMode.baseline});
  final UpgradeFeelMode mode;
  AcceptedUpgrade? receipt;
  double elapsed = 0, duration = 0, activeAge = 0;
  final _pending = <String, double>{};
  bool get firstUsePending => _pending.containsKey(receipt?.family);
  String? actualUse;
  double useAge = 0;
  int _generation = -1, _serial = 0;
  bool get holding => receipt != null && elapsed < duration;
  bool get visible => receipt != null && elapsed < duration + .7;
  double get progress => duration <= 0 ? 1 : (elapsed / duration).clamp(0, 1);
  int get frame => releaseAge >= 0
      ? upgradeReleaseFrame(receipt!.family, releaseAge)
      : upgradeInfusionFrame(progress, receipt?.family ?? 'heavyLoad');
  double releaseAge = -1;
  bool _releaseArmed = false;
  bool get releasing => releaseAge >= 0 && releaseAge < .24 && receipt != null;
  bool get showingBody => holding || releasing;

  /// Called only beside the existing, consumed-once recovery pulse.
  bool releaseImpact() {
    if (!_releaseArmed || holding || receipt == null) return false;
    _releaseArmed = false;
    releaseAge = 0;
    return true;
  }

  bool accept(
    AcceptedUpgrade value, {
    required bool reducedMotion,
    required bool rook,
  }) {
    if (value.generation < _generation ||
        (value.generation == _generation && value.serial <= _serial)) {
      return false;
    }
    if (_generation != value.generation) {
      _pending.clear();
      actualUse = null;
    }
    _generation = value.generation;
    _serial = value.serial;
    if (mode == UpgradeFeelMode.baseline) {
      cancel();
      return false;
    }
    if (!validUpgradeRewardId(value.id)) {
      receipt = null;
      duration = elapsed = 0;
      return false;
    }
    receipt = value;
    releaseAge = -1;
    _releaseArmed = true;
    elapsed = activeAge = 0;
    duration = reducedMotion
        ? .18
        : value.beforeRank > 0
        ? .8
        : mode == UpgradeFeelMode.short
        ? .75
        : 1.1;
    if (value.prototype) _pending[value.family] = 20;
    actualUse = null;
    return true;
  }

  void advanceHold(double dt) {
    if (!dt.isFinite || dt <= 0 || !holding) return;
    elapsed = math.min(duration, elapsed + dt);
  }

  void advanceActive(double dt) {
    if (!dt.isFinite || dt <= 0 || holding) return;
    elapsed += dt;
    if (releaseAge >= 0) releaseAge += dt;
    activeAge += dt;
    useAge += dt;
    for (final family in _pending.keys.toList()) {
      final remaining = _pending[family]! - dt;
      if (remaining <= 0) {
        _pending.remove(family);
      } else {
        _pending[family] = remaining;
      }
    }
    if (useAge >= .8) actualUse = null;
  }

  /// Call only from the accepted mechanic, never render, intent or RNG preview.
  bool observe(String family, String label) {
    if (holding || !_pending.containsKey(family)) return false;
    _pending.remove(family);
    actualUse = label;
    useAge = 0;
    return true;
  }

  /// A crash never replays the hold or a proc; retain only a static readout.
  void restoreStatic(AcceptedUpgrade? value) {
    cancel();
    if (value == null || mode == UpgradeFeelMode.baseline) return;
    receipt = value;
    elapsed = duration = 0;
  }

  void cancel() {
    receipt = null;
    _releaseArmed = false;
    releaseAge = -1;
    elapsed = duration = activeAge = 0;
    _pending.clear();
    actualUse = null;
  }
}

String upgradeReceiptDelta(AcceptedUpgrade r) {
  String f(num n) => n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  final a = r.before, b = r.after;
  switch (r.family) {
    case 'heavyLoad':
      return 'Primary damage ${f(a['Damage multiplier'] ?? 1)}× → ${f(b['Damage multiplier'] ?? 1)}×';
    case 'walkingSpeedIncrease':
      final before = a['Walking speed'] ?? 0, after = b['Walking speed'] ?? 0;
      return before <= 0
          ? 'Movement improved'
          : 'Move speed +${f((after / before - 1) * 100)}%';
    case 'scrapArmour':
      return r.beforeRank == 0
          ? 'Guard ready · absorbs one hit'
          : 'Guard recharge ${f(a['Guard recharge (s)']!)}s → ${f(b['Guard recharge (s)']!)}s';
    case 'hotShot':
      return 'Burn ${f((a['Burn per tick'] ?? 0) * 2)} → ${f((b['Burn per tick'] ?? 0) * 2)} damage/s';
    case 'ricochet':
      final k = b.containsKey('Total enemy ricochets')
          ? 'Total enemy ricochets'
          : 'Extra bounces';
      return 'Bounces ${f(a[k] ?? 0)} → ${f(b[k] ?? 0)}';
    case 'support:sentry':
      return '${f(b['Battery (s)']!)}s battery · deploys when clear';
    default:
      return '';
  }
}
