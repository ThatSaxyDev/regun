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
  return switch (weapon) {
    'revolver' => {
      ...common,
      'Direct damage': base('damage'),
      'Innate enemy ricochets': base('ricochets'),
      'Bounce damage retention': .7,
      'Bounce seek range': 500,
    },
    'houndrack' => {
      ...common,
      'Direct damage': base('damage'),
      'Distance damage multiplier': 1,
      'Launch speed': base('speed') * .3,
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
      'Maximum cutting radius': base('range') * .35,
      'Forward travel': base('range') * .65,
      'Outward damage per body': base('damage'),
      'Return damage per body':
          base('damage') * n('effects.ringcaster.ringReturnScale'),
      'Expansion (s)': n('effects.ringcaster.ringExpand'),
      'Maximum outer hold (s)': n('effects.ringcaster.ringHold'),
      'Retraction (s)': n('effects.ringcaster.ringRetract'),
      'Cutting thickness': n('effects.ringcaster.ringThickness'),
      'Targets per phase': n('effects.ringcaster.ringTargets'),
    },
    _ => throw ArgumentError.value(weapon, 'weapon'),
  };
}
