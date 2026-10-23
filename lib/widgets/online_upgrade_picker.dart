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

  Widget _card(String id, bool fusion) {
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
                  '${power == PowerUp.dashCapacity && rank == 2 ? 'Triple Dash' : power?.title ?? recipe?.title ?? id}${fusion || id == 'salvage' ? '' : ' $rankName'}',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: Color(0xffE5DDD1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  power != null
                      ? upgradeDescription(power, rank: session.gun!.rank(id))
                      : recipe?.description ?? '',
                  style: const TextStyle(
                    color: Color(0xffB9B7AF),
                    fontSize: 12,
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
