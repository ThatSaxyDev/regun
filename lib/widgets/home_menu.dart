import 'package:regun/desktop/controller_menu.dart';
import 'package:regun/desktop/desktop_display.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/widgets/wallet_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/services/mac_store_promo.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/theme/menu_focus.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:url_launcher/url_launcher.dart';

import 'online_coming_soon.dart';
import 'app_build_label.dart';
import 'home_artwork.dart';

/// Home navigation and the shelter backdrop.
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
    this.onLeaderboards,
    this.onContinue,
    this.bestScore = 0,
    this.onlineAvailable = false,
    this.onlineChecking = false,
    this.pushPrompt,
  });
  final bool ready, reducedMotion, onlineAvailable, onlineChecking;
  final int bestScore;
  final VoidCallback onPlay, onOnline, onTraining, onCollection, onSettings;
  final VoidCallback? onContinue, onLeaderboards;

  /// One-time notification offer. It shares the leaderboards row so the menu
  /// does not grow a new block; the leaderboards button keeps its place below.
  final Widget? pushPrompt;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final desktop = desktopInputAvailable;
      final desktopMenu =
          desktop && box.maxWidth >= 680 && box.maxWidth >= box.maxHeight;
      final portrait = box.maxHeight > box.maxWidth;
      final compact = box.maxHeight < 440;
      final panelWidth = portrait
          ? 440.0
          : desktopMenu
          ? (box.maxWidth * .28).clamp(280.0, 360.0)
          : (box.maxWidth * .48).clamp(290.0, 470.0);
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final reduced = reducedMotion || MediaQuery.disableAnimationsOf(context);
      final online = _HomeAction(
        label: 'Online',
        quiet: desktopMenu,
        detail: onlineChecking
            ? 'CHECKING…'
            : onlineAvailable
            ? 'CO-OP / VERSUS'
            : 'COMING SOON',
        muted: !onlineAvailable,
        onTap: !ready || onlineChecking
            ? null
            : onlineAvailable
            ? onOnline
            : () => showOnlineComingSoon(context),
      );
      final leaderboards = _HomeAction(
        label: 'Leaderboards',
        quiet: desktopMenu,
        onTap: ready ? onLeaderboards : null,
      );
      final play = _HomeAction(
        label: ready ? 'Play' : 'Loading',
        primary: onContinue == null,
        quiet: desktopMenu && onContinue != null,
        onTap: ready ? onPlay : null,
      );
      final training = _HomeAction(
        label: 'Training',
        utility: !desktopMenu,
        quiet: desktopMenu,
        onTap: ready ? onTraining : null,
      );
      final collection = _HomeAction(
        label: 'Collection',
        utility: !desktopMenu,
        quiet: desktopMenu,
        onTap: ready ? onCollection : null,
      );
      final settings = _HomeAction(
        key: const Key('home-settings'),
        label: 'Settings',
        utility: true,
        gear: !desktopMenu,
        quiet: desktopMenu,
        onTap: ready ? onSettings : null,
      );
      final exit = _HomeAction(
        label: 'Exit',
        utility: true,
        quiet: desktopMenu,
        onTap: () async {
          final confirmed = await confirmRunAction(
            context,
            eyebrow: 'RE-GUN',
            title: 'EXIT REGUN?',
            message: 'Close the game and return to your desktop.',
            action: 'Exit',
          );
          if (confirmed && context.mounted) {
            await quitDesktopApp();
          }
        },
      );
      final navigation = SizedBox(
        width: panelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'REGUN',
              key: const Key('home-title'),
              style: TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: compact
                    ? 24
                    : desktop && !portrait
                    ? (panelWidth * .13).clamp(36, 58)
                    : 34,
                height: 1.3,
                letterSpacing: 3,
                color: const Color(0xffeee5d4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'NO QUIET WAY OUT.',
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: desktopMenu ? 12 : 10,
                letterSpacing: 2,
                color: const Color(0xffb5aa96),
              ),
            ),
            SizedBox(height: compact ? 12 : (desktopMenu ? 20 : 28)),
            if (desktopMenu) ...[
              if (onContinue != null) ...[
                _HomeAction(
                  label: 'Continue',
                  primary: true,
                  onTap: ready ? onContinue : null,
                ),
                const SizedBox(height: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 5,
                children: [
                  play,
                  online,
                  training,
                  collection,
                  if (pushPrompt != null)
                    pushPrompt!
                  else if (onLeaderboards != null)
                    leaderboards,
                ],
              ),
              const Divider(height: 20, color: Color(0x667d6856)),
              Row(
                spacing: 8,
                children: [
                  Expanded(child: settings),
                  if (nativeMacDesktop)
                    Expanded(child: exit)
                  else
                    const Spacer(),
                ],
              ),
            ] else ...[
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
                  Expanded(child: play),
                ],
              ),
              const SizedBox(height: 10),
              online,
              if (pushPrompt != null) ...[
                const SizedBox(height: 10),
                pushPrompt!,
              ] else if (onLeaderboards != null) ...[
                const SizedBox(height: 10),
                leaderboards,
              ],
              SizedBox(height: compact ? 10 : 22),
              Row(
                spacing: 8,
                children: [
                  Expanded(child: training),
                  Expanded(child: collection),
                  settings,
                ],
              ),
              if (nativeMacDesktop) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 100, child: exit),
                ),
              ],
            ],
          ],
        ),
      );
      // Large text deliberately switches to a scrollable composition rather than
      // shrinking touch targets or letting the title disappear behind a mask.
      // The Mac download adds height in the scroll case and needs clearance in
      // the stacked case, so the threshold accounts for it.
      final macPromo = macStorePromoAvailable;
      final scroll =
          portrait ||
          box.maxHeight < (desktop ? 540 : 360) + (macPromo ? 96 : 0) ||
          scale > 1.25;
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
                horizontal: desktop && !portrait
                    ? (box.maxWidth * .065).clamp(24, 128)
                    : box.maxWidth > 700
                    ? 32
                    : 8,
              ),
              child: Column(
                children: [
                  if (portrait) ...[
                    const WalletBar(),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: macStorePromoDismissed,
                      builder: (context, dismissed, _) {
                        final showPromo = macPromo && !dismissed;
                        if (scroll) {
                          return SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: portrait ? 220 : 12,
                                bottom: 20,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    navigation,
                                    if (showPromo) ...[
                                      SizedBox(height: compact ? 16 : 24),
                                      SizedBox(
                                        width: panelWidth,
                                        child: const _MacStorePromo(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        // The column keeps its exact centred position. The Mac
                        // download is layered into the free space beneath it
                        // rather than joining the column, so no existing action
                        // moves. The scroll threshold above guarantees the two
                        // cannot meet.
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: navigation,
                            ),
                            if (showPromo)
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: SizedBox(
                                  width: panelWidth,
                                  child: const _MacStorePromo(),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Three zones so each keeps its intended position: score at
                  // the left edge, the support link centred, build label at the
                  // right edge. The two Expanded zones are equal, which is what
                  // centres the middle child in the row.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bestScore > 0
                              ? 'BEST  ${formatNumber(bestScore)}'
                              : '',
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 8,
                            letterSpacing: 1.4,
                            color: Color(0xff7f918e),
                          ),
                        ),
                      ),
                      // Web only. `kIsWeb` is false on macOS, iOS and Android,
                      // so no native build can ever route a player to an
                      // external payment page.
                      if (kIsWeb) const _SupportRegun(),
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AppBuildLabel(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!portrait)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(0, 16, 24, 0),
                child: SizedBox(
                  width: (box.maxWidth - panelWidth - 88).clamp(128.0, 400.0),
                  child: const WalletBar(),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _HomeAction extends ConsumerStatefulWidget {
  const _HomeAction({
    super.key,
    required this.label,
    this.detail,
    this.onTap,
    this.primary = false,
    this.utility = false,
    this.gear = false,
    this.muted = false,
    this.quiet = false,
  });
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool primary, utility, gear, muted, quiet;
  @override
  ConsumerState<_HomeAction> createState() => _HomeActionState();
}

class _HomeActionState extends ConsumerState<_HomeAction> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  void didUpdateWidget(_HomeAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final controller = ControllerMenuMode.of(context);
    final ink = widget.muted
        ? const Color(0xff99979c)
        : widget.primary || widget.gear
        ? const Color(0xffedd2a1)
        : const Color(0xffd4c9b7);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.muted ? '${widget.label}, coming soon' : widget.label,
      child: Tooltip(
        message: widget.gear ? widget.label : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: enabled,
            autofocus: desktopInputAvailable && widget.primary && enabled,
            onTap: !enabled
                ? null
                : () {
                    ref.read(soloudPlayProvider).play('click.mp3');
                    widget.onTap!();
                  },
            onHover: desktopInputAvailable
                ? (value) => setState(() => _hovered = value)
                : null,
            onFocusChange: desktopInputAvailable
                ? (value) => setState(() => _focused = value)
                : null,
            onTapDown: !enabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: CustomPaint(
              painter: _HomePlate(
                primary: widget.primary,
                quiet: widget.quiet,
                utility: widget.utility,
                pressed: _pressed,
                enabled: enabled && !widget.muted,
                highlighted: enabled && _hovered && !controller,
                focused: enabled && _focused,
              ),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: desktopInputAvailable
                      ? (widget.quiet ? 36 : 48)
                      : (widget.utility ? 48 : 54),
                ),
                width: widget.gear ? 48 : null,
                padding: EdgeInsets.symmetric(
                  horizontal: desktopInputAvailable
                      ? (widget.primary ? 16 : 12)
                      : widget.utility
                      ? 12
                      : 20,
                  vertical: desktopInputAvailable ? 8 : 12,
                ),
                child: Transform.translate(
                  offset: Offset(0, _pressed ? 1 : -1),
                  child: Opacity(
                    opacity: enabled ? 1 : .4,
                    child: widget.gear
                        ? Center(
                            child: CustomPaint(
                              size: const Size(22, 22),
                              painter: _SettingsGlyph(ink),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: widget.utility
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.label.toUpperCase(),
                                  textAlign: widget.utility
                                      ? TextAlign.center
                                      : TextAlign.left,
                                  maxLines: desktopInputAvailable ? 1 : null,
                                  overflow: desktopInputAvailable
                                      ? TextOverflow.ellipsis
                                      : null,
                                  style: TextStyle(
                                    fontFamily: widget.utility
                                        ? FontFam.orbitron
                                        : FontFam.pressStart,
                                    fontSize:
                                        desktopInputAvailable && widget.primary
                                        ? 13
                                        : widget.utility
                                        ? 11
                                        : 10,
                                    height: 1.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .5,
                                    color: ink,
                                  ),
                                ),
                              ),
                              if (widget.detail != null &&
                                  scale <= 1.25 &&
                                  (!desktopInputAvailable || widget.quiet)) ...[
                                const SizedBox(width: 12),
                                Text(
                                  widget.detail!,
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
        ),
      ),
    );
  }
}

/// The same stepped iron construction as Regun's in-game controls, with a
/// recessed face, worn highlights and brass fasteners rather than flat slabs.
class _HomePlate extends CustomPainter {
  const _HomePlate({
    required this.primary,
    required this.utility,
    required this.pressed,
    required this.enabled,
    required this.highlighted,
    required this.focused,
    required this.quiet,
  });
  final bool primary, utility, pressed, enabled, highlighted, focused, quiet;

  @override
  void paint(Canvas canvas, Size size) {
    if (quiet && !highlighted && !pressed && !focused) return;
    final face = Rect.fromLTWH(
      1,
      pressed ? 3 : 0,
      size.width - 2,
      size.height - 4,
    );
    final paint = Paint()..isAntiAlias = false;
    final rim = highlighted
        ? const Color(0xfff4d8a5)
        : primary
        ? const Color(0xffbd9762)
        : const Color(0xff71604f);
    canvas.drawPath(
      controlPlate(face.shift(const Offset(0, 4))),
      paint..color = const Color(0xff0c0a0e),
    );
    canvas.drawPath(controlPlate(face), paint..color = const Color(0xff141116));
    canvas.drawPath(
      controlPlate(face.deflate(1)),
      paint..color = rim.withValues(alpha: enabled || highlighted ? 1 : .35),
    );
    final inner = face.deflate(3);
    canvas.drawPath(
      controlPlate(inner, cut: 4),
      paint
        ..color = pressed
            ? const Color(0xff211b20)
            : highlighted
            ? const Color(0xff564337)
            : !enabled
            ? const Color(0xff242327)
            : primary
            ? const Color(0xff49382e)
            : focused
            ? const Color(0xff352c26)
            : utility
            ? const Color(0xff252027)
            : const Color(0xff30272e),
    );
    canvas.save();
    canvas.clipPath(controlPlate(inner, cut: 4));
    // A recessed lower edge, a caught top lip and short breaks in the finish.
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.bottom - 4, inner.width, 4),
      paint..color = const Color(0xff191419),
    );
    canvas.drawRect(
      Rect.fromLTWH(inner.left + 5, inner.top, inner.width - 10, 1),
      paint
        ..color = primary ? const Color(0xff896c4e) : const Color(0xff57474a),
    );
    for (var i = 0; i < (size.width / 5).floor(); i++) {
      final x = inner.left + (i * 37 % inner.width);
      final y = inner.top + (i * 17 % inner.height);
      canvas.drawRect(
        Rect.fromLTWH(x, y, i % 4 == 0 ? 3 : 1, 1),
        paint
          ..color = i.isEven
              ? const Color(0x146f6157)
              : const Color(0x220b090d),
      );
    }
    if (primary) {
      canvas.drawRect(
        Rect.fromLTWH(inner.left + 4, inner.top + 10, 2, inner.height - 20),
        paint..color = const Color(0xffc39b61),
      );
    }
    canvas.restore();
    // Tiny square pins sit in the rim; they don't compete with button labels.
    for (final x in [face.left + 7, face.right - 9]) {
      canvas.drawRect(
        Rect.fromLTWH(x, face.center.dy - 1, 2, 2),
        paint..color = rim.withValues(alpha: enabled ? .9 : .3),
      );
    }
    if (focused) {
      paintMenuFocus(canvas, face);
    }
  }

  @override
  bool shouldRepaint(_HomePlate oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.quiet != quiet ||
      oldDelegate.utility != utility ||
      oldDelegate.pressed != pressed ||
      oldDelegate.enabled != enabled ||
      oldDelegate.focused != focused ||
      oldDelegate.highlighted != highlighted;
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

/// Web-only way to back the project.
///
/// Sits in the low-priority meta row beside the build label, in the same
/// Orbitron/muted treatment, so it never competes with Play. Opens in a new tab
/// so the running game is never navigated away from; `kIsWeb` at the call site
/// keeps every native build free of an external payment link.
class _SupportRegun extends StatelessWidget {
  const _SupportRegun();

  static final _url = Uri.parse(
    'https://checkout.bachs.io/pay/pl_078cbeae14f3',
  );

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: 'Support Regun development, opens in a new tab',
    child: TextButton(
      onPressed: () => launchUrl(
        _url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      ),
      style: TextButton.styleFrom(
        // 44px keeps the target usable even though the label is 10pt meta text.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: const Color(0xff7f918e),
        overlayColor: const Color(0xffedd2a1),
        textStyle: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 10,
          height: 1.4,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text(
        'SUPPORT REGUN',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    ),
  );
}

/// Web-only prompt offering the released macOS build to Mac visitors.
///
/// Deliberately not one of the `_HomeAction` plates: those are the game's
/// actions, and a store link sitting among Play and Continue would read as one.
/// This is a quieter, bordered card that hangs in the empty space beneath the
/// column, using the same palette and cut corners so it belongs to the screen
/// without joining the menu.
///
/// Never shown outside a browser on a Mac — see `mac_store_promo_stub.dart`.
class _MacStorePromo extends ConsumerStatefulWidget {
  const _MacStorePromo();

  @override
  ConsumerState<_MacStorePromo> createState() => _MacStorePromoState();
}

class _MacStorePromoState extends ConsumerState<_MacStorePromo> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    // Grow with the text scale instead of clipping, capped so a large system
    // font cannot turn this into a wall.
    final pad = (12 * scale).clamp(12.0, 20.0);
    return Semantics(
      link: true,
      label: 'Get Regun for Mac on the Mac App Store, opens in a new tab',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (context.mounted) ref.read(soloudPlayProvider).play('click.mp3');
            launchUrl(
              Uri.parse(macAppStoreUrl),
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
          },
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: CustomPaint(
            painter: _MacStorePlate(
              pressed: _pressed,
              highlighted: _hovered || _focused,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad + 2, pad * .8, pad, pad * .8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MAC APP STORE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 8,
                            height: 1.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffc39b61),
                          ),
                        ),
                        SizedBox(height: 2 * scale),
                        const Text(
                          'Get Regun for Mac',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 12,
                            height: 1.4,
                            letterSpacing: .4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffeee5d4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  // Dismiss is its own gesture area, so a tap here can never
                  // also open the store. In-memory only: it lasts until the page
                  // is reloaded, which keeps it gone when returning from a run
                  // while still offering the app on a fresh visit.
                  Semantics(
                    button: true,
                    label: 'Dismiss Mac App Store suggestion',
                    child: InkWell(
                      excludeFromSemantics: true,
                      onFocusChange: (focused) =>
                          setState(() => _closeHovered = focused),
                      onTap: dismissMacStorePromo,
                      onTapDown: (_) => setState(() => _closeHovered = true),
                      onTapCancel: () => setState(() => _closeHovered = false),
                      onTapUp: (_) => setState(() => _closeHovered = false),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(
                          child: Text(
                            '✕',
                            style: TextStyle(
                              fontFamily: FontFam.orbitron,
                              fontSize: 11,
                              height: 1.2,
                              color: _closeHovered
                                  ? const Color(0xffeee5d4)
                                  : const Color(0xff7f918e),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Transform.translate(
                    offset: Offset(0, _pressed ? 1 : -1),
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CustomPaint(
                        painter: _OutboundArrow(
                          _hovered || _focused
                              ? const Color(0xfff4d8a5)
                              : const Color(0xffc39b61),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered card with the same cut corners as the control plates, plus a gold
/// edge bar so it reads as a way out to the store rather than another menu row.
class _MacStorePlate extends CustomPainter {
  const _MacStorePlate({required this.pressed, required this.highlighted});

  final bool pressed;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final face = (Offset.zero & size).deflate(.5);
    final path = controlPlate(face, cut: 7);
    canvas.drawPath(
      path,
      Paint()
        ..color = pressed
            ? const Color(0xff241d24)
            : const Color(0xff1d1720).withValues(alpha: .84),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = highlighted
            ? const Color(0xff896c4e)
            : const Color(0xff4d3f3d),
    );
    // Accent bar on the left edge, inset so the cut corners stay visible.
    canvas.drawRect(
      Rect.fromLTWH(face.left + 4, face.top + 10, 2, face.height - 20),
      Paint()..color = const Color(0xffc39b61),
    );
  }

  @override
  bool shouldRepaint(_MacStorePlate oldDelegate) =>
      oldDelegate.pressed != pressed || oldDelegate.highlighted != highlighted;
}

/// The "leaves this app" arrow: a frame with a diagonal arrow breaking out of
/// its top-right corner.
///
/// Drawn rather than typed. The `↗` glyph renders as whatever the platform's
/// fallback font supplies — an emoji on some systems — which reads as cheap
/// next to the pixel-art plates. This is stroke geometry on a 16-unit grid, so
/// it stays crisp at any size and matches the gold used elsewhere.
class _OutboundArrow extends CustomPainter {
  const _OutboundArrow(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    // The frame, open at the top-right so the arrow appears to leave it.
    canvas.drawPath(
      Path()
        ..moveTo(1.5, 6.5)
        ..lineTo(1.5, 14.5)
        ..lineTo(9.5, 14.5)
        ..lineTo(9.5, 9.5),
      paint,
    );
    // The arrow: shaft plus head.
    canvas.drawPath(
      Path()
        ..moveTo(7.5, 8.5)
        ..lineTo(14.5, 1.5)
        ..moveTo(9.5, 1.5)
        ..lineTo(14.5, 1.5)
        ..lineTo(14.5, 6.5),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutboundArrow oldDelegate) => color != oldDelegate.color;
}
