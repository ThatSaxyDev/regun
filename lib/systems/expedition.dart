import 'package:regun/systems/expedition_signature.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/support_rewards.dart';

import 'dart:ui';

import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/services/expedition_release.dart';

enum ExpeditionVeteran { miniWalker, miniDemon, miniAriet }

enum ExpeditionPhase { combat, reward, exit, victory, defeat }

enum ExpeditionBoon {
  arsenal('WEAPON', 0xffdbad69, [
    PowerUp.heavyLoad,
    PowerUp.fastReload,
    PowerUp.lastShell,
    PowerUp.breachLoader,
    PowerUp.quickTrigger,
    PowerUp.maxBulletsIncrease,
  ]),
  ordnance('ORDNANCE', 0xffe0936d, [
    PowerUp.sprintMine,
    PowerUp.fragmentation,
    PowerUp.grenadeDamage,
    PowerUp.grenadeRadius,
    PowerUp.grenadeRecharge,
    PowerUp.grenadeCapacity,
  ]),
  ember('EMBER', 0xffe88677, [
    PowerUp.hotShot,
    PowerUp.accelerant,
    PowerUp.scouringHeat,
    PowerUp.shrapnel,
  ]),
  storm('STORM', 0xff91cbd6, [
    PowerUp.staticCharge,
    PowerUp.conductiveCore,
    PowerUp.faradayReserve,
    PowerUp.ricochet,
  ]),
  mobility('MOBILITY', 0xffb2a0d4, [
    PowerUp.walkingSpeedIncrease,
    PowerUp.quickstep,
    PowerUp.dashCapacity,
    PowerUp.sprintInvincibility,
    PowerUp.braceLoader,
  ]),
  repair('REPAIR', 0xffa5c9a0, [PowerUp.salvage]),
  guard('GUARD', 0xffabc797, [
    PowerUp.healthIncrease,
    PowerUp.scrapArmour,
    PowerUp.fieldMedic,
    PowerUp.walkingSpeedIncrease,
    PowerUp.quickstep,
    PowerUp.dashCapacity,
  ]),
  frost('FROST', 0xffa6d8dc, [
    PowerUp.exposedSeam,
    PowerUp.bulletsPhaseThrough,
    PowerUp.bulletRangeIncrease,
  ]),
  impact('IMPACT', 0xffd4b58a, [
    PowerUp.closeQuarters,
    PowerUp.blastHarness,
    PowerUp.numberOfBulletsPerShotIncrease,
  ]),
  precision('PRECISION', 0xffe4c081, [
    PowerUp.bulletRangeIncrease,
    PowerUp.rapidFire,
    PowerUp.executioner,
  ]),
  screen('SCREEN', 0xff9accc2, [PowerUp.fastReload, PowerUp.scrapArmour]),
  thermite('THERMITE', 0xffe0936d, [
    PowerUp.grenadeRadius,
    PowerUp.scouringHeat,
  ]),
  retaliation('RETALIATION', 0xffd7aa7b, [
    PowerUp.healthIncrease,
    PowerUp.scrapArmour,
  ]),
  quickdraw('QUICKDRAW', 0xffc9aed4, [PowerUp.quickstep, PowerUp.quickTrigger]);

  const ExpeditionBoon(this.label, this.color, this.pool);
  final String label;
  final int color;
  final List<PowerUp> pool;
  ExpeditionSignature? get signature => switch (this) {
    arsenal => ExpeditionSignature.breachCharge,
    ember => ExpeditionSignature.flashpoint,
    storm || mobility => ExpeditionSignature.thunderstep,
    frost => ExpeditionSignature.coldSnap,
    impact => ExpeditionSignature.shatterstep,
    ordnance => ExpeditionSignature.fuseLink,
    guard => ExpeditionSignature.bloodTax,
    precision => ExpeditionSignature.deadeye,
    screen => ExpeditionSignature.ironCurtain,
    thermite => ExpeditionSignature.thermite,
    retaliation => ExpeditionSignature.backlash,
    quickdraw => ExpeditionSignature.quickdraw,
    repair => null,
  };
}

enum ExpeditionRegion {
  breach(ArenaType.breach, BossKind.walker, 5, 5),
  foundry(ArenaType.foundry, BossKind.sovereign, 5, 6),
  floodworks(ArenaType.floodworks, BossKind.marshal, 6, 7),
  relay(ArenaType.relayGraveyard, BossKind.lodestar, 5, 7);

