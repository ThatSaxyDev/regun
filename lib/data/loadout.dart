import 'package:flutter/material.dart';

enum WeaponType {
  shotgun(
      'Pump Shotgun', 'Wide spread. Shell reload.', 5, 0.35, 1, 420, 700, 3700),
  carbine('Carbine', 'Sustained fire. Magazine swap.', 24, 0.1, 0.762, 650, 950,
      1800),
  revolver('Revolver', 'Heavy rounds. Cylinder reload.', 6, 0.65, 3, 800, 1150,
      2100),
  arcCaster('Arc Caster', 'Chain lightning. Energy recharge.', 4, 0.9, 2, 480,
      650, 2400);

  const WeaponType(this.title, this.description, this.capacity, this.cadence,
      this.damage, this.range, this.speed, this.reloadMs);
  final String title, description;
  final int capacity, range, reloadMs;
  final double cadence, damage, speed;
}

enum CharacterType {
  rook('Rook', 'Balanced and dependable.', 6, 300, 1, Color(0xffDF795F)),
  scrapper(
      'Scrapper',
      'Wider pickup reach. Stronger mines. −15% direct damage.',
      6,
      300,
      0.85,
      Color(0xffB8BE83)),
  warden('Warden', 'Two extra hearts and a recharging guard. Slower movement.',
      8, 270, 1, Color(0xff8EA9C2));

  const CharacterType(this.title, this.description, this.health, this.speed,
      this.damage, this.color);
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
  const Loadout(
      {this.weapon = WeaponType.shotgun,
      this.character = CharacterType.rook,
      this.arena = ArenaType.breach,
      this.training = false});
  final WeaponType weapon;
  final CharacterType character;
  final ArenaType arena;
  final bool training;
  Map<String, dynamic> toJson() => {
        'weapon': weapon.name,
        'character': character.name,
        'arena': arena.name,
        'training': training
      };
  factory Loadout.fromJson(Map<String, dynamic> map) => Loadout(
      weapon: WeaponType.values.byName(map['weapon'] as String),
      character: CharacterType.values.byName(map['character'] as String),
      arena: ArenaType.values.byName(map['arena'] as String),
      training: map['training'] == true);
}
