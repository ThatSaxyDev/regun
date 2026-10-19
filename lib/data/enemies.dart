enum EnemyKind {
  scorpion('Scorpion', 'Fans around your sides, then closes in.'),
  mummy('Mummy', 'Intercepts your route. Leave its reach before the strike.'),
  ranged('Revenant', 'Keeps its distance. Close in during its cast.'),
  runner('Skitter', 'Flanks, commits to a lunge, then recovers.'),
  shield(
      'Shield Warden', 'Front armor blocks shots. Strike during its recovery.'),
  burster('Burster', 'Cuts off your route. Escape its marked explosion.'),
  nest('Brood Nest', 'Break the nest before its brood grows.'),
  sentinel('Sentinel', 'Watch the marked ground, then move.');

  const EnemyKind(this.title, this.description);
  final String title, description;
}

enum BossKind {
  shadow('Shadow', 'Aimed fans, committed dashes, and close strikes.'),
  demon('Demon', 'Heavy cleaves, marked slams, and charge lanes.'),
  queen('Scorpion Queen', 'Tail strikes, brood, and lingering poison.');

  const BossKind(this.title, this.description);
  final String title, description;
}
