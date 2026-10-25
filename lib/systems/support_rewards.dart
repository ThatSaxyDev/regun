import 'dart:math';

/// Supply-only identities; deliberately outside permanent PowerUp ranks/slots.
enum SupportFamily { sentry, aura }

const supportMaxTier = 8;
const supportTierLabels = [
  '',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
];

class SupportCard {
  const SupportCard(this.family, this.tier, {this.mount = 'carbine'});
  final SupportFamily family;
  final int tier;
  final String mount;
  String get id =>
      'support:${family.name}:$tier:${family == SupportFamily.sentry ? mount : 'field'}';
  String get title => family == SupportFamily.aura ? 'Aura Farm' : 'Sentry Gun';
  String get rankLabel => supportTierLabels[tier];
  String description(Map<String, num> values) {
    final c = SupportConfig(values);
    String number(double v) =>
        v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    if (family == SupportFamily.aura) {
      return '${c.auraLife(tier).round()}s moving field. ${number(c.auraDamage(tier) / c.tick)} damage/s per enemy · ${c.auraRadius(tier).round()} radius.';
    }
    return '${mount == 'carbine' ? 'Carbine' : 'Three-round burst'} mount. ${number(c.weapon(mount, 'damage', mount == 'carbine' ? .9 : 1.25) * c.multiplier(tier))} damage/round · ${c.sentryLife(tier).round()}s battery · unlimited ammo · ${c.incoming}s incoming.';
  }

  static SupportCard? read(String id) {
    final p = id.split(':');
    if (p.length != 4 || p[0] != 'support') return null;
    final f = SupportFamily.values.where((f) => f.name == p[1]).firstOrNull;
    final t = int.tryParse(p[2]);
    if (f == null ||
        t == null ||
        t < 1 ||
        t > supportMaxTier ||
        (f == SupportFamily.sentry
            ? !['carbine', 'burstRifle'].contains(p[3])
            : p[3] != 'field')) {
      return null;
    }
    return SupportCard(f, t, mount: p[3]);
  }
}

class SupportConfig {
  const SupportConfig(this.values);
  final Map<String, num> values;
  double n(String family, String key, double fallback) =>
      (values['support.$family.$key'] ?? fallback).toDouble();
  bool enabled(SupportFamily family) => n(family.name, 'enabled', 0) == 1;
  double get incoming => n('sentry', 'incoming', 6);
  double get turn => n('sentry', 'turn', 300) * pi / 180;
  double get fallback => n('sentry', 'fallback', 1);
  double _rank(
    String family,
    String key,
    int tier,
    List<num> defaults,
    double tail,
    double cap,
  ) {
    final fallback = tier <= 3
        ? defaults[tier].toDouble()
        : max(
            defaults[tier].toDouble(),
            n(family, '${key}3', defaults[3].toDouble()) + tail * (tier - 3),
          ).clamp(0.0, cap).toDouble();
    return n(family, '$key$tier', fallback);
  }

  double sentryLife(int t) =>
      _rank('sentry', 'life', t, [0, 36, 42, 48, 51, 54, 57, 60, 63], 3, 75);
  double multiplier(int t) => _rank(
    'sentry',
    'damage',
    t,
    [0, 3, 3.5, 4, 4.25, 4.5, 4.75, 5, 5.25],
    .25,
    6,
  );
  double acquisition(String mount) => min(
    n(
      'sentry',
      mount == 'carbine' ? 'carbineRange' : 'burstRange',
      mount == 'carbine' ? 550 : 650,
    ),
    weapon(mount, 'range', mount == 'carbine' ? 650 : 700),
  );
  double weapon(String mount, String key, double fallback) =>
      (values['weapons.$mount.$key'] ?? fallback).toDouble();
  double auraLife(int t) =>
      _rank('aura', 'life', t, [0, 18, 22, 26, 28, 30, 32, 34, 36], 2, 60);
  double auraRadius(int t) => _rank(
    'aura',
    'radius',
    t,
    [0, 155, 165, 175, 180, 185, 190, 195, 200],
    5,
    220,
  );
  double auraDamage(int t) => _rank(
    'aura',
    'damage',
    t,
    [0, .375, .46875, .5625, .609375, .65625, .703125, .75, .796875],
    .046875,
    1,
  );
  double get tick => n('aura', 'tick', .25);
  int get targets => n('aura', 'targets', 12).toInt();
  double weight(SupportFamily f) => n(f.name, 'weight', 1);
  static void validate(Map<String, num> values) {
    if (!values.containsKey('support.sentry.enabled')) return;
    final c = SupportConfig(values);
    if (c.incoming < 3.45 ||
        c.acquisition('carbine') != c.n('sentry', 'carbineRange', 550) ||
        c.acquisition('burstRifle') != c.n('sentry', 'burstRange', 650)) {
      throw const FormatException('Invalid support arrival/range');
    }
    for (var t = 2; t <= supportMaxTier; t++) {
      if (c.sentryLife(t) < c.sentryLife(t - 1) ||
          c.multiplier(t) < c.multiplier(t - 1) ||
          c.auraLife(t) < c.auraLife(t - 1) ||
          c.auraRadius(t) < c.auraRadius(t - 1) ||
          c.auraDamage(t) < c.auraDamage(t - 1)) {
        throw const FormatException('Support tiers must increase');
      }
    }
  }
}

