import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// Read-only comparisons use the current visit's pinned numbers and loadout.
class RankPathPreview extends StatefulWidget {
  const RankPathPreview({
    super.key,
    required this.state,
    required this.weapon,
    required this.character,
    required this.power,
  });
  final GameState state;
  final WeaponType weapon;
  final CharacterType character;
  final WeaponPowerBalance power;
  @override
  State<RankPathPreview> createState() => _RankPathPreviewState();
}

class _RankPathPreviewState extends State<RankPathPreview> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final choices = powerUps
        .where((p) => weaponSupportsPowerUp(widget.weapon, p))
        .toList();
    final p = choices[index % choices.length];
    final limit = widget.state.rankLimit(p);
    final ranks = limit < 8 ? List.generate(limit, (i) => i + 1) : [3, 4, 8];
    const style = TextStyle(
      fontFamily: FontFam.orbitron,
      fontSize: 11,
      height: 1.5,
      color: Color(0xffE5DDD1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${p.title} / ${widget.weapon.title}', style: style),
        const SizedBox(height: 12),
        for (final rank in ranks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'][rank]} / ${widget.state.rankValues(p, rank, widget.weapon, widget.character, widget.power).entries.map((e) => '${e.key} ${e.value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '')}').join(' / ')}',
              style: style,
            ),
          ),
        const Text(
          'Compare one upgrade. Prerequisites and other upgrades still apply.',
          style: style,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ClickButton(
              text: 'Previous',
              width: 140,
              height: 44,
              onTap: () => setState(
                () => index = (index - 1 + choices.length) % choices.length,
              ),
            ),
            ClickButton(
              text: 'Next',
              width: 140,
              height: 44,
              onTap: () => setState(() => index = (index + 1) % choices.length),
            ),
          ],
        ),
      ],
    );
  }
}
