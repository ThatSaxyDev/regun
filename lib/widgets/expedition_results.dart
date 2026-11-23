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

const _paper = Color(0xffe9e2d1);
const _muted = Color(0xffbcb8a8);
const _iron = Color(0xff555449);
const _brass = Color(0xffe1ba78);
const _rust = Color(0xffe69b82);
const _body = TextStyle(
  color: _muted,
  fontFamily: FontFam.orbitron,
  fontSize: 13,
  height: 1.4,
);
const _label = TextStyle(
  color: _muted,
  fontFamily: FontFam.orbitron,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  height: 1.4,
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
  final List<({String name, String? rank, PixelGlyph glyph})> buildEntries;
  final bool threatUnlocked, saving, saveFailed;
  final VoidCallback onReturn, onRetrySave;

  bool get _victory => run.phase == ExpeditionPhase.victory;
  Color get _accent => _victory ? _brass : _rust;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        radius: .85,
        colors: [Color(0xb5141714), Color(0xed0d100f)],
      ),
    ),
    child: SafeArea(
      minimum: const EdgeInsets.all(10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 535;
              final short = box.maxHeight < 420;
              final inset = box.maxWidth < 680 ? 16.0 : 30.0;
              final gap = box.maxWidth < 680 ? 18.0 : 34.0;
              final report = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _outcome(wide: wide, short: short),
                  SizedBox(height: short ? 12 : 23),
                  _route(short: short),
                ],
              );
              final kit = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KitPortrait(
                    loadout: loadout,
                    region: run.region,
                    short: short,
                  ),
                  SizedBox(height: short ? 12 : 18),
                  _kitLog(),
                ],
              );
              return ControllerMenuScope(
                child: Material(
                  type: MaterialType.transparency,
                  child: CustomPaint(
                    painter: _ReportFrame(_accent),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        inset,
                        short ? 12 : 27,
                        inset,
                        short ? 7 : 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: Scrollbar(
                              thumbVisibility: true,
                              thickness: 3,
                              child: SingleChildScrollView(
                                primary: true,
                                padding: EdgeInsets.only(
                                  bottom: short ? 8 : 15,
                                ),
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 9, child: report),
                                          SizedBox(width: gap),
                                          Expanded(flex: 8, child: kit),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          report,
                                          SizedBox(height: gap),
                                          kit,
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: _iron),
                          SizedBox(height: short ? 6 : 10),
                          _actions(wide: wide, short: short),
                        ],
                      ),
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

  Widget _outcome({required bool wide, required bool short}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('THREAT ${run.threat + 1}', style: _label.copyWith(color: _accent)),
      SizedBox(height: short ? 5 : 10),
      LayoutBuilder(
        builder: (context, box) {
          final preferred = wide && !short
              ? 32.0
              : short
              ? 20.0
              : 25.0;
          final scale =
              MediaQuery.textScalerOf(context).scale(preferred) / preferred;
          return Semantics(
            header: true,
            child: Text(
              _victory ? 'EXPEDITION COMPLETE' : 'EXPEDITION LOST',
              style: TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: math.min(preferred, box.maxWidth / (10.15 * scale)),
                color: _accent,
                height: 1.35,
              ),
            ),
          );
        },
      ),
      SizedBox(height: short ? 7 : 14),
      Wrap(
        spacing: short ? 17 : 27,
        runSpacing: 5,
        children: [_stat('TIME', elapsed), _stat('KILLS', '$kills')],
      ),
    ],
  );

  Widget _stat(String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: _label),
      const SizedBox(width: 6),
      Text(
        value,
        style: _body.copyWith(
          color: _paper,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  Widget _route({required bool short}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('ROUTE', style: _label),
      const SizedBox(height: 5),
      for (final region in ExpeditionRegion.values)
        _region(region, short: short),
    ],
  );

  Widget _region(ExpeditionRegion region, {required bool short}) {
    final cleared = _victory || region.index < run.region.index;
    final ended = region == run.region && !_victory;
    final marker = cleared
        ? _brass
        : ended
        ? _rust
        : _iron;
    final title = region.arena.title;
    final stage = run.bossRoom ? region.boss.title : 'Room ${run.room + 1}';
    return Semantics(
      label:
          '$title, ${cleared
              ? 'cleared'
              : ended
              ? 'run ended at $stage'
              : 'unreached'}',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _RouteTrace(
          marker: marker,
          cleared: cleared,
          ended: ended,
          incoming: region.index == 0
              ? null
              : cleared || ended
              ? _brass
              : _iron,
          outgoing: region == ExpeditionRegion.values.last
              ? null
              : cleared
              ? _brass
              : _iron,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(34, short ? 3 : 5, 0, short ? 3 : 5),
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (ended)
                  TextSpan(
                    text: '  /  $stage',
                    style: const TextStyle(
                      color: _rust,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            style: _body.copyWith(
              color: cleared || ended ? _paper : _muted,
              fontSize: short ? 13 : 14,
              fontWeight: cleared || ended ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _kitLog() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('BUILD', style: _label),
      const SizedBox(height: 7),
      if (buildEntries.isEmpty)
        const Text('No boons earned', style: _body)
      else
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final entry in buildEntries)
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PixelIcon(entry.glyph, size: 13, color: _brass),
                      ),
                    ),
                    TextSpan(text: entry.name),
                    if (entry.rank case final rank?)
                      TextSpan(
                        text: '  $rank',
                        style: const TextStyle(color: _brass),
                      ),
                  ],
                ),
                style: _body.copyWith(color: _paper),
              ),
          ],
        ),
    ],
  );

  Widget _actions({required bool wide, required bool short}) {
    final message = saving
        ? 'Saving results…'
        : saveFailed
        ? 'Results could not be saved.'
        : threatUnlocked
        ? 'Threat ${run.threat + 2} unlocked'
        : null;
    final status = message == null
        ? null
        : Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: _body.copyWith(color: saveFailed ? _rust : _brass),
            ),
          );
    final action = ClickButton(
      text: saveFailed ? 'Retry save' : 'Return to Outpost',
      glyph: saveFailed ? PixelGlyph.reload : PixelGlyph.back,
      buttonColor: _brass,
      height: short ? 44 : 49,
      width: wide ? 236 : null,
      autofocus: true,
      onTap: saving
          ? null
          : saveFailed
          ? onRetrySave
          : onReturn,
    );
    if (wide) {
      return Row(
        children: [
          Expanded(child: status ?? const SizedBox.shrink()),
          const SizedBox(width: 12),
          action,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null) ...[status, const SizedBox(height: 6)],
        action,
      ],
    );
  }
}

