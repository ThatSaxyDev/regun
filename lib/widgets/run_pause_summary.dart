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
    this.desktop = false,
  });
  final GameState state;
  final Loadout loadout;
  final double reloadSeconds;
  final bool desktop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SizedBox(
            width: desktop ? 142 : 76,
            height: desktop ? 62 : 36,
            child: WeaponThumbnail(loadout.weapon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loadout.weapon.title,
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: desktop ? 20 : 14,
                    height: 1.4,
                    color: const Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${loadout.character.title} / ${loadout.arena.title}',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: desktop ? 14 : 11,
                    height: 1.4,
                    color: const Color(0xffB2A8B4),
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
        minColumnWidth: desktop ? 145 : 160,
        children: [
          _Stat(
            'SURVIVED',
            desktop: desktop,
            '${state.survivalSeconds ~/ 60}:${(state.survivalSeconds % 60).toString().padLeft(2, '0')}',
          ),
          _Stat('KILLS', formatNumber(state.kills), desktop: desktop),
          _Stat(
            'BOSSES DEFEATED',
            formatNumber(state.bosses),
            desktop: desktop,
          ),
          _Stat(
            'HEALTH',
            '${state.health} / ${state.maxHealth}',
            desktop: desktop,
          ),
          _Stat(
            'AMMO',
            desktop: desktop,
            '${state.noOfBullets} / ${state.maxBullets}',
            note: state.reloading
                ? 'Reloading ${reloadSeconds.toStringAsFixed(1)}s'
                : null,
          ),
          _Stat(
            'LEVEL',
            desktop: desktop,
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
  const _Stat(this.label, this.value, {this.note, required this.desktop});
  final String label, value;
  final String? note;
  final bool desktop;
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
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: desktop ? 13 : 10,
              height: 1.4,
              color: const Color(0xffB2A8B4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: desktop ? 20 : 13,
              height: 1.6,
              color: const Color(0xffE1BA78),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: desktop ? 14 : 11,
                height: 1.4,
                color: const Color(0xffE5DDD1),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
