import 'package:flutter/material.dart';

enum WeaponType {
  shotgun(
    'Pump Shotgun',
    'Wide spread. Shell reload.',
    5,
    0.35,
    1.2,
    420,
    700,
    3200,
  ),
  carbine(
    'Carbine',
    'Sustained fire. Magazine swap.',
    24,
    0.1,
    0.762,
    650,
    950,
    1800,
  ),
  revolver(
    'Revolver',
    'Heavy rounds. Cylinder reload.',
    6,
    0.65,
    3,
    800,
    1150,
    2100,
  ),
  arcCaster(
    'Arc Caster',
    'Heavy bolts. Two chain jumps.',
    6,
    0.75,
    3,
    560,
    1050,
    2400,
  ),
  burstRifle(
    'Burst Rifle',
    'Three-round bursts. Hold to repeat.',
    18,
    .60,
    1.05,
    700,
    1100,
    2000,
  ),
  railLance(
    'Rail Lance',
    'Charge a piercing stake.',
    3,
    1.1,
    7,
    1000,
    1600,
    2600,
  ),
  rivetDriver(
    'Rivet Driver',
    'Plant charges. Reload for crowd blasts.',
    8,
    .26,
    .75,
    560,
    950,
    2200,
  ),
  cinderHose(
    'Cinder Hose',
    'Sweep nearby enemies with fire.',
    50,
    .10,
    .38,
    240,
    600,
    2300,
  ),
  reaperDisc(
    'Reaper Disc',
    'Cut on the way out and back.',
    3,
    .65,
    1.5,
    500,
    700,
    2400,
  ),
  scrapMortar(
    'Scrap Mortar',
    'Aim a delayed ground blast.',
    4,
    .95,
    4.5,
    620,
    600,
    2800,
  ),
  beltRepeater(
    'Belt-fed Repeater',
    'Spin up. Hold the firing lane.',
    100,
    .085,
    .70,
    620,
    1000,
    3600,
  ),
  frostShotgun(
    'Frost Shotgun',
    'Three ice pellets freeze enemies.',
    5,
    .80,
    2.2,
    360,
    800,
    2600,
  ),
  prismCutter(
    'Prism Cutter',
    'Cut a line. Watch the heat.',
    18,
    .10,
    .48,
    460,
    1000,
    1800,
  ),
  sporeLobber(
    'Spore Lobber',
    'Leave short-lived spore patches.',
    6,
    .70,
    .50,
    480,
    600,
    2700,
  ),
  longwatchSniper(
    'Longwatch Sniper',
    'Aim. Release to fire a piercing round.',
    5,
    1.10,
    12,
    1200,
    1900,
    2800,
  ),
  twinVerdict(
    'Twin Verdict',
    'Alternate barrels. Pair hits for extra damage.',
    12,
    .48,
    2.5,
    780,
    1450,
    2600,
  ),
  flakRegent(
    'Flak Regent',
    'Heavy shells split into four forward fragments.',
    16,
    .32,
    2.4,
    650,
    1050,
    3000,
  ),
  anchorEngine(
    'Anchor Engine',
    'Aim a magnetic trap. Gather, then crush.',
    4,
    1.1,
    8,
    600,
    600,
    3400,
  ),
  faultlineDriver(
    'Faultline Driver',
    'Aim, release. Fracture a piercing ground lane.',
    5,
    1.15,
    6,
    720,
    1000,
    3200,
  ),
  cycloneBreacher(
    'Cyclone Breacher',
    'Five heavy pellets. Rapid close-range volleys.',
    8,
    .50,
    1.2,
    300,
    850,
    3000,
  ),
  mourningBell(
    'Mourning Bell',
    'Strike a cone. Lingering enemies take an echo.',
    6,
    1.0,
    4.5,
    400,
    1000,
    3000,
  );

  const WeaponType(
    this.title,
    this.description,
    this.capacity,
    this.cadence,
    this.damage,
    this.range,
    this.speed,
    this.reloadMs,
  );
  final String title, description;
  final int capacity, range, reloadMs;
  final double cadence, damage, speed;

  bool get supportsTacticalReload => true;

