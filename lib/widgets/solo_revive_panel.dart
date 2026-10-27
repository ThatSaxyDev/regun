import 'package:regun/utils/format_number.dart';
import 'package:flutter/material.dart';
import 'package:regun/models/solo_recovery.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:regun/widgets/wallet_bar.dart';

const _paper = Color(0xffE5DDD1),
    _muted = Color(0xffB2A8B4),
    _brass = Color(0xffE1BA78);

/// The results screen's restrained sibling: one framed decision, quiet run
/// context and pinned actions. Only constrained/large-text layouts scroll.
class SoloRevivePanel extends StatelessWidget {
  const SoloRevivePanel({
    super.key,
    required this.state,
    required this.recovery,
    required this.banked,
    required this.onBuy,
    required this.onRetry,
    required this.onEnd,
    required this.onMenu,
  });
  final GameState state;
  final SoloRecovery recovery;
  final int banked;
  final VoidCallback onBuy, onRetry, onEnd, onMenu;
  bool get uncertain =>
      recovery.stage == 'requested' || recovery.stage == 'prepared';
  bool get paid => recovery.stage == 'prepared';
  bool get canBuy =>
      recovery.available &&
      banked >= SoloRecovery.price &&
      !recovery.busy &&
      !uncertain;
  Text _text(
    String text, {
    double size = 12,
    Color color = _paper,
    bool title = false,
  }) => Text(
    text,
    style: TextStyle(
      fontFamily: title ? FontFam.pressStart : FontFam.orbitron,
      fontSize: size,
      color: color,
      height: 1.5,
    ),
  );
  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: Material(
      color: const Color(0xED100D14),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, box) {
                final roomy =
                    box.maxWidth >= 580 &&
                    box.maxHeight >= 290 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _text('THIS RUN', size: 10, color: _muted),
                    const SizedBox(height: 10),
                    _text(
                      '${state.survivalSeconds ~/ 60}:${(state.survivalSeconds % 60).toString().padLeft(2, '0')}',
                      size: 24,
                      title: true,
                    ),
                    const SizedBox(height: 8),
                    _text(
                      '${formatNumber(state.kills)} kills  /  ${formatNumber(state.bosses)} bosses',
                      color: _muted,
                    ),
                    const SizedBox(height: 10),
                    _text(
                      state.causeOfDeath.isEmpty
                          ? 'Your build is held.'
                          : state.causeOfDeath,
                      color: _muted,
                    ),
                  ],
                );
                final offer = CustomPaint(
                  painter: const GameNoticeFrame(),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _text(
                          paid
                              ? 'RETURN CONFIRMED'
                              : uncertain
                              ? 'CONFIRMING YOUR RETURN'
                              : 'SECOND WIND',
                          size: 14,
                          title: true,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const PixelIcon(
                              PixelGlyph.shards,
                              color: _brass,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            _text(
                              '${formatNumber(SoloRecovery.price)} SCRAP',
                              size: 16,
                              color: _brass,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _text(
                                paid
                                    ? 'Spent once'
                                    : canBuy
                                    ? '${walletAmount(banked - SoloRecovery.price)} left'
                                    : '${walletAmount(banked)} banked',
                                size: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _text(
                          uncertain
                              ? 'Checking your spend. Retrying will not charge twice.'
                              : 'Keep your build. Half health. Full ammo.',
                          size: 12,
                        ),
                        const SizedBox(height: 6),
                        _text(
                          recovery.busy
                              ? (uncertain
                                    ? 'Confirming with the server…'
                                    : 'Checking connection…')
                              : recovery.message.isNotEmpty &&
                                    !recovery.available
                              ? recovery.message
                              : 'One revive this run.',
                          size: 11,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                );
                final content = roomy
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 2, child: summary),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: offer),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [summary, const SizedBox(height: 16), offer],
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _text('END OF THE LINE', size: 17, title: true),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PixelIcon(
                              PixelGlyph.shards,
                              color: _brass,
                              size: 13,
                            ),
                            const SizedBox(width: 8),
                            _text(walletAmount(banked), color: _brass),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: roomy
                          ? Center(child: content)
                          : SingleChildScrollView(child: content),
                    ),
                    const SizedBox(height: 12),
                    GameNoticeActions(
                      primary: ClickButton(
                        text: recovery.busy
                            ? 'CHECKING…'
                            : canBuy
                            ? 'REVIVE · ${formatNumber(SoloRecovery.price)}'
                            : paid
                            ? 'RESUME'
                            : 'RETRY CONNECTION',
                        buttonColor: _brass,
                        onTap: recovery.busy
                            ? null
                            : canBuy
                            ? onBuy
                            : onRetry,
                      ),
                      secondary: ClickButton(
                        text: 'END RUN',
                        buttonColor: const Color(0xff817783),
                        onTap: recovery.busy && uncertain ? null : onEnd,
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          child: InkWell(
                            onTap: recovery.busy ? null : onMenu,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: _text(
                                'Save & menu',
                                size: 11,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
