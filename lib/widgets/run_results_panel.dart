import 'package:regun/utils/format_number.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:flutter/material.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/wallet_bar.dart';

const _paper = Color(0xffE5DDD1);
const _muted = Color(0xffB2A8B4);
const _brass = Color(0xffE1BA78);

/// Uses landscape width; navigation stays outside the small-screen scroll area.
class RunResultsPanel extends StatelessWidget {
  const RunResultsPanel({
    super.key,
    required this.state,
    required this.earnedScrap,
    required this.scrapBreakdown,
    required this.record,
    required this.unlocks,
    required this.onRestart,
    required this.onMenu,
    this.nextGoal,
  });
  final GameState state;
  final int earnedScrap;
  final String scrapBreakdown, record;
  final String? nextGoal;
  final List<String> unlocks;
  final VoidCallback onRestart, onMenu;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xDF100D14),
    child: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'END OF THE LINE',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 18,
                      height: 1.5,
                      color: _paper,
                    ),
                  ),
                  WalletBar(showLabels: false),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(12) / 12;
                    final wide = box.maxWidth >= 660;
                    final summary = _summary();
                    final details = _ResultDetails(
                      state: state,
                      nextGoal: nextGoal,
                      unlocks: unlocks,
                      availableHeight: wide ? box.maxHeight : null,
                      availableWidth: wide
                          ? (box.maxWidth - 28) * 4 / 9
                          : box.maxWidth,
                    );
                    final content = wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: summary),
                              const SizedBox(width: 28),
                              Expanded(flex: 4, child: details),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              const SizedBox(height: 20),
                              details,
                            ],
                          );
                    // Large text reduces the usable viewport just like a smaller screen.
                    final needsScroll = !wide || box.maxHeight < 210 * scale;
                    if (needsScroll) {
                      return SingleChildScrollView(
                        key: const Key('results-small-screen-scroll'),
                        child: content,
                      );
                    }
                    return content;
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: ClickButton(
                      onTap: onRestart,
                      text: 'Restart',
                      width: 160,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: ClickButtonM(
                      onTap: onMenu,
                      text: 'Menu',
                      width: 140,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (state.causeOfDeath.isNotEmpty) ...[
        Text(
          state.causeOfDeath,
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 12,
            height: 1.4,
            color: _muted,
          ),
        ),
        const SizedBox(height: 12),
      ],
      LayoutBuilder(
        builder: (context, box) {
          final columns = MediaQuery.textScalerOf(context).scale(16) > 20
              ? 2
              : 3;
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final item in [
                (
                  '${state.survivalSeconds ~/ 60}:${(state.survivalSeconds % 60).toString().padLeft(2, '0')}',
                  'SURVIVED',
                ),
                (formatNumber(state.kills), 'KILLS'),
                (formatNumber(state.bosses), 'BOSSES'),
                (formatNumber(state.score), 'SCORE'),
                ('+${formatNumber(earnedScrap)}', 'THIS RUN SCRAP'),
              ])
                SizedBox(
                  width: (box.maxWidth - 16 * (columns - 1)) / columns,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontFamily: FontFam.pressStart,
                            fontSize: 16,
                            height: 1.5,
                            color: _paper,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: 9,
                          height: 1.4,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Text(
        scrapBreakdown,
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 10,
          height: 1.5,
          color: _muted,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        record,
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 11,
          height: 1.5,
          color: _brass,
        ),
      ),
    ],
  );
}

class _ResultDetails extends StatefulWidget {
  const _ResultDetails({
    required this.state,
    required this.nextGoal,
    required this.unlocks,
    this.availableHeight,
    required this.availableWidth,
  });
  final double? availableHeight;
  final double availableWidth;
  final GameState state;
  final String? nextGoal;
  final List<String> unlocks;
  @override
  State<_ResultDetails> createState() => _ResultDetailsState();
}

class _ResultDetailsState extends State<_ResultDetails> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final reward in widget.unlocks) 'Unlocked: $reward',
      for (final entry in widget.state.ranks.entries)
        '${entry.key.title} ${entry.value}',
      for (final id in widget.state.evolutions)
        fusionRecipes.where((r) => r.id == id).firstOrNull?.title ?? id,
    ];
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final width = widget.availableWidth;
    final goalPainter = TextPainter(
      text: TextSpan(
        text: widget.nextGoal ?? '',
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 11,
          height: 1.5,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width.clamp(100, 600));
    final remaining =
        (widget.availableHeight ?? 300 * scale) -
        goalPainter.height -
        60 * scale -
        48;
    final count = (remaining / (24 * scale)).floor().clamp(1, 4);
    final pages = (lines.length / count).ceil().clamp(1, 100);
    final current = page.clamp(0, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.nextGoal != null) ...[
          const Text(
            'NEXT GOAL',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 10,
              color: _brass,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.nextGoal!,
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              height: 1.5,
              color: _paper,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'RUN BUILD',
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 10,
            color: _brass,
          ),
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          const Text(
            'No upgrades collected',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              color: _muted,
            ),
          ),
        for (final line in lines.skip(current * count).take(count))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 10,
                height: 1.5,
                color: _muted,
              ),
            ),
          ),
        if (pages > 1)
          Row(
            children: [
              IconButton(
                tooltip: 'Previous build page',
                onPressed: current == 0
                    ? null
                    : () => setState(() => page = current - 1),
                icon: PixelIcon(
                  PixelGlyph.back,
                  size: 16,
                  color: current == 0 ? _muted : _brass,
                ),
              ),
              Text(
                '${current + 1} / $pages',
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 10,
                  color: _muted,
                ),
              ),
              IconButton(
                tooltip: 'Next build page',
                onPressed: current == pages - 1
                    ? null
                    : () => setState(() => page = current + 1),
                icon: RotatedBox(
                  quarterTurns: 2,
                  child: PixelIcon(
                    PixelGlyph.back,
                    size: 16,
                    color: current == pages - 1 ? _muted : _brass,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