class SupportProgress {
  int serial = 0;
  final Map<String, int> tiers = {};
  final Set<String> banned = {};
  List<String> recent = [];
  SupportCard? offer;
  final List<SupportCard> pending = [];
  final Set<String> busy = {};
  SupportCard? roll(SupportConfig config, double Function() random) {
    final pool = SupportFamily.values
        .where(
          (f) =>
              config.enabled(f) &&
              !banned.contains(f.name) &&
              !busy.contains(f.name) &&
              config.weight(f) > 0,
        )
        .toList();
    if (pool.isEmpty) return offer = null;
    // An ordinary-only hand competes at weight 2; enablement is not a guarantee.
    final total = pool.fold<double>(0, (s, f) => s + config.weight(f));
    if (random() >= total / (total + 2)) return offer = null;
    var pick =
        random() *
        pool.fold<double>(
          0,
          (s, f) => s + config.weight(f) * (recent.contains(f.name) ? .35 : 1),
        );
    var chosen = pool.last;
    for (final f in pool) {
      pick -= config.weight(f) * (recent.contains(f.name) ? .35 : 1);
      if (pick <= 0) {
        chosen = f;
        break;
      }
    }
    recent = [chosen.name];
    return offer = SupportCard(
      chosen,
      min(supportMaxTier, (tiers[chosen.name] ?? 0) + 1),
      mount: chosen == SupportFamily.sentry && random() >= .5
          ? 'burstRifle'
          : 'carbine',
    );
  }

  bool confirm(String id) {
    final card = offer;
    if (card == null ||
        card.id != id ||
        busy.contains(card.family.name) ||
        banned.contains(card.family.name)) {
      return false;
    }
    tiers[card.family.name] = card.tier;
    busy.add(card.family.name);
    pending.add(card);
    serial++;
    offer = null;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'serial': serial,
    'tiers': tiers,
    'banned': banned.toList(),
    'recent': recent,
    'offer': offer?.id,
    'pending': pending.map((c) => c.id).toList(),
    'busy': busy.toList(),
  };
  static SupportProgress restore(dynamic raw) {
    final p = SupportProgress();
    if (raw == null) return p;
    if (raw is! Map ||
        raw['schema'] != 1 ||
        raw['serial'] is! int ||
        raw['serial'] < 0 ||
        raw['serial'] > 1000000) {
      throw const FormatException('Invalid support progress');
    }
    p.serial = raw['serial'];
    for (final e in (raw['tiers'] as Map).entries) {
      if (!['sentry', 'aura'].contains(e.key) ||
          e.value is! int ||
          e.value < 1 ||
          e.value > supportMaxTier) {
        throw const FormatException('Invalid support tier');
      }
      p.tiers[e.key] = e.value;
    }
    for (final key in ['banned', 'recent', 'busy']) {
      final list = List<String>.from(raw[key] as List);
      if (list.length > 2 ||
          list.any((x) => !['sentry', 'aura'].contains(x)) ||
          list.toSet().length != list.length) {
        throw const FormatException('Invalid support family');
      }
      if (key == 'banned') p.banned.addAll(list);
      if (key == 'recent') p.recent = list;
      if (key == 'busy') p.busy.addAll(list);
    }
    if (raw['offer'] != null) {
      p.offer = SupportCard.read(raw['offer']);
      if (p.offer == null) throw const FormatException('Invalid support offer');
    }
    for (final id in raw['pending'] as List) {
      final c = SupportCard.read(id);
      if (c == null ||
          !p.busy.contains(c.family.name) ||
          c.tier != p.tiers[c.family.name] ||
          p.pending.any((e) => e.family == c.family)) {
        throw const FormatException('Invalid support entitlement');
      }
      p.pending.add(c);
    }
    if (p.pending.length > 2 ||
        p.busy.any((f) => !p.tiers.containsKey(f)) ||
        p.serial < p.tiers.values.fold(0, (a, b) => a + b)) {
      throw const FormatException('Invalid support pending');
    }
    return p;
  }
}

List<Map<String, num>> supportProjection(
  Map<String, num> values,
  SupportFamily family, {
  String mount = 'carbine',
}) {
  final c = SupportConfig(values);
  return [
    for (var t = 1; t <= supportMaxTier; t++)
      if (family == SupportFamily.aura)
        {
          'tier': t,
          'lifetime': c.auraLife(t),
          'radius': c.auraRadius(t),
          'tick': c.tick,
          'damage': c.auraDamage(t),
          'exposureDps': c.auraDamage(t) / c.tick,
          'targets': c.targets,
        }
      else
        {
          'tier': t,
          'lifetime': c.sentryLife(t),
          'incoming': c.incoming,
          'damage':
              c.weapon(mount, 'damage', mount == 'carbine' ? .9 : 1.25) *
              c.multiplier(t),
          'unlimitedAmmo': 1,
          'reload': 0,
          'cadence': c.weapon(mount, 'cadence', mount == 'carbine' ? .1 : .6),
          'range': c.acquisition(mount),
          'fireOnlyDps':
              c.weapon(mount, 'damage', mount == 'carbine' ? .9 : 1.25) *
              c.multiplier(t) *
              (mount == 'carbine' ? 1 : 3) /
              c.weapon(mount, 'cadence', mount == 'carbine' ? .1 : .6),
        },
  ];
}