  const ExpeditionRegion(this.arena, this.boss, this.minimum, this.maximum);
  final ArenaType arena;
  final BossKind boss;
  final int minimum, maximum;
}

/// The seed and generator revision pin rooms, enemy mixes and route rewards.
class Expedition {
  Expedition(
    this.seed, {
    this.generator = version,
    this.threat = 0,
    this.release = ExpeditionRelease.bundled,
  });
  static const version = 11;
  final signatures = <ExpeditionSignature, int>{};
  List<ExpeditionSignature> signatureDraft = const [];
  bool breachChargeReady = false;
  bool coldSnapReady = false;
  int signatureHits = 0, signatureKills = 0;
  int synergy = 0;
  bool quickdrawReady = false;
  final fusions = <ExpeditionFusion>{};
  Iterable<ExpeditionFusion> get forgeChoices =>
      generator < 10 ||
          !bossRoom ||
          phase != ExpeditionPhase.reward ||
          fusions.length >= 2
      ? const []
      : ExpeditionFusion.values
            .where(
              (fusion) => !fusions.contains(fusion) && fusion.ready(signatures),
            )
            .take(2);

  List<ExpeditionSignature> get openingSignatures {
    if (generator < 9) return ExpeditionSignature.legacy;
    final cards =
        (generator < 10
                ? ExpeditionSignature.firstPass
                : ExpeditionSignature.values)
            .toList()
          ..shuffle(random(21));
    return cards.take(3).toList();
  }

  bool get hasSynergy => synergy > 0;
  bool get offersSynergy =>
      canForgeSynergy && bossRoom && phase == ExpeditionPhase.reward;
  ExpeditionSignature? get rewardSignature {
    final card = reward.signature;
    if (generator < 9 && !ExpeditionSignature.legacy.contains(card)) {
      return null;
    }
    return card;
  }

  bool get canForgeSynergy =>
      generator == 9 &&
      synergy == 0 &&
      signatures.values.where((rank) => rank >= 2).length >= 2;

  double flashpointCooldown = 0;
  final int seed, generator, threat;
  final ExpeditionRelease release;
  int room = 0, route = 0, spawned = 0;
  ExpeditionRegion region = ExpeditionRegion.breach;
  double clock = 0;
  double hazardClock = 0;
  int bossAdds = 0;
  bool dropStarted = false;
  int dropGuards = 0;
  String? dropSpecial;
  List<PowerUp> dropBoons = const [];

  bool get supplyRoom =>
      generator >= 8 &&
      !bossRoom &&
      room ==
          1 +
              RunRandom(seed ^ (region.index * 16381) ^ 0x5dc1)
                  .nextInt(roomCount - 2);
  ExpeditionPhase phase = ExpeditionPhase.combat;
  ExpeditionBoon reward = ExpeditionBoon.arsenal;
  List<PowerUp> draft = const [];
  List<String> capstones = const [];
  List<ExpeditionBoon> exits = const [];
  int? next;

  int get roomCount {
    final roll = RunRandom(seed ^ (region.index * 14551) ^ 7349);
    if (generator < 6) {
      return region.minimum + roll.nextInt(region.maximum - region.minimum + 1);
    }
    return switch (roll.nextInt(10)) {
      < 3 => 5,
      < 6 => 6,
      < 9 => 7,
      _ => 8,
    };
  }

  bool get opening => region == ExpeditionRegion.breach && room == 0;
  BossKind get boss => generator < 4
      ? region.boss
      : switch (region) {
          ExpeditionRegion.breach => BossKind.walker,
          ExpeditionRegion.foundry => BossKind.demon,
          ExpeditionRegion.floodworks => BossKind.ariet,
          ExpeditionRegion.relay => BossKind.lodestar,
        };
  double get bossHealth =>
      boss.baseHealth *
      (generator < 4
          ? 1
          : switch (boss) {
              BossKind.walker => 1.32,
              BossKind.demon => 1.28,
              BossKind.ariet => 1.45,
              _ => 1.25,
            });
  bool get trapped =>
      generator >= 4 &&
      !bossRoom &&
      (generator >= 5 && region == ExpeditionRegion.breach
          ? room >= 3
          : room > 0) &&
      (room + region.index + seed % 3).isEven;
  bool get bossRoom => room == roomCount;
  bool get finalRegion => region == ExpeditionRegion.relay;
  bool get terminal =>
      phase == ExpeditionPhase.victory || phase == ExpeditionPhase.defeat;

