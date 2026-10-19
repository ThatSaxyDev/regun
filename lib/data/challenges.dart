class ChallengeDefinition {
  const ChallengeDefinition(this.id, this.title, this.requirement, this.reward);
  final String id, title, requirement, reward;
}

const challenges = [
  ChallengeDefinition(
      'training', 'First Steps', 'Complete training', 'Carbine'),
  ChallengeDefinition(
      'scrapper', 'Clean Sweep', 'Defeat 500 enemies', 'Scrapper'),
  ChallengeDefinition('warden', 'Hold the Line', 'Survive 8 minutes', 'Warden'),
  ChallengeDefinition(
      'revolver', 'Out of the Dark', 'Defeat Shadow', 'Revolver'),
  ChallengeDefinition(
      'arcCaster', 'Cool the Furnace', 'Defeat Demon', 'Arc Caster'),
  ChallengeDefinition(
      'foundry', 'First Cycle', 'Defeat Scorpion Queen', 'The Foundry'),
  ChallengeDefinition(
      'recipes', 'Fusion Made', 'Create a fusion', 'Recipe archive'),
  ChallengeDefinition(
      'queenTrophy', 'Royal Pardon', 'Defeat Scorpion Queen', 'Queen emblem'),
  ChallengeDefinition(
      'veteran', 'Still Standing', 'Survive 15 minutes', 'Veteran title'),
  ChallengeDefinition(
      'endless', 'Beyond the Breach', 'Survive 20 minutes', 'Endless trail'),
  ChallengeDefinition('scorpionCharm', 'Pest Control', 'Defeat 1,000 scorpions',
      'Scorpion charm'),
  ChallengeDefinition(
      'eliteHunter', 'Elite Hunter', 'Defeat 100 elites', 'Hunter emblem'),
  ChallengeDefinition('shadowPalette', 'Untouched Shadow',
      'Defeat Shadow without being hit', 'Shadow palette'),
  ChallengeDefinition('emberPalette', 'Untouched Flame',
      'Defeat Demon without being hit', 'Ember palette'),
  ChallengeDefinition('shotgunMaster', 'Pump Action',
      'Complete a cycle with Shotgun', 'Shotgun badge'),
  ChallengeDefinition('carbineMaster', 'Steady Hands',
      'Complete a cycle with Carbine', 'Carbine badge'),
  ChallengeDefinition('revolverMaster', 'Six Chambers',
      'Complete a cycle with Revolver', 'Revolver badge'),
  ChallengeDefinition('arcMaster', 'Live Wire',
      'Complete a cycle with Arc Caster', 'Arc badge'),
  ChallengeDefinition('engineer', 'Full Circuit', 'Discover all six fusions',
      'Engineer palette'),
  ChallengeDefinition('survivor', 'Everyone Out',
      'Complete a cycle with every character', 'Survivor emblem'),
];
