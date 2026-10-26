/// Stable accepted-reward identities and shared reaction recipes.
/// Every accepted reward gets a reaction; bespoke visuals can replace a recipe
/// without changing gameplay or the acceptance contract.
const upgradeRewardIds = <String>{
  'heavyLoad',
  'quickTrigger',
  'maxBulletsIncrease',
  'fastReload',
  'numberOfBulletsPerShotIncrease',
  'bulletsPhaseThrough',
  'bulletRangeIncrease',
  'rapidFire',
  'walkingSpeedIncrease',
  'healthIncrease',
  'fieldMedic',
  'scrapArmour',
  'quickstep',
  'dashCapacity',
  'grenadeCapacity',
  'sprintInvincibility',
  'scavenger',
  'luckyFind',
  'hotShot',
  'accelerant',
  'staticCharge',
  'conductiveCore',
  'sprintMine',
  'fragmentation',
  'ricochet',
  'bankShot',
  'lastShell',
  'breachLoader',
  'orbitDrone',
  'targetingLink',
  'shrapnel',
  'executioner',
  'grenadeDamage',
  'grenadeRadius',
  'grenadeRecharge',
  'braceLoader',
  'sureFoot',
  'scouringHeat',
  'faradayReserve',
  'blastHarness',
  'exposedSeam',
  'measuredShot',
  'closeQuarters',
  'sprintDistanceIncrease',
  'salvage',
  'kilnPact',
  'groundWire',
  'firebreak',
  'stormCircuit',
  'minefield',
  'pinball',
  'breachEngine',
  'hunterSwarm',
};

bool validUpgradeRewardId(String id) =>
    upgradeRewardIds.contains(id) ||
    RegExp(r'^support:sentry:[1-8]:(carbine|burstRifle)$').hasMatch(id) ||
    RegExp(r'^support:aura:[1-8]:field$').hasMatch(id);

String upgradeAnimationRecipe(String id) {
  final family = id.startsWith('support:')
      ? id.split(':').take(2).join(':')
      : id;
  return switch (family) {
    'walkingSpeedIncrease' ||
    'quickstep' ||
    'dashCapacity' ||
    'sprintInvincibility' ||
    'sprintDistanceIncrease' ||
    'sureFoot' ||
    'braceLoader' => 'walkingSpeedIncrease',
    'scrapArmour' ||
    'healthIncrease' ||
    'fieldMedic' ||
    'salvage' => 'scrapArmour',
    'hotShot' ||
    'accelerant' ||
    'scouringHeat' ||
    'firebreak' ||
    'kilnPact' => 'hotShot',
    'ricochet' ||
    'bankShot' ||
    'pinball' ||
    'bulletsPhaseThrough' ||
    'bulletRangeIncrease' ||
    'executioner' ||
    'exposedSeam' ||
    'measuredShot' ||
    'closeQuarters' => 'ricochet',
    'quickTrigger' ||
    'maxBulletsIncrease' ||
    'fastReload' ||
    'rapidFire' ||
    'grenadeRecharge' ||
    'lastShell' ||
    'breachLoader' ||
    'breachEngine' ||
    'support:sentry' ||
    'support:aura' ||
    'staticCharge' ||
    'conductiveCore' ||
    'faradayReserve' ||
    'orbitDrone' ||
    'targetingLink' ||
    'stormCircuit' ||
    'groundWire' ||
    'hunterSwarm' => 'support:sentry',
    _ => 'heavyLoad',
  };
}