  RunRandom random(int stream) => RunRandom(
    seed ^
        (room * 7949) ^
        (route * 104729) ^
        (stream * 32719) ^
        (region.index * 31337),
  );

  void advanceRoom() {
    final door = next!;
    if (bossRoom) {
      region = ExpeditionRegion.values[region.index + 1];
      room = 0;
      reward = ExpeditionBoon.arsenal;
    } else {
      if (exits.isNotEmpty) reward = exits[door];
      room++;
    }
    route = ((route << 1) | door) & 0x3ffffff;
    phase = ExpeditionPhase.combat;
    spawned = 0;
    clock = 0;
    hazardClock = 0;
    bossAdds = 0;
    dropStarted = false;
    dropGuards = 0;
    dropSpecial = null;
    dropBoons = const [];
    draft = const [];
    capstones = const [];
    signatureDraft = const [];
    exits = const [];
    next = null;
  }

  double get enemyHealthScale => generator < 5
      ? 1
      : 1 +
            region.index * (generator >= 7 ? .46 : .26) +
            room * .025 +
            threat * .08;

  // The boss and the next region's first room share a boundary on the curve,
  // so a long region cannot make the following region feel slower.
  double get _combatDepth => region.index + room / roomCount;

  double get enemyPursuitScale =>
      generator < 7 ? 1 : 1.02 + _combatDepth * .175;

  // Mini Walkers already cover much more ground than the ordinary horde.
  double get miniWalkerPursuitScale =>
      generator < 7 ? 1 : 1 + _combatDepth * .01;

  int get bossReinforcements => generator < 7 ? 2 : random(9).nextInt(3);

  ExpeditionVeteran? get veteran {
    if (generator < 7 || bossRoom || region.index == 0) return null;
    var slot = 0;
    for (final (wave, size) in waveSizes.indexed) {
      if (spawned == slot + size - 1) {
        // Keep the previous boss's troops in the mix after the next handoff.
        final inherited = wave == 0 || wave.isOdd ? region.index - 1 : 0;
        return ExpeditionVeteran.values[inherited];
      }
      slot += size;
    }
    return null;
  }

  double get enemyImpactScale =>
      generator < 5 ? 1 : 1 - region.index * .09 - room * .015;

  int enemyDamage({bool heavy = false}) {
    if (generator < 5 || region == ExpeditionRegion.breach) return 1;
    if (heavy && (generator >= 7 || region.index >= 2 || room >= 3)) return 2;
    if (generator >= 7) return _combatDepth >= 2.8 ? 2 : 1;
    if (region == ExpeditionRegion.relay && room >= 2) return 2;
    return 1;
  }

  int get waveSize => (2 + region.index + room ~/ 2).clamp(2, 6);
  bool get briskOpening =>
      generator >= 11 && region == ExpeditionRegion.breach && room <= 1;

  int get waveLimit => briskOpening
      ? 3 + room
      : generator >= 7 && region.index > 0
      ? 7 + region.index
      : (waveSize + (opening ? 0 : 1)).clamp(2, 9);
  int get waveCarryover => briskOpening
      ? 1
      : generator >= 7 && region.index > 0
      ? 2 + region.index
      : region.index < 2
      ? 0
      : 1;

  int get _enemyBudget =>
      5 +
      room +
      region.index * 3 +
      threat * 2 +
      release.pressure +
      (generator >= 7 ? region.index * 4 + (room >= 2 ? 3 + room ~/ 2 : 0) : 0);

  List<int> get waveSizes {
    if (bossRoom) return const [];
    final count = 3 + random(7).nextInt(3);
    final minimum =
        count *
        (briskOpening
            ? 3
            : generator >= 7 && region.index > 0
            ? 4
            : generator >= 11
            ? 3
            : 2);
    final budget = _enemyBudget < minimum ? minimum : _enemyBudget;
    return [
      for (var wave = 0; wave < count; wave++)
        budget ~/ count + (wave >= count - budget % count ? 1 : 0),
    ];
  }

  bool get startsWave {
    if (spawned == 0) return true;
    if (generator < 6) return spawned % waveSize == 0;
    var boundary = 0;
    for (final size in waveSizes) {
      boundary += size;
      if (spawned <= boundary) return spawned == boundary;
    }
    return false;
  }

