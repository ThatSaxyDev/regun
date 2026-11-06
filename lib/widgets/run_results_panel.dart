import 'package:regun/desktop/desktop_platform.dart';
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
    color: desktopInputAvailable
        ? const Color(0xd9191a15)
        : const Color(0xDF100D14),
    child: SafeArea(
      minimum: desktopInputAvailable
          ? EdgeInsets.symmetric(
              horizontal: (MediaQuery.sizeOf(context).width * .05).clamp(
                16,
                112,
              ),
              vertical: 24,
            )
          : const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktopInputAvailable ? 1040 : 1100,
          ),
          child: Column(
            mainAxisSize: desktopInputAvailable
                ? MainAxisSize.min
                : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'END OF THE LINE',
                    style: TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: desktopInputAvailable ? 30 : 18,
                      height: 1.5,
                      color: _paper,
                    ),
                  ),
                  const WalletBar(showLabels: false, readOnly: true),
                ],
              ),
              if (desktopInputAvailable)
                const Divider(height: 36, color: Color(0xff756044))
              else
                const SizedBox(height: 12),
              Flexible(
                fit: desktopInputAvailable ? FlexFit.loose : FlexFit.tight,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(12) / 12;
                    final desktop = desktopInputAvailable;
                    final wide = box.maxWidth >= (desktop ? 700 : 660);
                    final summary = _summary(desktop: desktop);
                    final details = _ResultDetails(
                      desktop: desktop,
                      state: state,
                      nextGoal: nextGoal,
                      unlocks: unlocks,
                      availableHeight: wide ? box.maxHeight : null,
                      availableWidth: wide
                          ? (box.maxWidth - 28) * 4 / 9 - (desktop ? 24 : 0)
                          : box.maxWidth,
                    );
                    final content = wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: summary),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 4,
                                child: desktop
                                    ? DecoratedBox(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: Color(0xff756044),
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 24,
                                          ),
                                          child: details,
                                        ),
                                      )
                                    : details,
                              ),
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
                    final needsScroll =
                        desktop || !wide || box.maxHeight < 210 * scale;
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
              if (desktopInputAvailable)
                const Divider(height: 32, color: Color(0xff756044))
              else
                const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: ClickButton(
                      onTap: onRestart,
                      text: 'Restart',
                      width: 160,
                      height: desktopInputAvailable ? 54 : 48,
                      fontSize: desktopInputAvailable ? 13 : null,
                      buttonColor: desktopInputAvailable ? _brass : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: ClickButtonM(
                      onTap: onMenu,
                      text: 'Menu',
                      width: 140,
                      height: desktopInputAvailable ? 54 : 48,
                      fontSize: desktopInputAvailable ? 13 : null,
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

  Widget _summary({required bool desktop}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (state.causeOfDeath.isNotEmpty) ...[
        Text(
          state.causeOfDeath,
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: desktop ? 15 : 12,
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
            runSpacing: desktop ? 18 : 12,
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
                          style: TextStyle(
                            fontFamily: FontFam.pressStart,
                            fontSize: desktop ? 22 : 16,
                            height: 1.5,
                            color: desktop && item.$2 == 'SCORE'
                                ? _brass
                                : _paper,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: desktop ? 13 : 9,
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
        style: TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: desktop ? 14 : 10,
          height: 1.5,
          color: _muted,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        record,
        style: TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: desktop ? 14 : 11,
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
    required this.desktop,
    required this.nextGoal,
    required this.unlocks,
    this.availableHeight,
    required this.availableWidth,
  });
  final bool desktop;
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
    final bodySize = widget.desktop ? 15.0 : 11.0;
    final labelSize = widget.desktop ? 13.0 : 10.0;
    final goalPainter = TextPainter(
      text: TextSpan(
        text: widget.nextGoal ?? '',
        style: TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: bodySize,
          height: 1.5,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width.clamp(100, 600));
    final goalHeight = goalPainter.height;
    goalPainter.dispose();
    final remaining =
        (widget.availableHeight ?? 300 * scale) - goalHeight - 60 * scale - 48;
    final count = (remaining / ((widget.desktop ? 30 : 24) * scale))
        .floor()
        .clamp(1, 4);
    final pages = (lines.length / count).ceil().clamp(1, 100);
    final current = page.clamp(0, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.nextGoal != null) ...[
          Text(
            'NEXT GOAL',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: labelSize,
              color: _brass,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.nextGoal!,
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: bodySize,
              height: 1.5,
              color: _paper,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'RUN BUILD',
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: labelSize,
            color: _brass,
          ),
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Text(
            'No upgrades collected',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: bodySize,
              color: _muted,
            ),
          ),
        for (final line in lines.skip(current * count).take(count))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: widget.desktop ? bodySize : labelSize,
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
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: labelSize,
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
