import 'package:regun/utils/format_number.dart';
import 'package:regun/widgets/support_thumbnail.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/rank_effect_values.dart';
import 'package:regun/systems/upgrade_details.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

class OnlineUpgradePicker extends StatelessWidget {
  const OnlineUpgradePicker({super.key, required this.session});
  final OnlineSession session;
  @override
  Widget build(BuildContext context) {
    final gun = session.gun!;
    final source = gun.progress['source'] as String? ?? '';
    final fusion = source == 'fusion';
    return ColoredBox(
      color: const Color(0xe8141117),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gun.offers.isEmpty
                      ? 'Team is choosing'
                      : fusion
                      ? 'Fuse a core'
                      : source.startsWith('supply:')
                      ? 'Airdrop'
                      : 'Choose an upgrade',
                  style: const TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 16,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${session.match!.phaseSeconds.ceil()}s',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: Color(0xffAD9162),
                  ),
                ),
                const SizedBox(height: 16),
                for (final choice in gun.offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _card(choice, fusion),
                  ),
                if (!fusion && gun.offers.isNotEmpty)
                  ClickButton(
                    text: 'Reroll (${gun.progress['rerolls'] ?? 0})',
                    onTap:
                        session.busy ||
                            (gun.progress['rerolls'] as num? ?? 0) <= 0
                        ? null
                        : () => unawaited(session.rerollUpgrade()),
                  ),
                if (session.error.isNotEmpty)
                  Text(
                    session.error,
                    style: const TextStyle(color: Color(0xffDD826C)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _delta(String id) {
    final gun = session.gun!;
    if ((gun.data['rankCurves'] as Map?)?['ranks.meta.policy'] != 1) return '';
    final v = <String, num>{
      ...Map<String, num>.from(gun.data['rankCurves'] as Map? ?? {}),
      for (final e in (gun.data['upgradeStrengths'] as Map? ?? {}).entries)
        'powerups.${e.key}.${{'dashCapacity', 'grenadeCapacity'}.contains(e.key) ? 'capacity' : 'strength'}':
            e.value as num,
      for (final e in {
        'capacity': gun.baseCapacity,
        'cadence': gun.baseNumber('cadence', .35),
        'reloadMs': gun.baseNumber('reload', 3.2) * 1000,
        'range': gun.baseNumber('range', 420),
        'speed': gun.baseNumber('speed', 700),
      }.entries)
        'weapons.${gun.weapon}.${e.key}': e.value,
    };
    final before = RankEffects.values(
      id,
      gun.rank(id),
      v,
      weapon: gun.weapon,
      survivor: gun.survivor,
      fusions: Set<String>.from(gun.data['fusions'] as List? ?? []),
    );
    final after = RankEffects.values(
      id,
      gun.rank(id) + 1,
      v,
      weapon: gun.weapon,
      survivor: gun.survivor,
      fusions: Set<String>.from(gun.data['fusions'] as List? ?? []),
    );
    String n(num v) => groupNumberText(
      v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    final changed = after.keys.where(
      (k) => ((after[k] ?? 0) - (before[k] ?? 0)).abs() > 1e-8,
    );
    return changed.isEmpty
        ? 'Fusion prerequisite rank.'
        : changed
              .take(2)
              .map((k) => '$k ${n(before[k] ?? 0)} to ${n(after[k] ?? 0)}')
              .join(' / ');
  }

  Widget _card(String id, bool fusion) {
    final support = SupportCard.read(id);
    final supportValues = Map<String, num>.from(
      session.gun!.data['supportValues'] as Map? ?? {},
    );
    final power = PowerUp.values.where((p) => p.name == id).firstOrNull;
    final recipe = fusionRecipes.where((p) => p.id == id).firstOrNull;
    final rank = session.gun!.rank(id) + 1;
    final rankName = [
      '',
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
    ][rank.clamp(0, 8)];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff211D23),
        border: Border.all(color: const Color(0xff6F604B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  support != null
                      ? '${support.title} ${support.rankLabel}'
                      : '${power == PowerUp.dashCapacity && rank == 2 ? 'Triple Dash' : power?.title ?? recipe?.title ?? id}${fusion || id == 'salvage' ? '' : ' $rankName'}',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: Color(0xffE5DDD1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  support != null
                      ? support.description(supportValues)
                      : power != null
                      ? upgradeDescription(power, rank: session.gun!.rank(id))
                      : recipe?.description ?? '',
                  style: const TextStyle(
                    color: Color(0xffB9B7AF),
                    fontSize: 12,
                  ),
                ),
                if (support != null) SupportThumbnail(card: support),
                if (!fusion && support == null && _delta(id).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _delta(id),
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 11,
                        height: 1.5,
                        color: Color(0xffE1BA78),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClickButton(
                  text: fusion ? 'Fuse' : 'Take',
                  height: 44,
                  onTap: session.busy
                      ? null
                      : () => unawaited(session.chooseUpgrade(id)),
                ),
                if (!fusion &&
                    id != 'salvage' &&
                    (session.gun!.progress['bans'] as num? ?? 0) > 0)
                  TextButton(
                    onPressed: session.busy
                        ? null
                        : () => unawaited(session.banUpgrade(id)),
                    child: const Text(
                      'Ban',
                      style: TextStyle(color: Color(0xffB9B7AF)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