  double get spawnInterval {
    if (briskOpening) {
      if (spawned == 0) return .55 - .1 * room;
      return startsWave ? 1.35 - .15 * room : .44 - .06 * room;
    }
    if (spawned == 0) {
      return opening
          ? 1.4
          : generator >= 7 && region.index > 0
          ? .65
          : .85;
    }
    if (generator >= 7 && region.index > 0) {
      return startsWave ? (1.35 - .15 * region.index) : .25;
    }
    if (generator >= 11 && region == ExpeditionRegion.breach) {
      return startsWave ? (1.30 - .09 * room) : (.43 - .027 * room);
    }
    if (startsWave) {
      return (2.1 - .3 * region.index - .13 * room).clamp(.65, 2.1);
    }
    return (.65 - .08 * region.index - .035 * room).clamp(.28, .65);
  }

  List<EnemyKind> _rampedPack() {
    final roll = random(1);
    final basics = switch (region) {
      ExpeditionRegion.breach => [
        EnemyKind.scorpion,
        EnemyKind.mummy,
        if (room >= 1) EnemyKind.ranged,
        if (room >= 2) EnemyKind.runner,
      ],
      ExpeditionRegion.foundry => [
        EnemyKind.mummy,
        EnemyKind.ranged,
        EnemyKind.runner,
      ],
      ExpeditionRegion.floodworks => [
        EnemyKind.ranged,
        EnemyKind.runner,
        EnemyKind.shield,
      ],
      ExpeditionRegion.relay => [
        EnemyKind.runner,
        EnemyKind.shield,
        EnemyKind.ranged,
      ],
    };
    final heavy = switch (region) {
      ExpeditionRegion.breach => [
        if (room >= 3) EnemyKind.shield,
        if (room >= 4) EnemyKind.burster,
      ],
      ExpeditionRegion.foundry => [
        EnemyKind.shield,
        EnemyKind.burster,
        if (room >= 2) EnemyKind.sentinel,
      ],
      ExpeditionRegion.floodworks => [
        EnemyKind.burster,
        EnemyKind.sentinel,
        if (room >= 2) EnemyKind.nest,
      ],
      ExpeditionRegion.relay => [
        EnemyKind.burster,
        EnemyKind.sentinel,
        EnemyKind.nest,
      ],
    };
    final waves = generator >= 6 ? waveSizes : const <int>[];
    final count = generator >= 6 ? waves.reduce((a, b) => a + b) : _enemyBudget;
    final firstGroup = generator >= 7 && region.index > 0
        ? basics.length
        : waves.firstOrNull ?? waveSize;
    final heavySpacing = region.index >= 2 ? 3 : 4;
    return [
      for (var i = 0; i < count; i++)
        if (i < basics.length)
          basics[i]
        else if (heavy.isNotEmpty &&
            i >= firstGroup &&
            (i - firstGroup) % heavySpacing == 0)
          heavy[((i - firstGroup) ~/ heavySpacing) % heavy.length]
        else
          basics[roll.nextInt(basics.length)],
    ];
  }

