import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/theme/pixel_glyph.dart';

extension UpgradeGlyph on PowerUp {
  PixelGlyph get glyph => switch (this) {
    PowerUp.heavyLoad || PowerUp.executioner => PixelGlyph.crosshair,
    PowerUp.quickTrigger ||
    PowerUp.walkingSpeedIncrease ||
    PowerUp.rapidFire => PixelGlyph.dash,
    PowerUp.maxBulletsIncrease || PowerUp.lastShell => PixelGlyph.round,
    PowerUp.fastReload || PowerUp.breachLoader => PixelGlyph.reload,
    PowerUp.numberOfBulletsPerShotIncrease => PixelGlyph.scatter,
    PowerUp.bulletsPhaseThrough ||
    PowerUp.bulletRangeIncrease => PixelGlyph.play,
    PowerUp.healthIncrease => PixelGlyph.heart,
    PowerUp.fieldMedic => PixelGlyph.cross,
    PowerUp.scrapArmour || PowerUp.sprintInvincibility => PixelGlyph.shield,
    PowerUp.quickstep || PowerUp.sprintDistanceIncrease => PixelGlyph.dash,
    PowerUp.scavenger => PixelGlyph.magnet,
    PowerUp.luckyFind || PowerUp.salvage => PixelGlyph.star,
    PowerUp.hotShot || PowerUp.accelerant => PixelGlyph.fire,
    PowerUp.staticCharge || PowerUp.conductiveCore => PixelGlyph.bolt,
    PowerUp.sprintMine ||
    PowerUp.grenadeDamage ||
    PowerUp.grenadeRadius => PixelGlyph.mine,
    PowerUp.grenadeRecharge => PixelGlyph.reload,
    PowerUp.fragmentation || PowerUp.shrapnel => PixelGlyph.shards,
    PowerUp.ricochet || PowerUp.bankShot => PixelGlyph.bounce,
    PowerUp.orbitDrone => PixelGlyph.drone,
    PowerUp.targetingLink => PixelGlyph.link,
  };
}

PixelGlyph fusionGlyph(String id) => switch (id) {
  'firebreak' => PixelGlyph.fire,
  'stormCircuit' => PixelGlyph.bolt,
  'minefield' => PixelGlyph.mine,
  'pinball' => PixelGlyph.bounce,
  'breachEngine' => PixelGlyph.round,
  _ => PixelGlyph.drone,
};
