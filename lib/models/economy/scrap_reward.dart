import 'package:regun/utils/format_number.dart';

/// Earned Solo economy v1. Independent of payment, shop prices and combat RNG.
class ScrapReward {
  const ScrapReward({
    required this.salvage,
    required this.kills,
    required this.bosses,
    required this.survival,
  });
  factory ScrapReward.run({
    required int salvage,
    required int kills,
    required int bosses,
    required int seconds,
    bool training = false,
  }) => training
      ? const ScrapReward(salvage: 0, kills: 0, bosses: 0, survival: 0)
      : ScrapReward(
          salvage: salvage.clamp(0, 1000000000),
          kills: kills.clamp(0, 1000000000) ~/ 10,
          bosses: bosses.clamp(0, 1000000) * 15,
          survival: seconds.clamp(0, 1000000000) ~/ 60,
        );
  final int salvage, kills, bosses, survival;
  int get total => salvage + kills + bosses + survival;
  String get breakdown =>
      'Salvage ${formatNumber(salvage)} / Kills ${formatNumber(kills)} / Bosses ${formatNumber(bosses)} / Survival ${formatNumber(survival)}';
}