  List<EnemyKind> get pack {
    if (bossRoom) return const [];
    if (generator >= 5) return _rampedPack();
    final roll = random(1);
    if (generator == 1 && region == ExpeditionRegion.breach) {
      final mix = [
        EnemyKind.scorpion,
        EnemyKind.mummy,
        if (room >= 1 || generator >= 4) EnemyKind.ranged,
        if (room >= 2 || (generator >= 4 && room > 0)) EnemyKind.runner,
        if (room >= 3) EnemyKind.shield,
        if (room >= 4) EnemyKind.burster,
      ];
      return [
        for (var i = 0; i < 5 + 2 * room; i++)
          i < 2 ? mix[i] : mix[roll.nextInt(mix.length)],
      ];
    }
    final mix = switch (region) {
      ExpeditionRegion.breach => [
        EnemyKind.scorpion,
        EnemyKind.mummy,
        if (room >= 1 || generator >= 4) EnemyKind.ranged,
        if (room >= 2 || (generator >= 4 && room > 0)) EnemyKind.runner,
        if (room >= 3) EnemyKind.shield,
        if (room >= 4) EnemyKind.burster,
      ],
      ExpeditionRegion.foundry => [
        EnemyKind.shield,
        EnemyKind.burster,
        EnemyKind.mummy,
        if (room.isOdd) EnemyKind.ranged else EnemyKind.runner,
        if (room >= 2) EnemyKind.sentinel,
      ],
      ExpeditionRegion.floodworks => [
        EnemyKind.ranged,
        EnemyKind.runner,
        EnemyKind.scorpion,
        if (room.isOdd) EnemyKind.shield else EnemyKind.burster,
        if (room >= 2) EnemyKind.nest,
      ],
      ExpeditionRegion.relay => [
        EnemyKind.runner,
        EnemyKind.shield,
        EnemyKind.ranged,
        EnemyKind.burster,
        EnemyKind.sentinel,
        EnemyKind.mummy,
      ],
    };
    return [
      for (
        var i = 0;
        i <
            5 +
                2 * room +
                region.index * 2 +
                threat * 2 +
                release.pressure +
                (generator >= 4 ? 3 : 0);
        i++
      )
        i < (generator >= 4 ? mix.length : 2)
            ? mix[i]
            : mix[roll.nextInt(mix.length)],
    ];
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'generator': generator,
    'threat': threat,
    'release': release.toJson(),
    'region': region.name,
    'seed': seed,
    'room': room,
    'route': route,
    'spawned': spawned,
    'clock': clock,
    'hazardClock': hazardClock,
    'bossAdds': bossAdds,
    if (dropStarted) 'dropStarted': true,
    if (dropGuards > 0) 'dropGuards': dropGuards,
    if (dropSpecial != null) 'dropSpecial': dropSpecial,
    if (dropBoons.isNotEmpty)
      'dropBoons': dropBoons.map((p) => p.name).toList(),
    'phase': phase.name,
    'reward': reward.name,
    'draft': draft.map((p) => p.name).toList(),
    'capstones': capstones,
    'signatures': {
      for (final entry in signatures.entries) entry.key.name: entry.value,
    },
    'signatureDraft': signatureDraft.map((value) => value.name).toList(),
    'breachChargeReady': breachChargeReady,
    if (coldSnapReady) 'coldSnapReady': true,
    if (signatureHits > 0) 'signatureHits': signatureHits,
    if (signatureKills > 0) 'signatureKills': signatureKills,
    if (synergy > 0) 'synergy': synergy,
    if (quickdrawReady) 'quickdrawReady': true,
    if (fusions.isNotEmpty)
      'fusions': fusions.map((fusion) => fusion.name).toList(),
    'flashpointCooldown': flashpointCooldown,
    'exits': exits.map((p) => p.name).toList(),
    if (next != null) 'next': next,
  };

