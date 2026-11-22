import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/desktop/controller_menu.dart';
import 'package:regun/systems/expedition.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:regun/widgets/survivor_portrait.dart';

const _paper = Color(0xfff1e7d6);
const _muted = Color(0xffbdb1a5);
const _edge = Color(0xff51453f);
const _cleared = Color(0xffe5be7f);
const _lost = Color(0xffefa18b);
const _label = TextStyle(
  color: _cleared,
  fontFamily: FontFam.orbitron,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
  fontSize: 12,
);
const _body = TextStyle(
  color: _muted,
  fontFamily: FontFam.orbitron,
  fontSize: 14,
  height: 1.35,
);

class ExpeditionResults extends StatelessWidget {
  const ExpeditionResults({
    super.key,
    required this.run,
    required this.loadout,
    required this.elapsed,
    required this.kills,
    required this.buildEntries,
    required this.threatUnlocked,
    required this.saving,
    required this.saveFailed,
    required this.onReturn,
    required this.onRetrySave,
  });

  final Expedition run;
  final Loadout loadout;
  final String elapsed;
  final int kills;
  final List<({String name, String? rank})> buildEntries;
  final bool threatUnlocked, saving, saveFailed;
  final VoidCallback onReturn, onRetrySave;

  bool get _victory => run.phase == ExpeditionPhase.victory;
  Color get _accent => _victory ? _cleared : _lost;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xda100e11),
    child: SafeArea(
      minimum: const EdgeInsets.all(10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 856),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 640;
              final inset = wide ? 24.0 : 16.0;
              final short = box.maxHeight < 480;
              return ControllerMenuScope(
                child: Material(
                  color: const Color(0xff201c1e),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _accent, width: 3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              primary: true,
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                short ? 14 : 22,
                                inset,
                                short ? 14 : 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _heading(wide: wide, short: short),
                                  SizedBox(height: short ? 14 : 22),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _route()),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 2, child: _build()),
                                      ],
                                    )
                                  else ...[
                                    _route(),
                                    const SizedBox(height: 18),
                                    _build(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xff282224),
                            border: Border(top: BorderSide(color: _edge)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: inset,
                              vertical: short ? 7 : 10,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                if (saving)
                                  const Text('Saving results…', style: _body)
                                else if (saveFailed)
                                  Text(
                                    'Results could not be saved.',
                                    style: _body.copyWith(color: _lost),
                                  )
                                else if (threatUnlocked)
                                  Text(
                                    'Threat ${run.threat + 2} unlocked',
                                    style: _body.copyWith(color: _cleared),
                                  ),
                                ClickButton(
                                  text: saveFailed
                                      ? 'Retry save'
                                      : 'Return to Outpost',
                                  buttonColor: _cleared,
                                  height: 46,
                                  autofocus: true,
                                  onTap: saving
                                      ? null
                                      : saveFailed
                                      ? onRetrySave
                                      : onReturn,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _heading({required bool wide, required bool short}) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FIELD REPORT  /  THREAT ${run.threat + 1}',
              style: _label.copyWith(color: _accent),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final preferred = wide ? 21.0 : 14.0;
                final scale =
                    MediaQuery.textScalerOf(context).scale(preferred) /
                    preferred;
                // Keep the ten-glyph word intact at narrow, enlarged settings.
                final fontSize = math.min(
                  preferred,
                  box.maxWidth / (10.2 * scale),
                );
                return Semantics(
                  header: true,
                  child: Text(
                    _victory ? 'EXPEDITION COMPLETE' : 'EXPEDITION LOST',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: fontSize,
                      color: _paper,
                      height: 1.45,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 9),
            Text(
              '${loadout.character.title}  /  ${loadout.weapon.title}',
              style: _body,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [_stat('Time', elapsed), _stat('Kills', '$kills')],
            ),
          ],
        ),
      ),
      if (wide && !short)
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: 86,
            child: SurvivorPortrait(
              character: loadout.character,
              weapon: loadout.weapon,
              maxArtSize: 84,
            ),
          ),
        ),
    ],
  );

  Widget _stat(String label, String value) => Text.rich(
    TextSpan(
      text: '$label ',
      children: [
        TextSpan(
          text: value,
          style: const TextStyle(color: _paper, fontWeight: FontWeight.w700),
        ),
      ],
    ),
    style: _body,
  );

  Widget _route() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('ROUTE', style: _label),
      const SizedBox(height: 7),
      for (final region in ExpeditionRegion.values) _region(region),
    ],
  );

  Widget _region(ExpeditionRegion region) {
    final cleared = _victory || region.index < run.region.index;
    final reached = region == run.region && !_victory;
    final marker = cleared
        ? _cleared
        : reached
        ? _lost
        : _edge;
    final title = region.arena.title;
    final stage = run.bossRoom ? region.boss.title : 'Room ${run.room + 1}';
    return Semantics(
      label:
          '$title, ${cleared
              ? 'cleared'
              : reached
              ? 'run ended at $stage'
              : 'unreached'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: PixelIcon(
                cleared
                    ? PixelGlyph.star
                    : reached
                    ? PixelGlyph.cross
                    : PixelGlyph.round,
                size: 13,
                color: marker,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reached ? '$title / $stage' : title,
                style: _body.copyWith(
                  color: reached
                      ? _lost
                      : cleared
                      ? _paper
                      : _muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('BUILD', style: _label),
      const SizedBox(height: 8),
      if (buildEntries.isEmpty)
        const Text('No boons earned', style: _body)
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in buildEntries)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xff2c2526),
                  border: Border(left: BorderSide(color: _edge, width: 2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: entry.name,
                      children: [
                        if (entry.rank case final rank?)
                          TextSpan(
                            text: '  $rank',
                            style: const TextStyle(color: _cleared),
                          ),
                      ],
                    ),
                    style: _body.copyWith(color: _paper),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}
