import 'dart:convert';

import 'identity_key.dart';

/// Read-only presentation contracts. Only server reducers change these values.
Map<String, dynamic> combatObject(String data) =>
    jsonDecode(data) as Map<String, dynamic>;
double combatNumber(
  Map<String, dynamic> data,
  String key, [
  double fallback = 0,
]) => data[key] is num && (data[key] as num).isFinite
    ? (data[key] as num).toDouble()
    : fallback;

class OnlineGun {
  OnlineGun(this.key, this.data, {this.enabled = true});
  final String key;
  final Map<String, dynamic> data;
  final bool enabled;
  String get weapon => data['weapon'] as String? ?? 'shotgun';
  String get survivor => data['survivor'] as String? ?? 'rook';
  double get health => combatNumber(data, 'health');
  double get maxHealth => combatNumber(data, 'maximumHealth', 6);
  int get ammo => combatNumber(data, 'ammo').toInt();
  int get baseCapacity => switch (weapon) {
    'carbine' => 24,
    'revolver' || 'arcCaster' => 6,
    _ => 5,
  };
  Map<String, dynamic> get progress =>
      data['progress'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get ranks =>
      data['ranks'] as Map<String, dynamic>? ?? {};
  int rank(String key) => (ranks[key] as num? ?? 0).toInt();
  int get capacity {
    final n = rank('maxBulletsIncrease');
    return baseCapacity +
        n.clamp(0, 3) * (weapon == 'carbine' ? 6 : 2) +
        (n - 3).clamp(0, 5) * (weapon == 'carbine' ? 2 : 1);
  }

  List<String> get offers => (progress['offers'] as List? ?? []).cast<String>();
  int get offerId => combatNumber(progress, 'offerId').toInt();
  double get cooldown => combatNumber(data, 'fireCooldown');
  double get reloadRemaining => combatNumber(data, 'reloadRemaining');
  double get reloadDuration => combatNumber(data, 'reloadDuration');
  double get reloadProgress => reloadDuration <= 0
      ? 0
      : (1 - reloadRemaining / reloadDuration).clamp(0, 1);
  bool get reloading => reloadRemaining > 0;
  int get shots => combatNumber(data, 'shots').toInt();
  int get damageSerial => combatNumber(data, 'damageSerial').toInt();
  int get reloadSerial => combatNumber(data, 'reloadSerial').toInt();
  int get kills => combatNumber(data, 'kills').toInt();
  int get deaths => combatNumber(data, 'deaths').toInt();
  double get damageTotal => combatNumber(data, 'damageTotal');
  double get lastDamage => combatNumber(data, 'lastDamage');
  double get shotX => combatNumber(data, 'shotX');
  double get shotY => combatNumber(data, 'shotY');
  double get shotAngle => combatNumber(data, 'shotAngle');
  double get protection => combatNumber(data, 'protection');
}

class OnlineMatch {
  OnlineMatch(this.data);
  final Map<String, dynamic> data;
  int get version => combatNumber(data, 'version').toInt();
  String get phase => data['phase'] as String? ?? 'waiting';
  double get seconds => combatNumber(data, 'seconds');
  double get phaseSeconds => combatNumber(data, 'phaseSeconds');
  int get round => combatNumber(data, 'round', 1).toInt();
  List<int> get wins =>
      (data['wins'] as List? ?? [0, 0]).map((v) => (v as num).toInt()).toList();
  int get winner => combatNumber(data, 'winner', -1).toInt();
  bool get overtime => data['overtime'] == true;
}

class OnlineRound {
  OnlineRound(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  double get x => combatNumber(data, 'x');
  double get y => combatNumber(data, 'y');
  double get dx => combatNumber(data, 'dx', 1);
  double get dy => combatNumber(data, 'dy');
  double get speed => combatNumber(data, 'speed');
  double get distance => combatNumber(data, 'distance');
  String get owner {
    final key = data['owner'] as String;
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key)
        ? identityKeyFromCanonical(key)
        : key;
  }

  String get weapon => data['weapon'] as String? ?? 'shotgun';
}

class OnlineEntity {
  OnlineEntity(this.id, this.kind, this.data);
  final String id, kind;
  final Map<String, dynamic> data;
  String get key => data['key'] as String? ?? id;
  double get x => combatNumber(data, 'x');
  double get y => combatNumber(data, 'y');
  double number(String key, [double fallback = 0]) =>
      combatNumber(data, key, fallback);
}