  factory Expedition.read(Object? raw) {
    if (raw is! Map ||
        ![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, version].contains(raw['version'])) {
      throw const FormatException('Unsupported Expedition save');
    }
    final value =
        Expedition(
            raw['seed'] as int,
            generator: (raw['generator'] ?? raw['version']) as int,
            threat: (raw['threat'] ?? 0) as int,
            release: raw['release'] == null
                ? ExpeditionRelease.bundled
                : ExpeditionRelease.read(raw['release']),
          )
          ..region = ExpeditionRegion.values.byName(
            raw['region'] as String? ?? 'breach',
          )
          ..room = raw['room'] as int
          ..route = raw['route'] as int
          ..spawned = raw['spawned'] as int
          ..clock = (raw['clock'] as num).toDouble()
          ..hazardClock = (raw['hazardClock'] as num?)?.toDouble() ?? 0
          ..bossAdds = raw['bossAdds'] as int? ?? 0
          ..dropStarted = raw['dropStarted'] == true
          ..dropGuards = raw['dropGuards'] as int? ?? 0
          ..dropSpecial = raw['dropSpecial'] as String?
          ..dropBoons = (raw['dropBoons'] as List? ?? [])
              .cast<String>()
              .map(PowerUp.values.byName)
              .toList()
          ..phase = ExpeditionPhase.values.byName(raw['phase'] as String)
          ..reward = ExpeditionBoon.values.byName(raw['reward'] as String)
          ..draft = (raw['draft'] as List)
              .cast<String>()
              .map(PowerUp.values.byName)
              .toList()
          ..capstones = (raw['capstones'] as List? ?? [])
              .cast<String>()
              .toList()
          ..exits = (raw['exits'] as List)
              .cast<String>()
              .map(ExpeditionBoon.values.byName)
              .toList()
          ..next = raw['next'] as int?
          ..signatureDraft = (raw['signatureDraft'] as List? ?? [])
              .cast<String>()
              .map(ExpeditionSignature.values.byName)
              .toList()
          ..breachChargeReady = raw['breachChargeReady'] == true
          ..coldSnapReady = raw['coldSnapReady'] == true
          ..signatureHits = raw['signatureHits'] as int? ?? 0
          ..signatureKills = raw['signatureKills'] as int? ?? 0
          ..synergy = raw['synergy'] as int? ?? 0
          ..quickdrawReady = raw['quickdrawReady'] == true
          ..flashpointCooldown =
              (raw['flashpointCooldown'] as num?)?.toDouble() ?? 0;
    final forged = (raw['fusions'] as List? ?? []).cast<String>();
    value.fusions.addAll(forged.map(ExpeditionFusion.values.byName));
    if (forged.length != value.fusions.length ||
        forged.length > 2 ||
        (forged.isNotEmpty && value.generator < 10)) {
      throw const FormatException('Invalid Expedition fusions');
    }
    for (final entry in (raw['signatures'] as Map? ?? {}).entries) {
      value.signatures[ExpeditionSignature.values.byName(entry.key as String)] =
          entry.value as int;
    }
    if (value.seed < 0 ||
        value.seed > 0x7fffffff ||
        value.room < 0 ||
        value.room > value.roomCount ||
        value.route < 0 ||
        value.route > 0x3ffffff ||
        ![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, version].contains(value.generator) ||
        value.threat < 0 ||
        value.threat > 2 ||
        !value.clock.isFinite ||
        value.clock < 0 ||
        !value.hazardClock.isFinite ||
        value.hazardClock < 0 ||
        value.hazardClock > 15 ||
        value.bossAdds < 0 ||
        value.bossAdds > 3 ||
        (value.dropStarted && !value.supplyRoom) ||
        value.dropGuards < 0 ||
        value.dropGuards > 3 ||
        (value.dropGuards > 0 && !value.dropStarted) ||
        value.dropBoons.length > 2 ||
        value.dropBoons.toSet().length != value.dropBoons.length ||
        (value.dropSpecial != null &&
            (!value.dropStarted ||
                value.phase != ExpeditionPhase.combat ||
                (value.dropSpecial != 'repair' &&
                    SupportCard.read(value.dropSpecial!) == null &&
                    !WeaponType.values.any(
                      (w) => value.dropSpecial == 'weapon:${w.name}',
                    )))) ||
        (value.dropSpecial == null && value.dropBoons.isNotEmpty) ||
        value.spawned < 0 ||
        value.spawned > (value.bossRoom ? 1 : value.pack.length) ||
        value.signatureHits < 0 ||
        value.signatureHits > 3 ||
        value.signatureKills < 0 ||
        value.signatureKills >= ExpeditionSignature.bloodTaxKills(1) ||
        value.synergy < 0 ||
        value.synergy > 1 ||
        value.fusions.any((fusion) => !fusion.ready(value.signatures)) ||
        (value.quickdrawReady &&
            (value.signatures[ExpeditionSignature.quickdraw] ?? 0) == 0) ||
        value.signatureDraft.length > 3 ||
        value.signatureDraft.toSet().length != value.signatureDraft.length ||
        value.signatures.values.any((rank) => rank < 1 || rank > 3) ||
        value.signatureDraft.any((id) => (value.signatures[id] ?? 0) >= 3) ||
        !value.flashpointCooldown.isFinite ||
        value.flashpointCooldown < 0 ||
        value.flashpointCooldown > .8 ||
        value.draft.length > 3 ||
        value.draft.toSet().length != value.draft.length ||
        value.capstones.length > 2 ||
        value.capstones.toSet().length != value.capstones.length ||
        value.capstones.any((id) => !fusionRecipes.any((r) => r.id == id)) ||
        value.exits.length > 2 ||
        value.exits.toSet().length != value.exits.length ||
        (value.phase == ExpeditionPhase.reward &&
            ((value.draft.isEmpty &&
                    value.capstones.isEmpty &&
                    value.signatureDraft.isEmpty) ||
                (!value.bossRoom && value.spawned != value.pack.length))) ||
        (value.phase == ExpeditionPhase.victory && !value.bossRoom) ||
        (value.phase == ExpeditionPhase.exit &&
            (value.exits.length !=
                (value.bossRoom || value.room == value.roomCount - 1
                    ? 0
                    : 2))) ||
        (value.next != null &&
            (value.phase != ExpeditionPhase.exit ||
                value.next! < 0 ||
                value.next! >=
                    (value.exits.isEmpty ? 1 : value.exits.length)))) {
      throw const FormatException('Invalid Expedition save');
    }
    final tax = value.signatures[ExpeditionSignature.bloodTax];
    if (tax != null &&
        value.signatureKills >= ExpeditionSignature.bloodTaxKills(tax)) {
      throw const FormatException('Invalid Blood Tax progress');
    }
    return value;
  }
}

