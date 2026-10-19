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
  queen('Scorpion Queen', 'Tail strikes, brood, and lingering poison.'),
  bellkeeper('The Bellkeeper',
      'Find the gap. Wait for the echo. Break the exposed clapper.'),
  magistrate('Chain Magistrate',
      'Read the chains. Break a clasp or leave the tightening line.'),
  saint('The Mirror Saint',
      'Change your route. Watch the broken shoulder. Break the glass.'),
  sovereign('Kiln Sovereign',
      'Read the vents. Break an exposed valve to open the core.'),
  marshal('The Last Marshal',
      'Punish the reload. Flank the brace. Watch the returning blade.');

  const BossKind(this.title, this.description);
  final String title, description;
  bool get expansion => index >= BossKind.bellkeeper.index;
  double get baseHealth => switch (this) {
        shadow => 140,
        demon => 230,
        queen => 300,
        bellkeeper => 260,
        magistrate => 280,
        saint => 250,
        sovereign => 340,
        marshal => 270,
      };
}
