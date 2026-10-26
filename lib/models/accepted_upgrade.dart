import 'package:regun/models/upgrade_animation_recipe.dart';

/// Cosmetic receipt emitted only after a validated reward commit. It cannot
/// grant damage, charges, ranks or recovery. Recovery retains its own ledger.
class AcceptedUpgrade {
  const AcceptedUpgrade({
    required this.generation,
    required this.actor,
    required this.serial,
    required this.offerId,
    required this.source,
    required this.id,
    required this.beforeRank,
    required this.afterRank,
    required this.balance,
    required this.before,
    required this.after,
  });
  final int generation, serial, offerId, beforeRank, afterRank;
  final String actor, source, id, balance;
  final Map<String, num> before, after;
  Map<String, Object?> toJson() => {
    'schema': 1,
    'generation': generation,
    'actor': actor,
    'serial': serial,
    'offerId': offerId,
    'source': source,
    'id': id,
    'beforeRank': beforeRank,
    'afterRank': afterRank,
    'balance': balance,
    'before': before,
    'after': after,
  };
  static AcceptedUpgrade? read(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map || raw.length != 12 || raw['schema'] != 1) {
      throw const FormatException('Invalid upgrade receipt');
    }
    for (final key in [
      'generation',
      'serial',
      'offerId',
      'beforeRank',
      'afterRank',
    ]) {
      final n = raw[key];
      if (n is! int || n < 0 || n > (key.endsWith('Rank') ? 8 : 1000000000)) {
        throw const FormatException('Invalid upgrade receipt serial/rank');
      }
    }
    for (final key in ['actor', 'source', 'id', 'balance']) {
      if (raw[key] is! String || (raw[key] as String).length > 128) {
        throw const FormatException('Invalid upgrade receipt identity');
      }
    }
    Map<String, num> values(String key) {
      final map = raw[key];
      if (map is! Map ||
          map.length > 12 ||
          map.entries.any(
            (e) =>
                e.key is! String ||
                (e.key as String).length > 64 ||
                e.value is! num ||
                !(e.value as num).isFinite ||
                (e.value as num).abs() > 1000000,
          )) {
        throw const FormatException('Invalid upgrade receipt components');
      }
      return Map.unmodifiable(map.cast<String, num>());
    }

    final receipt = AcceptedUpgrade(
      generation: raw['generation'],
      actor: raw['actor'],
      serial: raw['serial'],
      offerId: raw['offerId'],
      source: raw['source'],
      id: raw['id'],
      beforeRank: raw['beforeRank'],
      afterRank: raw['afterRank'],
      balance: raw['balance'],
      before: values('before'),
      after: values('after'),
    );
    if (!validUpgradeRewardId(receipt.id) ||
        receipt.serial < 1 ||
        receipt.afterRank < receipt.beforeRank) {
      throw const FormatException('Unknown upgrade receipt');
    }
    final required = switch (receipt.family) {
      'heavyLoad' => ['Damage multiplier'],
      'walkingSpeedIncrease' => ['Walking speed'],
      'scrapArmour' => ['Guard recharge (s)'],
      'hotShot' => ['Burn per tick'],
      'ricochet' => [
        receipt.after.containsKey('Total enemy ricochets')
            ? 'Total enemy ricochets'
            : 'Extra bounces',
      ],
      'support:sentry' => ['Battery (s)', 'Incoming (s)'],
      _ => <String>[],
    };
    if (required.any(
      (k) =>
          !receipt.after.containsKey(k) ||
          (receipt.family != 'support:sentry' &&
              !receipt.before.containsKey(k)),
    )) {
      throw const FormatException('Incomplete upgrade receipt');
    }
    if (receipt.family == 'support:sentry' &&
        (!RegExp(r'^support:sentry:[1-8]:(carbine|burstRifle)$')
                .hasMatch(receipt.id) ||
            int.parse(receipt.id.split(':')[2]) != receipt.afterRank)) {
      throw const FormatException('Invalid support receipt');
    }
    return receipt;
  }

  String get family =>
      id.startsWith('support:') ? id.split(':').take(2).join(':') : id;
  bool get prototype => const {
    'heavyLoad',
    'walkingSpeedIncrease',
    'scrapArmour',
    'hotShot',
    'ricochet',
    'support:sentry',
  }.contains(family);
}