class ExpeditionRoom {
  ExpeditionRoom(Expedition expedition) {
    if (expedition.generator >= 3 && !expedition.bossRoom) {
      _authorChamber(expedition);
      return;
    }
    final random = expedition.random(2);
    final shape = (random.nextInt(4) + expedition.room) % 4;
    final region = expedition.region;
    final legacy =
        expedition.generator == 1 && region == ExpeditionRegion.breach;
    final compactBoss = expedition.generator >= 4 && expedition.bossRoom;
    final width = compactBoss
        ? (region == ExpeditionRegion.relay ? 2860.0 : 1940.0)
        : expedition.bossRoom
        ? (region == ExpeditionRegion.relay ? 3850.0 : 2360.0)
        : 1600.0 +
              120 * random.nextInt(4) +
              (legacy ? 0 : [0.0, 260.0, -180.0, 100.0][shape]);
    final height = compactBoss
        ? (region == ExpeditionRegion.relay ? 1990.0 : 1560.0)
        : expedition.bossRoom
        ? (region == ExpeditionRegion.relay ? 3030.0 : 1760.0)
        : 1080.0 +
              100 * random.nextInt(4) +
              (legacy ? 0 : [170.0, -70.0, 260.0, 0.0][shape]);
    bounds = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    entrance = Offset(0, height / 2 - 180);
    final spread = width * (.22 + random.nextInt(3) * .05);
    doors = expedition.bossRoom || expedition.room == expedition.roomCount - 1
        ? [Offset(0, -height / 2 + 110)]
        : [
            Offset(-spread, -height / 2 + 110),
            Offset(spread, -height / 2 + 110),
          ];
    final x = width * .22;
    final shift = (random.nextInt(5) - 2) * 42.0;
    final y = height * .2;
    Rect prop(double x, double y, double w, double h) =>
        Rect.fromCenter(center: Offset(x, y), width: w, height: h);
    final topology = <Rect>[
      if (!legacy && !expedition.bossRoom)
        ...switch (shape) {
          0 => [
            prop(-width / 2 + 137, y, 274, 235),
            prop(width / 2 - 137, -y, 274, 235),
          ],
          1 => [
            prop(-width / 2 + 118, -y, 236, 275),
            prop(width / 2 - 118, y, 236, 275),
          ],
          2 => [prop(width / 2 - 215, 0, 430, 165)],
          _ => [prop(-width / 2 + 190, -y, 380, 145)],
        },
    ];
    final exitClearance = [
      for (var i = 0; i < doors.length; i++) door(i).inflate(65),
    ];
    final entryClearance = Rect.fromCenter(
      center: entrance,
      width: 220,
      height: 145,
    );
    solids = List.unmodifiable(
      expedition.bossRoom
          ? <Rect>[]
          : [
                  ...topology,
                  ...switch (shape) {
                    0 => [prop(shift, -y, 470, 100), prop(-shift, y, 380, 100)],
                    1 => [prop(-x, shift, 105, 435), prop(x, -shift, 105, 435)],
                    2 => [
                      prop(-x, -y, 390, 105),
                      prop(x, y, 390, 105),
                      prop(shift, 0, 128, 115),
                      prop(-width / 2 + 88, y / 2, 176, 310),
                    ],
                    _ => [
                      prop(shift, 0, 390, 250),
                      prop(-x - 100, y, 175, 110),
                      prop(x + 100, -y, 175, 110),
                      prop(width / 2 - 94, y, 188, 290),
                    ],
                  },
                ]
                .where(
                  (solid) =>
                      legacy ||
                      (!solid.overlaps(entryClearance) &&
                          !exitClearance.any(solid.overlaps)),
                )
                .toList(),
    );
  }

