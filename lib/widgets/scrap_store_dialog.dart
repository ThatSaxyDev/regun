import 'package:flutter/material.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/apple_scrap_store.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

Future<void> showScrapStore(
  BuildContext context, {
  bool allowSignIn = true,
}) async {
  if (!AppleScrapStore.supported) return;
  final account = AccountController.shared;
  await account.initialize();
  if (!context.mounted) return;
  if (allowSignIn &&
      (!account.attached || account.needsSignIn || account.conflict)) {
    if (!await showAccountFlow(context, account) || !context.mounted) return;
  }
  final owner = account.session?.accountId;
  if (owner == null || !account.attached) return;
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: _ScrapStoreDialog(owner: owner),
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

  final _store = AppleScrapStore.shared;
  final _account = AccountController.shared;
  late Future<List<({int amount, ProductDetails product})>> _offers;

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
      final sameOwner =
          _account.attached && _account.session?.accountId == widget.owner;
      return FutureBuilder(
        future: _offers,
        builder: (context, snapshot) => GameNotice(
          eyebrow: 'REGUN / WALLET',
          title: 'SCRAP STORE',
          titleSize: roomyDesktop ? 26 : 20,
          messageSize: roomyDesktop ? 17 : 13,
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
                    final gap = roomyDesktop ? 16.0 : 12.0;
                    final minPackWidth = roomyDesktop ? 230.0 : 190.0;
                    final priceStyle = roomyDesktop
                        ? _priceStyle.copyWith(fontSize: 19)
                        : _priceStyle;
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final columns =
                        ((constraints.maxWidth + gap) /
                                (minPackWidth * scale + gap))
                            .floor()
                            .clamp(1, 3);
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    final enabled = !_store.busy && !_store.awaitingPayment;
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
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final offer in snapshot.data!)
                              ClickButton(
                                width: width,
                                text:
                                    'Buy ${formatNumber(offer.amount)} Scrap for ${offer.product.price}',
                                content: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: roomyDesktop ? 8 : 0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${formatNumber(offer.amount)} Scrap',
                                        style: TextStyle(
                                          fontFamily: FontFam.orbitron,
                                          fontSize: roomyDesktop ? 23 : 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.3,
                                          color: const Color(0xffEEE5D4),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        offer.product.price,
                                        style: priceStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: enabled
                                    ? () => _store.buy(
                                        offer.product,
                                        widget.owner,
                                      )
                                    : null,
                              ),
                          ],
                        ),
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
