import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/utils/soloud_play.dart';

import 'app_build_label.dart';
import 'home_artwork.dart';

/// Home navigation stays in two action rows, even with a suspended run.
class HomeMenu extends StatelessWidget {
  const HomeMenu({
    super.key,
    required this.ready,
    required this.reducedMotion,
    required this.onPlay,
    required this.onOnline,
    required this.onTraining,
    required this.onCollection,
    required this.onSettings,
    this.onContinue,
    this.bestScore = 0,
  });
  final bool ready, reducedMotion;
  final int bestScore;
  final VoidCallback onPlay, onOnline, onTraining, onCollection, onSettings;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final portrait = box.maxHeight > box.maxWidth;
      final compact = box.maxHeight < 360;
      final panelWidth = portrait
          ? 440.0
          : (box.maxWidth * .48).clamp(290.0, 470.0);
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final reduced = reducedMotion || MediaQuery.disableAnimationsOf(context);
      final navigation = SizedBox(
        width: panelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'REGUN',
              key: Key('home-title'),
              style: TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: 34,
                height: 1.3,
                letterSpacing: 3,
                color: Color(0xffeee5d4),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'NO QUIET WAY OUT.',
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 10,
                letterSpacing: 2,
                color: Color(0xffb5aa96),
              ),
            ),
            SizedBox(height: compact ? 12 : 28),
            Row(
              children: [
                if (onContinue != null) ...[
                  Expanded(
                    child: _HomeAction(
                      label: 'Continue',
                      primary: true,
                      onTap: ready ? onContinue : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _HomeAction(
                    label: ready ? 'Play' : 'Loading',
                    primary: onContinue == null,
                    onTap: ready ? onPlay : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _HomeAction(
              label: 'Online',
              detail: 'CO-OP / VERSUS',
              onTap: ready ? onOnline : null,
            ),
            SizedBox(height: compact ? 10 : 22),
            Row(
              children: [
                Expanded(
                  child: _HomeAction(
                    label: 'Training',
                    utility: true,
                    onTap: ready ? onTraining : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HomeAction(
                    label: 'Collection',
                    utility: true,
                    onTap: ready ? onCollection : null,
                  ),
                ),
                const SizedBox(width: 8),
                _HomeAction(
                  key: const Key('home-settings'),
                  label: 'Settings',
                  utility: true,
                  gear: true,
                  onTap: ready ? onSettings : null,
                ),
              ],
            ),
          ],
        ),
      );
      // Large text deliberately switches to a scrollable composition rather than
      // shrinking touch targets or letting the title disappear behind a mask.
      final scroll = portrait || box.maxHeight < 260 || scale > 1.25;
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff171319)),
          Positioned.fill(
            left: portrait ? -160 : box.maxWidth * .25,
            bottom: portrait ? box.maxHeight * .38 : 0,
            child: HomeArtwork(reducedMotion: reduced),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xff171319),
                    const Color(0xff171319).withValues(alpha: .97),
                    const Color(0xff171319).withValues(alpha: .1),
                    const Color(0xff171319).withValues(alpha: .05),
                  ],
                  stops: const [0, .30, .65, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth > 700 ? 32 : 8,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: scroll
                        ? SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: portrait ? 220 : 12,
                                bottom: 20,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: navigation,
                              ),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: navigation,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        bestScore > 0 ? 'BEST  $bestScore' : '',
                        style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: 8,
                          letterSpacing: 1.4,
                          color: Color(0xff7f918e),
                        ),
                      ),
                      const Spacer(),
                      const AppBuildLabel(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _HomeAction extends ConsumerWidget {
  const _HomeAction({
    super.key,
    required this.label,
    this.detail,
    this.onTap,
    this.primary = false,
    this.utility = false,
    this.gear = false,
  });
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool primary, utility, gear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = primary ? const Color(0xff182024) : const Color(0xffe3dbc9);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Tooltip(
        message: gear ? label : '',
        child: Material(
          color: utility
              ? Colors.transparent
              : primary
              ? const Color(0xffd1b17b)
              : const Color(0xff30292f),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    ref.read(soloudPlayProvider).play('click.mp3');
                    onTap!();
                  },
            splashColor: ink.withValues(alpha: .12),
            child: Container(
              constraints: BoxConstraints(minHeight: utility ? 48 : 54),
              width: gear ? 48 : null,
              padding: EdgeInsets.symmetric(
                horizontal: utility ? 4 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: primary
                        ? const Color(0xfff1d4a3)
                        : const Color(0xff655651),
                    width: primary ? 3 : 1,
                  ),
                ),
              ),
              child: Opacity(
                opacity: onTap == null ? .4 : 1,
                child: gear
                    ? Center(
                        child: CustomPaint(
                          size: const Size(22, 22),
                          painter: _SettingsGlyph(ink),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: utility
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              label.toUpperCase(),
                              textAlign: utility
                                  ? TextAlign.center
                                  : TextAlign.left,
                              style: TextStyle(
                                fontFamily: utility
                                    ? FontFam.orbitron
                                    : FontFam.pressStart,
                                fontSize: utility ? 11 : 10,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: ink,
                              ),
                            ),
                          ),
                          if (detail != null && scale <= 1.25) ...[
                            const SizedBox(width: 12),
                            Text(
                              detail!,
                              style: TextStyle(
                                fontFamily: FontFam.orbitron,
                                fontSize: 8,
                                letterSpacing: .6,
                                color: ink.withValues(alpha: .6),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGlyph extends CustomPainter {
  const _SettingsGlyph(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      paintPixelGlyph(canvas, Offset.zero & size, PixelGlyph.settings, color);
  @override
  bool shouldRepaint(_SettingsGlyph oldDelegate) => color != oldDelegate.color;
}