  void _authorChamber(Expedition run) {
    final roll = run.random(2);
    final order = ExpeditionChamber.values.toList()
      ..shuffle(RunRandom(run.seed ^ (run.region.index * 31337)));
    var choices = order.toList();
    ExpeditionChamber? previous;
    for (var depth = 0; depth <= run.room; depth++) {
      if (choices.isEmpty) {
        choices = order.where((value) => value != previous).toList();
        // The previous chamber becomes eligible again after the next pick.
        choices.add(previous!);
      }
      final side = depth == 0 ? 0 : (run.route >> (run.room - depth)) & 1;
      final index = side == 1 && choices.length > 1 && choices[1] != previous
          ? 1
          : 0;
      previous = choices.removeAt(index);
    }
    chamber = previous!;
    final shift = (roll.nextInt(5) - 2) * 34.0;
    final (width, height) = switch (chamber!) {
      ExpeditionChamber.gallery => (2020.0, 1000.0),
      ExpeditionChamber.service => (1240.0, 1630.0),
      ExpeditionChamber.crossing => (1780.0, 1450.0),
      ExpeditionChamber.court => (1660.0, 1120.0),
    };
    final mirrored = run.generator >= 7 && roll.nextBool();
    final alternate = run.generator >= 7 && roll.nextBool();
    bounds = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    entrance = Offset(
      alternate ? (mirrored ? -145 : 145) : 0,
      height / 2 - 180,
    );
    final doorY = -height / 2 + 110;
    doors = run.room == run.roomCount - 1
        ? [Offset(0, doorY)]
        : [Offset(-width * .28, doorY), Offset(width * .28, doorY)];
    Rect block(double x, double y, double w, double h) =>
        Rect.fromCenter(center: Offset(x, y), width: w, height: h);
    final structures = alternate
        ? switch (chamber!) {
            ExpeditionChamber.gallery => [
              block(-470, -135, 320, 112),
              block(420, 137, 345, 106),
              block(-130, 92, 120, 160),
              block(160, -125, 116, 142),
            ],
            ExpeditionChamber.service => [
              block(-417, 224, 260, 145),
              block(386, -115, 300, 145),
              block(-120, -390, 130, 250),
              block(122, 110, 128, 180),
            ],
            ExpeditionChamber.crossing => [
              block(-610, 300, 400, 192),
              block(610, -280, 400, 192),
              block(-180, -210, 148, 214),
              block(187, 210, 150, 209),
            ],
            ExpeditionChamber.court => [
              block(-480, -175, 190, 155),
              block(480, 170, 190, 155),
              block(-440, 157, 200, 145),
              block(432, -161, 200, 145),
            ],
          }
        : switch (chamber!) {
            ExpeditionChamber.gallery => [
              block(-650, -80, 430, 124),
              block(650, 105, 420, 124),
              block(shift, 30, 145, 235),
            ],
            ExpeditionChamber.service => [
              block(-430, -120 + shift, 380, 165),
              block(430, 190 + shift, 380, 165),
              block(shift, -365, 175, 200),
            ],
            ExpeditionChamber.crossing => [
              block(-625, -280, 530, 330),
              block(625, 280, 530, 330),
              block(shift, 0, 290, 340),
            ],
            ExpeditionChamber.court => [
              block(-590, 180 + shift, 480, 220),
              block(590, -180 + shift, 480, 220),
            ],
          };
    final legal = ArenaBounds(bounds).interior;
    solids = List.unmodifiable([
      for (final structure in structures)
        (mirrored
                ? Rect.fromLTRB(
                    -structure.right,
                    structure.top,
                    -structure.left,
                    structure.bottom,
                  )
                : structure)
            .intersect(legal),
    ]);
  }

  late final Rect bounds;
  ExpeditionChamber? chamber;
  late final Offset entrance;
  late final List<Offset> doors;
  late final List<Rect> solids;

  late final List<Offset> trapPlates = List.unmodifiable([
    for (final y in [-245.0, 40.0, 245.0])
      for (final x in [-310.0, 310.0])
        if (!solids.any((solid) => solid.inflate(125).contains(Offset(x, y))))
          Offset(x, y),
  ]);

  Rect wallDoor(int index) => Rect.fromCenter(
    center: Offset(doors[index].dx, bounds.top + 44),
    width: 172,
    height: 24,
  );

  Rect door(int index) =>
      Rect.fromCenter(center: doors[index], width: 172, height: 70);
}

enum ExpeditionChamber {
  gallery('GALLERY'),
  service('SERVICE TUNNEL'),
  crossing('CROSSING'),
  court('MUSTER COURT');

  const ExpeditionChamber(this.label);
  final String label;
}
