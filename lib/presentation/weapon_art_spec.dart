import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/loadout.dart';

/// Explicit frame references: enum order must never address moving-part rows.
class WeaponArtSpec {
  const WeaponArtSpec(
    this.atlas,
    this.body,
    this.mechanism,
    this.width,
    this.height,
    this.grip, {
    this.bolt,
    this.muzzleHeight = .55,
    this.feedSocket,
    this.feedWidth,
    this.boltSocket,
    this.boltWidth,
  });
  final Offset? feedSocket, boltSocket;
  final double? feedWidth, boltWidth;
  final String atlas;
  final int body, mechanism;
  final int? bolt;
  final double width, height, grip, muzzleHeight;
  Offset get gripSocket => Offset(width * grip, height * .55);
  Offset get muzzleSocket => Offset(width, height * muzzleHeight);
  double get muzzle => muzzleSocket.dx - gripSocket.dx;

  static WeaponArtSpec of(WeaponType type) => switch (type) {
    WeaponType.houndrack => const WeaponArtSpec(
      'weapons/houndrack',
      0,
      1,
      68,
      22.6956,
      .30,
      bolt: 2,
      muzzleHeight: 0.44,
      feedSocket: Offset(22, -1),
      feedWidth: 13,
      boltSocket: Offset(18, -4.5),
      boltWidth: 11,
    ),
    WeaponType.stormOrb => const WeaponArtSpec(
      'weapons/storm_orb',
      0,
      1,
      65,
      21.1009,
      .30,
      bolt: 2,
      muzzleHeight: 0.45,
      feedSocket: Offset(23, 2.7),
      feedWidth: 9,
      boltSocket: Offset(36, -3.5),
      boltWidth: 13,
    ),
    WeaponType.ringCaster => const WeaponArtSpec(
      'weapons/ring_caster',
      0,
      1,
      62,
      22.483,
      .30,
      bolt: 2,
      muzzleHeight: 0.48,
      feedSocket: Offset(20, -3.5),
      feedWidth: 10.5,
      boltSocket: Offset(36.5, -3.4),
      boltWidth: 10.5,
    ),
    WeaponType.shotgun => const WeaponArtSpec(
      'weapons/arsenal',
      0,
      4,
      64,
      22,
      .44,
    ),
    WeaponType.carbine => const WeaponArtSpec(
      'weapons/arsenal',
      1,
      5,
      57,
      26,
      .45,
    ),
    WeaponType.revolver => const WeaponArtSpec(
      'weapons/arsenal',
      2,
      6,
      44,
      26,
      .23,
    ),
    WeaponType.arcCaster => const WeaponArtSpec(
      'weapons/arsenal',
      3,
      7,
      54,
      26,
      .23,
    ),
    WeaponType.burstRifle => const WeaponArtSpec(
      'weapons/burst_rifle',
      0,
      1,
      62,
      20,
      .43,
      bolt: 2,
      muzzleHeight: .347,
    ),
    WeaponType.railLance => const WeaponArtSpec(
      'weapons/rail_lance',
      0,
      1,
      78,
      18.01,
      0.43,
      bolt: 2,
      muzzleHeight: 0.44,
    ),
    WeaponType.rivetDriver => const WeaponArtSpec(
      'weapons/rivet_driver',
      0,
      1,
      52,
      21.55,
      0.44,
      bolt: 2,
      muzzleHeight: 0.33,
    ),
    WeaponType.cinderHose => const WeaponArtSpec(
      'weapons/cinder_hose',
      0,
      1,
      58,
      16.2,
      0.43,
      bolt: 2,
      muzzleHeight: 0.4,
    ),
    WeaponType.reaperDisc => const WeaponArtSpec(
      'weapons/reaper_disc',
      0,
      1,
      59,
      22.51,
      0.43,
      bolt: 2,
      muzzleHeight: 0.4,
    ),
    WeaponType.scrapMortar => const WeaponArtSpec(
      'weapons/scrap_mortar',
      0,
      1,
      54,
      21.32,
      0.43,
      bolt: 2,
      muzzleHeight: .34,
    ),
    WeaponType.beltRepeater => const WeaponArtSpec(
      'weapons/belt_repeater',
      0,
      1,
      70,
      30.96,
      0.43,
      bolt: 2,
      muzzleHeight: .34,
    ),
    WeaponType.frostShotgun => const WeaponArtSpec(
      'weapons/frost_shotgun',
      0,
      1,
      65,
      16.62,
      0.44,
      bolt: 2,
      muzzleHeight: 0.3,
    ),
    WeaponType.prismCutter => const WeaponArtSpec(
      'weapons/prism_cutter',
      0,
      1,
      58,
      23.36,
      0.43,
      bolt: 2,
      muzzleHeight: 0.38,
    ),
    WeaponType.sporeLobber => const WeaponArtSpec(
      'weapons/spore_lobber',
      0,
      1,
      55,
      14.79,
      0.43,
      bolt: 2,
      muzzleHeight: 0.4,
    ),
    WeaponType.longwatchSniper => const WeaponArtSpec(
      'weapons/longwatch_sniper',
      0,
      1,
      86,
      17,
      .34,
      bolt: 2,
      muzzleHeight: .40,
    ),
    WeaponType.twinVerdict => const WeaponArtSpec(
      'weapons/twin_verdict',
      0,
      1,
      50,
      19.69,
      0.29,
      bolt: 2,
      muzzleHeight: 0.344,
    ),
    WeaponType.flakRegent => const WeaponArtSpec(
      'weapons/flak_regent',
      0,
      1,
      68,
      26.86,
      0.285,
      bolt: 2,
      muzzleHeight: 0.337,
    ),
    WeaponType.anchorEngine => const WeaponArtSpec(
      'weapons/anchor_engine',
      0,
      1,
      66,
      25.41,
      0.27,
      bolt: 2,
      muzzleHeight: 0.335,
    ),
    WeaponType.faultlineDriver => const WeaponArtSpec(
      'weapons/faultline_driver',
      0,
      1,
      80,
      23.93,
      0.22,
      bolt: 2,
      muzzleHeight: 0.375,
    ),
    WeaponType.cycloneBreacher => const WeaponArtSpec(
      'weapons/cyclone_breacher',
      0,
      1,
      66,
      20.97,
      0.324,
      bolt: 2,
      muzzleHeight: 0.342,
    ),
    WeaponType.mourningBell => const WeaponArtSpec(
      'weapons/mourning_bell',
      0,
      1,
      65,
      21.57,
      0.36,
      bolt: 2,
      muzzleHeight: 0.385,
    ),
  };

  /// The actor's hand mount is 8 units toward aim and 6 units below its origin.
  /// World projectile creation and local/remote presentation share this socket.
  Offset releaseOffset(Offset direction) {
    if (direction.distanceSquared < 1e-12) return const Offset(0, 6);
    final unit = direction / math.sqrt(direction.distanceSquared);
    final side = Offset(-unit.dy, unit.dx) * (unit.dx < 0 ? -1 : 1);
    return const Offset(0, 6) +
        unit * (8 + muzzle) +
        side * (muzzleSocket.dy - gripSocket.dy);
  }
}
