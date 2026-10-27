import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/theme/upgrade_glyph.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:regun/widgets/support_thumbnail.dart';
import 'package:regun/widgets/survivor_portrait.dart';
import 'package:regun/widgets/weapon_thumbnail.dart';

const _paper = Color(0xffeee5d4),
    _muted = Color(0xffb5aa96),
    _brass = Color(0xffedd2a1),
    _rule = Color(0xff3b3437);
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String _played(int seconds) => seconds >= 3600
    ? '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m'
    : _clock(seconds);
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
int _count(dynamic value) => value is num ? value.toInt() : 0;
PowerUp? _upgrade(String id) =>
    PowerUp.values.where((p) => p.name == id).firstOrNull;
WeaponType? _weapon(String id) =>
    WeaponType.values.where((p) => p.name == id).firstOrNull;
CharacterType _survivor(dynamic id) =>
    CharacterType.values.where((p) => p.name == id).firstOrNull ??
    CharacterType.rook;
String _rank(dynamic value) {
  final rank = _count(value);
  return rank >= 1 && rank <= 8
      ? const ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'][rank - 1]
      : formatNumber(rank);
}

class PlayerRecordPanel extends StatefulWidget {
  const PlayerRecordPanel({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<PlayerRecordPanel> createState() => _PlayerRecordPanelState();
}

class _PlayerRecordPanelState extends State<PlayerRecordPanel> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final data = widget.data,
        stats = _map(data['stats']),
        best = _map(data['best']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: SurvivorPortrait(
                character: _survivor(best['survivor']),
                maxArtSize: 56,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] as String? ?? 'Player',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _paper,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (data['online'] == true)
                    const Text(
                      'Playing',
                      style: TextStyle(color: _brass, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClickButtonM(
              text: 'Back',
              width: 100,
              height: 48,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, label) in [
                'Records',
                'Weapons',
                'Upgrades',
              ].indexed)
                Semantics(
                  selected: tab == index,
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() => tab = index),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 112,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: tab == index ? _brass : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: tab == index ? _brass : _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: _rule),
        const SizedBox(height: 12),
        Expanded(
          child: tab == 0
              ? _records(context, stats, best)
              : _usage(stats, weapon: tab == 1),
        ),
      ],
    );
  }

  Widget _records(
    BuildContext context,
    Map<String, dynamic> stats,
    Map<String, dynamic> best,
  ) {
    final career = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Career'),
        const SizedBox(height: 4),
        for (final (label, value, emphasis) in [
          ('Best score', formatMetric(stats['bestScore'] ?? 0), true),
          ('Longest run', _clock(_count(stats['bestSeconds'])), false),
          ('Runs', formatMetric(stats['runs'] ?? 0), false),
          ('Enemy kills', formatMetric(stats['kills'] ?? 0), false),
          ('Bosses', formatMetric(stats['bosses'] ?? 0), false),
        ])
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _rule)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: emphasis ? _brass : _paper,
                      fontSize: emphasis ? 21 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide =
            box.maxWidth >= 640 &&
            MediaQuery.textScalerOf(context).scale(12) <= 17;
        if (!wide || best.isEmpty) {
          return SingleChildScrollView(
            key: const PageStorageKey('record-overview'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                career,
                if (best.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _bestBuild(best),
                ],
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: SingleChildScrollView(child: career)),
            const SizedBox(width: 24),
            const VerticalDivider(width: 1, color: _rule),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                key: const PageStorageKey('record-build'),
                child: _bestBuild(best),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bestBuild(Map<String, dynamic> best) {
    final weapon = _weapon(best['weapon'] as String? ?? '');
    final survivor = _survivor(best['survivor']);
    final arena = ArenaType.values
        .where((a) => a.name == best['arena'])
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Best run'),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 80,
              height: 48,
              child: weapon == null
                  ? const PixelIcon(PixelGlyph.crosshair)
                  : WeaponThumbnail(weapon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weapon?.title ?? best['weapon'] as String? ?? 'Weapon',
                    style: const TextStyle(
                      color: _paper,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      survivor.title,
                      if (arena != null) arena.title,
                      _clock(_count(best['seconds'])),
                    ].join(' / '),
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in _map(best['ranks']).entries)
          _BuildRow(
            art: PixelIcon(_upgrade(entry.key)?.glyph ?? PixelGlyph.star),
            title: _upgrade(entry.key)?.title ?? entry.key,
            value: _rank(entry.value),
          ),
        for (final id in best['fusions'] as List? ?? [])
          _BuildRow(
            art: const PixelIcon(PixelGlyph.star),
            title:
                fusionRecipes.where((f) => f.id == id).firstOrNull?.title ??
                '$id',
            value: '',
          ),
        for (final entry in _map(best['support']).entries)
          _BuildRow(
            art: _supportArt(entry.key),
            title: SupportCard.read(entry.key)?.title ?? entry.key,
            value: [
              if (SupportCard.read(entry.key) case final card?) card.rankLabel,
              if (_count(entry.value) > 1) '×${formatMetric(entry.value)}',
            ].join(' '),
          ),
      ],
    );
  }

  Widget _supportArt(String id) {
    final card = SupportCard.read(id);
    return card == null
        ? const PixelIcon(PixelGlyph.star)
        : SupportThumbnail(card: card, width: 40, height: 36);
  }

  Widget _usage(Map<String, dynamic> stats, {required bool weapon}) {
    final groups = weapon ? ['weapons'] : ['upgrades', 'fusions', 'support'];
    final children = <Widget>[];
    for (final group in groups) {
      final items = _map(stats[group]).entries.toList()
        ..sort((a, b) {
          final key = weapon ? 'seconds' : 'runs';
          final compared = _count(_map(b.value)[key])
              .compareTo(_count(_map(a.value)[key]));
          return compared != 0 ? compared : a.key.compareTo(b.key);
        });
      if (items.isEmpty && group != groups.first) continue;
      children.add(
        _SectionLabel(switch (group) {
          'weapons' => 'Most played',
          'upgrades' => 'Most picked',
          'fusions' => 'Fusions',
          _ => 'Support',
        }),
      );
      children.add(const SizedBox(height: 8));
      if (items.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              weapon ? 'No weapon history.' : 'No upgrade history.',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        );
      }
      for (final item in items) {
        final row = _map(item.value), gun = _weapon(item.key);
        final title = switch (group) {
          'weapons' => gun?.title ?? item.key,
          'upgrades' => _upgrade(item.key)?.title ?? item.key,
          'fusions' =>
            fusionRecipes.where((f) => f.id == item.key).firstOrNull?.title ??
                item.key,
          _ => SupportCard.read(item.key)?.title ?? item.key,
        };
        final art = switch (group) {
          'weapons' =>
            gun == null
                ? const PixelIcon(PixelGlyph.crosshair)
                : WeaponThumbnail(gun),
          'upgrades' => PixelIcon(
            _upgrade(item.key)?.glyph ?? PixelGlyph.star,
            size: 28,
          ),
          'support' => _supportArt(item.key),
          _ => const PixelIcon(PixelGlyph.star),
        };
        children.add(
          _UsageRow(
            art: art,
            title: title,
            subtitle: weapon
                ? '${_played(_count(row['seconds']))} / ${formatMetric(row['runs'] ?? 0)} runs'
                : '${formatMetric(row['runs'] ?? 0)} runs',
            value: formatMetric(row[weapon ? 'bestScore' : 'picks'] ?? 0),
            label: weapon ? 'Best score' : 'Picks',
            weapon: weapon,
          ),
        );
      }
      children.add(const SizedBox(height: 20));
    }
    return ListView(
      key: PageStorageKey(weapon ? 'record-weapons' : 'record-upgrades'),
      children: children,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    ),
  );
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({
    required this.art,
    required this.title,
    required this.value,
  });
  final Widget art;
  final String title, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 32, height: 28, child: Center(child: art)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: _paper, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: _brass,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.art,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.label,
    required this.weapon,
  });
  final Widget art;
  final String title, subtitle, value, label;
  final bool weapon;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked =
          box.maxWidth < 520 || MediaQuery.textScalerOf(context).scale(12) > 18;
      final score = Column(
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _brass,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _rule)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: weapon ? 88 : 48,
              height: 48,
              child: weapon ? art : Center(child: art),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _paper,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  if (stacked) ...[const SizedBox(height: 8), score],
                ],
              ),
            ),
            if (!stacked) ...[const SizedBox(width: 24), score],
          ],
        ),
      );
    },
  );
}
