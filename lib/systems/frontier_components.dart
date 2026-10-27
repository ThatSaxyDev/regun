import 'package:regun/data/weapon_behavior.dart';

/// Base components only: no survivor, upgrade, overkill or cover assumptions.
/// Shared with the admin; the gateway verifies the same projection in TypeScript.
Map<String, num> frontierComponents(String weapon, Map<String, num> values) {
  num n(String field) => values[field]!;
  num base(String field) => n('weapons.$weapon.$field');
  final common = <String, num>{
    'Release interval (s)': base('cadence'),
    'Magazine': base('capacity'),
    'Full reload (s)': base('reloadMs') / 1000,
    'Tactical reload (s)': base('reloadMs') * .7 / 1000,
    'Range': base('range'),
  };
  final projected = switch (weapon) {
    'revolver' => {
      ...common,
      'Direct damage': base('damage'),
      'Innate enemy ricochets': base('ricochets'),
      'Bounce damage retention':
          values['effects.revolver.bounceRetention'] ?? .7,
      'Bounce seek range': values['effects.revolver.bounceRange'] ?? 500,
    },
    'houndrack' => {
      ...common,
      'Direct damage': base('damage'),
      'Distance damage multiplier': 1,
      'Launch speed':
          base('speed') * (values['effects.houndrack.launchRatio'] ?? .3),
      'Maximum speed': base('speed'),
      'Secondary splash damage': n('effects.houndrack.rocketSplashDamage'),
      'Splash radius': n('effects.houndrack.rocketSplashRadius'),
      'Guidance (rad/s)': n('effects.houndrack.rocketTurnRate'),
      'Acquisition half-angle (deg)': n('effects.houndrack.rocketAcquireAngle'),
      'Motor acceleration (s)': n('effects.houndrack.rocketAcceleration'),
      'Live rockets': n('effects.houndrack.rocketLimit'),
    },
    'stormOrb' => {
      ...common,
      'Pre-fire delay (s)': n('effects.stormorb.orbWindup'),
      'Extra damage per crossed body': base('damage'),
      'Arc damage per tick': n('effects.stormorb.orbArcDamage'),
      'Arc interval (s)': n('effects.stormorb.orbTick'),
      'Arc radius': n('effects.stormorb.orbArcRadius'),
      'Targets per pulse': n('effects.stormorb.orbTargets'),
      'Live orbs': n('effects.stormorb.orbLimit'),
      'Maximum flight (s)': n('effects.stormorb.orbLifetime'),
    },
    'ringCaster' => {
      ...common,
      'Capture radius': n('effects.ringcaster.ringRadius'),
      'Starting radius': n('effects.ringcaster.ringStart'),
      'Forward travel':
          base('range') * (values['effects.ringcaster.deliveryShare'] ?? .65),
      'Collapse damage per captured body':
          base('damage') * n('effects.ringcaster.ringReturnScale'),
      'Expansion (s)': n('effects.ringcaster.ringExpand'),
      'Capture hold (s)': n('effects.ringcaster.ringHold'),
      'Contraction (s)': n('effects.ringcaster.ringRetract'),
      'Cutting thickness': n('effects.ringcaster.ringThickness'),
      'Capture body limit': 120,
    },
    _ => {...common, 'Direct damage': base('damage')},
  };
  final prefix = 'effects.${weapon.toLowerCase()}.';
  for (final entry in values.entries) {
    if (entry.key.startsWith(prefix) &&
        weaponBehaviorLabels.containsKey(entry.key)) {
      projected[weaponBehaviorLabels[entry.key]!] = entry.value;
    }
  }
  return projected;
}