  // Expansion weapons stay out of older hosted rooms until negotiated support.
  bool get availableOnline => index < 4;
  bool get usesArsenalRuntime => index >= 5;
  bool get hasLeasedArt => index >= 4;
  String get atlasName =>
      'weapons/${switch (this) {
        WeaponType.burstRifle => 'burst_rifle',
        WeaponType.railLance => 'rail_lance',
        WeaponType.rivetDriver => 'rivet_driver',
        WeaponType.cinderHose => 'cinder_hose',
        WeaponType.reaperDisc => 'reaper_disc',
        WeaponType.scrapMortar => 'scrap_mortar',
        WeaponType.beltRepeater => 'belt_repeater',
        WeaponType.frostShotgun => 'frost_shotgun',
        WeaponType.prismCutter => 'prism_cutter',
        WeaponType.sporeLobber => 'spore_lobber',
        WeaponType.longwatchSniper => 'longwatch_sniper',
        WeaponType.twinVerdict => 'twin_verdict',
        WeaponType.flakRegent => 'flak_regent',
        WeaponType.anchorEngine => 'anchor_engine',
        WeaponType.faultlineDriver => 'faultline_driver',
        WeaponType.cycloneBreacher => 'cyclone_breacher',
        WeaponType.mourningBell => 'mourning_bell',
        _ => 'arsenal',
      }}';
  int get victoryRequirement => switch (this) {
    WeaponType.burstRifle => 3,
    WeaponType.beltRepeater => 5,
    WeaponType.railLance => 7,
    WeaponType.frostShotgun => 9,
    WeaponType.rivetDriver => 12,
    WeaponType.cinderHose => 15,
    WeaponType.reaperDisc => 18,
    WeaponType.prismCutter => 21,
    WeaponType.sporeLobber => 24,
    WeaponType.scrapMortar => 27,
    WeaponType.longwatchSniper => 30,
    WeaponType.twinVerdict => 33,
    WeaponType.flakRegent => 36,
    WeaponType.anchorEngine => 40,
    WeaponType.faultlineDriver => 44,
    WeaponType.cycloneBreacher => 48,
    WeaponType.mourningBell => 52,
    _ => 0,
  };
  bool get supportsScatter =>
      index < 5 ||
      {
        WeaponType.railLance,
        WeaponType.rivetDriver,
        WeaponType.beltRepeater,
        WeaponType.frostShotgun,
        WeaponType.twinVerdict,
        WeaponType.cycloneBreacher,
      }.contains(this);
  bool get supportsPierce =>
      supportsScatter ||
      this == WeaponType.reaperDisc ||
      this == WeaponType.longwatchSniper;
  bool get supportsRicochet =>
      index < 5 ||
      {
        WeaponType.railLance,
        WeaponType.rivetDriver,
        WeaponType.beltRepeater,
        WeaponType.twinVerdict,
        WeaponType.cycloneBreacher,
      }.contains(this);
  bool get supportsVelocity =>
      supportsScatter ||
      {WeaponType.reaperDisc, WeaponType.sporeLobber}.contains(this);
  bool get isContinuous =>
      this == WeaponType.cinderHose || this == WeaponType.prismCutter;
  bool get hasDirectHits =>
      this != WeaponType.scrapMortar && this != WeaponType.anchorEngine;
  bool get hasLastRound => this != WeaponType.prismCutter;
  bool get supportsRange => true;
  bool get firesOnRelease =>
      this == WeaponType.longwatchSniper ||
      this == WeaponType.scrapMortar ||
      this == WeaponType.sporeLobber ||
      this == WeaponType.anchorEngine ||
      this == WeaponType.faultlineDriver;
}

/// Shell cadence shared by the reload clock and visible shotgun mechanism.
class ShotgunReload {
  static const firstShellMs = 800;
  static const shellIntervalMs = 600;
  static int durationFor(int missingShells) => missingShells <= 0
      ? 0
      : firstShellMs + shellIntervalMs * (missingShells - 1);
}

enum CharacterType {
  rook('Rook', 'Balanced and dependable.', 6, 300, 1, Color(0xffDF795F)),
  scrapper(
    'Scrapper',
    '+15% speed. Wider pickups. Stronger mines. −15% direct damage.',
    6,
    345,
    0.85,
    Color(0xffB8BE83),
  ),
  warden(
    'Warden',
    'Two extra hearts and a recharging guard. −13% speed.',
    8,
    261,
    1,
    Color(0xff8EA9C2),
  );

  const CharacterType(
    this.title,
    this.description,
    this.health,
    this.speed,
    this.damage,
    this.color,
  );
  final String title, description;
  final int health;
  final double speed, damage;
  final Color color;
}

enum ArenaType {
  breach('The Breach', 'Open dungeon. Space to learn the horde.'),
  foundry('The Foundry', 'Vents, choke points, and shifting pressure.');

  const ArenaType(this.title, this.description);
  final String title, description;
}

class Loadout {
  const Loadout({
    this.weapon = WeaponType.shotgun,
    this.character = CharacterType.rook,
    this.arena = ArenaType.breach,
    this.training = false,
  });
  final WeaponType weapon;
  final CharacterType character;
  final ArenaType arena;
  final bool training;
  Map<String, dynamic> toJson() => {
    'weapon': weapon.name,
    'character': character.name,
    'arena': arena.name,
    'training': training,
  };
  factory Loadout.fromJson(Map<String, dynamic> map) => Loadout(
    weapon: WeaponType.values.byName(
      map['weapon'] == 'breachHammer'
          ? 'longwatchSniper'
          : map['weapon'] as String,
    ),
    character: CharacterType.values.byName(map['character'] as String),
    arena: ArenaType.values.byName(map['arena'] as String),
    training: map['training'] == true,
  );
}
