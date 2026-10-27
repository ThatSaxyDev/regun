import 'package:regun/utils/format_number.dart';
import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/weapon_thumbnail.dart';

/// Only recorded run progress and current resources; no estimated combat metrics.
class RunPauseSummary extends StatelessWidget {
  const RunPauseSummary({
    super.key,
    required this.state,
    required this.loadout,
    required this.reloadSeconds,
  });
  final GameState state;
  final Loadout loadout;
  final double reloadSeconds;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SizedBox(
            width: 76,
            height: 36,
            child: WeaponThumbnail(loadout.weapon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loadout.weapon.title,
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${loadout.character.title} / ${loadout.arena.title}',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xffB2A8B4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Divider(height: 1, color: Color(0xff665A68)),
      const SizedBox(height: 16),
      MenuCardGrid(
        minColumnWidth: 160,
        children: [
          _Stat(
            'SURVIVED',
            '${state.survivalSeconds ~/ 60}:${(state.survivalSeconds % 60).toString().padLeft(2, '0')}',
          ),
          _Stat('KILLS', formatNumber(state.kills)),
          _Stat('BOSSES DEFEATED', formatNumber(state.bosses)),
          _Stat('HEALTH', '${state.health} / ${state.maxHealth}'),
          _Stat(
            'AMMO',
            '${state.noOfBullets} / ${state.maxBullets}',
            note: state.reloading
                ? 'Reloading ${reloadSeconds.toStringAsFixed(1)}s'
                : null,
          ),
          _Stat(
            'LEVEL',
            '${state.currentLevel}',
            note:
                '${formatNumber(state.xP)} / ${formatNumber(state.noOfCoinsToUpgrade.floor())} XP',
          ),
        ],
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.note});
  final String label, value;
  final String? note;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value${note == null ? '' : ', $note'}',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 10,
              height: 1.4,
              color: Color(0xffB2A8B4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: 13,
              height: 1.6,
              color: Color(0xffE1BA78),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                height: 1.4,
                color: Color(0xffE5DDD1),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
