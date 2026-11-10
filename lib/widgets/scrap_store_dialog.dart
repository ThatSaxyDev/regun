import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/scrap_store.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

/// Short landscape screens cannot show stacked pack cards at full size.
bool _shortScreen(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return !(nativeMacDesktop && size.width >= 1200 && size.height >= 680) &&
      size.height < 560;
}

Future<void> showScrapStore(
  BuildContext context, {
  bool allowSignIn = true,
}) async {
  if (!ScrapStore.supported) return;
  final account = AccountController.shared;
  await account.initialize();
  if (!context.mounted) return;
  if (allowSignIn &&
      (!account.attached || account.needsSignIn || account.conflict)) {
    if (!await showAccountFlow(context, account) || !context.mounted) return;
  }
  final owner = account.session?.accountId;
  if (owner == null || !account.attached) return;
  final tight = _shortScreen(context);
  final window = MediaQuery.sizeOf(context);
  final maxWidth =
      nativeMacDesktop && window.width >= 1200 && window.height >= 680
      ? 864.0
      : 704.0;
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: tight ? 8 : 16,
      ),
      // The notice sizes itself from its content, so on a short screen it can
      // be taller than the dialog box. Scale the whole surface down instead of
      // letting the bottom of it fall outside the screen.
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.min(maxWidth, constraints.maxWidth),
            child: _ScrapStoreDialog(owner: owner),
          ),
        ),
      ),
    ),
  );
}

class _ScrapStoreDialog extends StatefulWidget {
  const _ScrapStoreDialog({required this.owner});
  final String owner;

  @override
  State<_ScrapStoreDialog> createState() => _ScrapStoreDialogState();
}

class _ScrapStoreDialogState extends State<_ScrapStoreDialog> {
  static const _priceStyle = TextStyle(
    fontFamily: FontFam.orbitron,
    fontSize: 16,
    height: 1.4,
    color: Color(0xffE1BA78),
  );

  final _store = ScrapStore.shared;
  final _account = AccountController.shared;
  late Future<List<ScrapStoreOffer>> _offers;

  @override
  void initState() {
    super.initState();
    _offers = _store.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_store, _account]),
    builder: (context, _) {
      final window = MediaQuery.sizeOf(context);
      final roomyDesktop =
          nativeMacDesktop && window.width >= 1200 && window.height >= 680;
      final tight = _shortScreen(context);
      final sameOwner =
          _account.attached && _account.session?.accountId == widget.owner;
      return FutureBuilder(
        future: _offers,
        builder: (context, snapshot) => GameNotice(
          eyebrow: 'REGUN / WALLET',
          title: 'SCRAP STORE',
          titleSize: roomyDesktop ? 26 : (tight ? 17 : 20),
          messageSize: roomyDesktop ? 17 : (tight ? 12 : 13),
          maxWidth: roomyDesktop ? 864 : 704,
          message: !sameOwner
              ? 'Account changed. Close and reopen the store.'
              : snapshot.connectionState != ConnectionState.done
              ? 'Loading Scrap packs…'
              : snapshot.hasError
              ? (snapshot.error is AccountError
                    ? (snapshot.error! as AccountError).message
                    : 'Scrap checkout is unavailable.')
              : '${formatNumber(_account.preferences.profile.scrap)} Scrap available',
          detail: !sameOwner || !snapshot.hasData
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = roomyDesktop ? 16.0 : (tight ? 6.0 : 12.0);
                    final minPackWidth = roomyDesktop
                        ? 230.0
                        : (tight ? 170.0 : 190.0);
                    final priceStyle = roomyDesktop
                        ? _priceStyle.copyWith(fontSize: 19)
                        : tight
                        ? _priceStyle.copyWith(fontSize: 13)
                        : _priceStyle;
                    final amountSize = roomyDesktop
                        ? 23.0
                        : tight
                        ? 15.0
                        : 18.0;
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final columns =
                        ((constraints.maxWidth + gap) /
                                (minPackWidth * scale + gap))
                            .floor()
                            .clamp(1, 3);
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    final offers = snapshot.data!;
                    final enabled = !_store.busy && !_store.awaitingPayment;
                    final grid = Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final offer in offers)
                          ClickButton(
                            width: width,
                            text:
                                'Buy ${formatNumber(offer.amount)} Scrap for ${offer.label}',
                            content: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: roomyDesktop ? 8 : 0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${formatNumber(offer.amount)} Scrap',
                                    style: TextStyle(
                                      fontFamily: FontFam.orbitron,
                                      fontSize: amountSize,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                      color: const Color(0xffEEE5D4),
                                    ),
                                  ),
                                  SizedBox(height: 3 * scale),
                                  Text(
                                    offer.label,
                                    style: priceStyle,
                                  ),
                                  if (offer.alternate.isNotEmpty)
                                    Text(
                                      'or ${offer.alternate}',
                                      style: priceStyle.copyWith(
                                        fontSize:
                                            (priceStyle.fontSize ?? 13) - 2,
                                        color: priceStyle.color?.withValues(
                                          alpha: 0.62,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            onTap: enabled
                                ? () => _store.buy(offer, widget.owner)
                                : null,
                          ),
                      ],
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_store.message.isNotEmpty) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(_store.message, style: priceStyle),
                          ),
                          const SizedBox(height: 12),
                        ],
                        grid,
                      ],
                    );
                  },
                ),
          actions: GameNoticeActions(
            primary: ClickButton(
              text: 'Close',
              height: roomyDesktop ? 60 : null,
              fontSize: roomyDesktop ? 12 : null,
              onTap: () => Navigator.of(context).pop(),
            ),
            secondary: !sameOwner
                ? null
                : snapshot.hasError
                ? ClickButton(
                    text: 'Retry',
                    onTap: () => setState(() => _offers = _store.load()),
                  )
                : !_store.canRetryConfirmation
                ? null
                : ClickButton(
                    text: 'Retry confirmation',
                    onTap: _store.busy ? null : () => _store.recover(),
                  ),
          ),
        ),
      );
    },
  );
}
