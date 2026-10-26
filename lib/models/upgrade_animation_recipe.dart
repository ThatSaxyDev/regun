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
  // Match the physical performance, rather than routing unrelated perks through
  // Sentry's command gesture. Six clips remain shared; no new timing or leases.
  return switch (family) {
    'walkingSpeedIncrease' ||
    'quickstep' ||
    'dashCapacity' ||
    'sprintInvincibility' ||
    'sprintDistanceIncrease' ||
    'sureFoot' ||
    'braceLoader' ||
    'quickTrigger' ||
    'fastReload' ||
    'rapidFire' => 'walkingSpeedIncrease',
    'scrapArmour' || 'grenadeCapacity' || 'grenadeRecharge' => 'scrapArmour',
    // Cupped hands pull energy into the body: heat, electricity and restoration.
    // Colour follows the mechanic, so a medical/electric charge never looks fiery.
    'hotShot' ||
    'accelerant' ||
    'scouringHeat' ||
    'firebreak' ||
    'kilnPact' ||
    'staticCharge' ||
    'conductiveCore' ||
    'faradayReserve' ||
    'stormCircuit' ||
    'groundWire' ||
    'healthIncrease' ||
    'fieldMedic' ||
    'salvage' ||
    'support:aura' => 'hotShot',
    'ricochet' ||
    'bankShot' ||
    'pinball' ||
    'bulletsPhaseThrough' ||
    'bulletRangeIncrease' ||
    'executioner' ||
    'exposedSeam' ||
    'measuredShot' ||
    'targetingLink' => 'ricochet',
    // Palm command belongs to autonomous equipment and acquisition utilities.
    'support:sentry' ||
    'orbitDrone' ||
    'hunterSwarm' ||
    'sprintMine' ||
    'minefield' ||
    'scavenger' ||
    'luckyFind' => 'support:sentry',
    'heavyLoad' ||
    'maxBulletsIncrease' ||
    'numberOfBulletsPerShotIncrease' ||
    'lastShell' ||
    'breachLoader' ||
    'breachEngine' ||
    'fragmentation' ||
    'shrapnel' ||
    'grenadeDamage' ||
    'grenadeRadius' ||
    'blastHarness' ||
    'closeQuarters' => 'heavyLoad',
    _ => 'heavyLoad',
  };
}
