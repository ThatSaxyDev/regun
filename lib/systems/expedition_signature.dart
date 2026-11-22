import 'dart:ui';

enum ExpeditionCue {
  breach,
  thunder,
  flash,
  frost,
  fracture,
  fuse,
  blood,
  deadeye,
  curtain,
  slag,
  backlash,
  quickdraw,
  shatter,
  fusePrimer,
  quickdrawChamber;

  String get sound => 'signature_$name.wav';
}

/// One committed second detonation. Its remaining time only ticks during combat.
class ExpeditionAftershock {
  ExpeditionAftershock({
    required this.center,
    required this.radius,
    required this.damage,
    required this.targets,
    required this.shaped,
    this.remaining = delay,
  });

  static const delay = .28;
  static const limit = 8;
  final Offset center;
  final double radius, damage;
  final int targets;
  final bool shaped;
  double remaining;

  List<Object> toJson() => [
    center.dx,
    center.dy,
    radius,
    damage,
    targets,
    remaining,
    shaped,
  ];

  factory ExpeditionAftershock.read(Object? raw) {
    if (raw is! List ||
        raw.length != 7 ||
        raw.take(6).any((value) => value is! num || !value.isFinite) ||
        raw[4] is! int ||
        raw[6] is! bool) {
      throw const FormatException('Invalid Fuse Link aftershock');
    }
    final center = Offset(
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
    );
    final radius = (raw[2] as num).toDouble(),
        damage = (raw[3] as num).toDouble();
    final targets = raw[4] as int, remaining = (raw[5] as num).toDouble();
    if (center.dx.abs() > 4000 ||
        center.dy.abs() > 4000 ||
        radius <= 0 ||
        radius > 410 ||
        damage <= 0 ||
        damage > 20 ||
        targets < 5 ||
        targets > 7 ||
        remaining <= 0 ||
        remaining > delay) {
      throw const FormatException('Invalid Fuse Link aftershock');
    }
    return ExpeditionAftershock(
      center: center,
      radius: radius,
      damage: damage,
      targets: targets,
      shaped: raw[6] as bool,
      remaining: remaining,
    );
  }
}

/// A signature changes an existing combat action for the rest of this run.
enum ExpeditionSignature {
  breachCharge(
    'Breach Charge',
    'Finish a reload to fire a concussive wave on your next hit.',
    'The wave reaches farther and hits harder.',
  ),
  thunderstep(
    'Thunderstep',
    'Finish a dash to send lightning through nearby enemies.',
    'The landing strikes more enemies from farther away.',
  ),
  flashpoint(
    'Flashpoint',
    'Weapon and signature kills can ignite a blast around the fallen enemy.',
    'The blast reaches farther and hits harder.',
  ),
  coldSnap(
    'Cold Snap',
    'The first hit after reloading bursts into frost and briefly freezes nearby enemies.',
    'The burst reaches farther and deals more damage.',
  ),
  shatterstep(
    'Shatterstep',
    'Dash into a pack to crack the floor and shove enemies away.',
    'The landing hits harder and throws enemies farther.',
  ),
  fuseLink(
    'Fuse Link',
    'Grenades leave a hot charge that bursts again a beat later.',
    'The second blast hits harder and reaches farther.',
  ),
  bloodTax(
    'Blood Tax',
    'Earn a heal after 70 kills. At full health, it waits for a kill while hurt.',
    'Restore one heart after fewer kills.',
  ),
  deadeye(
    'Deadeye',
    'Every fourth weapon hit sends a shock through enemies near the target.',
    'The shock deals more damage and travels farther.',
  ),
  ironCurtain(
    'Iron Curtain',
    'Completing a reload sweeps away nearby hostile projectiles.',
    'The sweep protects a wider area.',
  ),
  thermite(
    'Thermite',
    'Grenades leave a patch of burning metal on the floor.',
    'The patch burns hotter.',
  ),
  backlash(
    'Backlash',
    'When you lose health, a pressure wave shoves nearby enemies away.',
    'The wave grows wider and stronger.',
  ),
  quickdraw(
    'Quickdraw',
    'Landing a dash chambers a round and primes a shock on your next hit.',
    'The follow-up shock deals more damage.',
  );

  static const firstPass = [
    breachCharge,
    thunderstep,
    flashpoint,
    coldSnap,
    shatterstep,
    fuseLink,
    bloodTax,
    deadeye,
  ];
  static int bloodTaxKills(int rank) => 75 - 5 * rank;

  String descriptionAt(int rank) => this == bloodTax
      ? 'Earn a heal after ${bloodTaxKills(rank)} kills. Holds at full health.'
      : rank == 1
      ? description
      : upgrade;

  static const legacy = [breachCharge, thunderstep, flashpoint];

  const ExpeditionSignature(this.title, this.description, this.upgrade);
  final String title, description, upgrade;
}

/// Each fusion adds a distinct trigger or changes how two signatures interact.
enum ExpeditionFusion {
  brittleSteel(
    'Brittle Steel',
    'Shatterstep breaks frozen enemies for bonus damage and sends shards into the pack.',
    ExpeditionSignature.coldSnap,
    ExpeditionSignature.shatterstep,
  ),
  flashover(
    'Flashover',
    'Flashpoint kills ignite nearby enemies. Burning enemies killed by a grenade can also trigger Flashpoint.',
    ExpeditionSignature.flashpoint,
    ExpeditionSignature.fuseLink,
  ),
  arcPrimer(
    'Arc Primer',
    'Thunderstep primes Breach Charge. A dash into a pack can set up your next shot.',
    ExpeditionSignature.thunderstep,
    ExpeditionSignature.breachCharge,
  ),
  fieldTransfusion(
    'Field Transfusion',
    'A Blood Tax heal primes Cold Snap and sweeps away nearby hostile rounds.',
    ExpeditionSignature.bloodTax,
    ExpeditionSignature.coldSnap,
  ),
  liveWire(
    'Live Wire',
    'Thunderstep primes Deadeye one hit away from its next shock.',
    ExpeditionSignature.deadeye,
    ExpeditionSignature.thunderstep,
  ),
  shapedCharge(
    'Shaped Charge',
    'The first target hit by Fuse Link sends a concussive blast into nearby enemies.',
    ExpeditionSignature.fuseLink,
    ExpeditionSignature.breachCharge,
  ),
  slagTrail(
    'Slag Trail',
    'Shatterstep leaves burning thermite at the landing point.',
    ExpeditionSignature.shatterstep,
    ExpeditionSignature.thermite,
  ),
  countermeasure(
    'Countermeasure',
    'Backlash also sweeps away hostile projectiles when you lose health.',
    ExpeditionSignature.ironCurtain,
    ExpeditionSignature.backlash,
  ),
  runningShot(
    'Running Shot',
    'Quickdraw shocks also hit a second group around you when the shot connects.',
    ExpeditionSignature.quickdraw,
    ExpeditionSignature.deadeye,
  );

  const ExpeditionFusion(this.title, this.description, this.first, this.second);
  final String title, description;
  final ExpeditionSignature first, second;

  bool ready(Map<ExpeditionSignature, int> ranks) =>
      (ranks[first] ?? 0) >= 2 && (ranks[second] ?? 0) >= 2;

  ExpeditionSignature? partner(ExpeditionSignature card) => card == first
      ? second
      : card == second
      ? first
      : null;
}