class _KitPortrait extends StatelessWidget {
  const _KitPortrait({
    required this.loadout,
    required this.region,
    required this.short,
  });

  final Loadout loadout;
  final ExpeditionRegion region;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final landmark = switch (region) {
      ExpeditionRegion.breach => 'district_evacuation',
      ExpeditionRegion.foundry => 'district_press',
      ExpeditionRegion.floodworks => 'district_sluice',
      ExpeditionRegion.relay => 'district_relay',
    };
    final height = short ? 86.0 : 160.0;
    final artSize = short ? 86.0 : 145.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _iron)),
        color: Color(0xff171a16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-.24, .6),
                        radius: .75,
                        colors: [Color(0xff4d4632), Color(0xff171a16)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(.86, 1),
                    child: FractionallySizedBox(
                      widthFactor: .68,
                      heightFactor: .88,
                      child: Image.asset(
                        'assets/art/arenas/$landmark.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        color: const Color(0xffa09a80),
                        colorBlendMode: BlendMode.modulate,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-.68, .9),
                    child: SizedBox.square(
                      dimension: artSize,
                      child: SurvivorPortrait(
                        character: loadout.character,
                        weapon: loadout.weapon,
                        maxArtSize: artSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: short ? 4 : 8,
            ),
            child: Text.rich(
              TextSpan(
                text: loadout.character.title.toUpperCase(),
                style: const TextStyle(
                  color: _paper,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: '  /  ${loadout.weapon.title}',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: _body,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFrame extends CustomPainter {
  const _ReportFrame(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rail = Path()
      ..moveTo(0, 0)
      ..lineTo(w - 18, 0)
      ..lineTo(w - 18, 6)
      ..lineTo(w - 9, 6)
      ..lineTo(w - 9, 12)
      ..lineTo(w, 12)
      ..lineTo(w, h)
      ..lineTo(18, h)
      ..lineTo(18, h - 6)
      ..lineTo(9, h - 6)
      ..lineTo(9, h - 12)
      ..lineTo(0, h - 12)
      ..close();
    final paint = Paint()..color = const Color(0xf51d201c);
    canvas.drawPath(rail, paint);
    paint
      ..color = _iron
      ..style = PaintingStyle.stroke;
    canvas.drawPath(rail, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = accent;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 3), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 3, 16), paint);
  }

  @override
  bool shouldRepaint(covariant _ReportFrame oldDelegate) =>
      oldDelegate.accent != accent;
}

class _RouteTrace extends CustomPainter {
  const _RouteTrace({
    required this.marker,
    required this.cleared,
    required this.ended,
    this.incoming,
    this.outgoing,
  });

  final Color marker;
  final bool cleared, ended;
  final Color? incoming, outgoing;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 12.0;
    final y = size.height / 2;
    final paint = Paint();
    if (incoming case final color?) {
      canvas.drawRect(Rect.fromLTRB(x - 1, 0, x + 1, y), paint..color = color);
    }
    if (outgoing case final color?) {
      canvas.drawRect(
        Rect.fromLTRB(x - 1, y, x + 1, size.height),
        paint..color = color,
      );
    }
    final bounds = Rect.fromCenter(center: Offset(x, y), width: 14, height: 14);
    canvas.drawRect(bounds, paint..color = marker);
    canvas.drawRect(bounds.deflate(2), paint..color = const Color(0xff1d201c));
    paint.color = marker;
    if (cleared) {
      canvas.drawRect(bounds.deflate(4), paint);
    } else if (ended) {
      paint.strokeWidth = 2;
      final mark = bounds.deflate(4);
      canvas.drawLine(mark.topLeft, mark.bottomRight, paint);
      canvas.drawLine(mark.topRight, mark.bottomLeft, paint);
    }
    canvas.drawRect(Rect.fromLTWH(x + 7, y - 1, 7, 2), paint..color = marker);
  }

  @override
  bool shouldRepaint(covariant _RouteTrace oldDelegate) =>
      marker != oldDelegate.marker ||
      cleared != oldDelegate.cleared ||
      ended != oldDelegate.ended ||
      incoming != oldDelegate.incoming ||
      outgoing != oldDelegate.outgoing;
}
