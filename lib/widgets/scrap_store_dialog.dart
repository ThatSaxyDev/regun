import 'package:flutter/material.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/apple_scrap_store.dart';
import 'package:regun/utils/format_number.dart';
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
      final sameOwner =
          _account.attached && _account.session?.accountId == widget.owner;
      return FutureBuilder(
        future: _offers,
        builder: (context, snapshot) => GameNotice(
          eyebrow: 'REGUN / APPLE SANDBOX',
          title: 'SCRAP STORE',
          message: !sameOwner
              ? 'Account changed. Close and reopen the store.'
              : snapshot.connectionState != ConnectionState.done
              ? 'Loading Apple prices…'
              : snapshot.hasError
              ? (snapshot.error is AccountError
                    ? (snapshot.error! as AccountError).message
                    : 'Scrap checkout is unavailable.')
              : _store.message.isNotEmpty
              ? '${_store.message} ${formatNumber(_account.preferences.profile.scrap)} Scrap banked.'
              : '${formatNumber(_account.preferences.profile.scrap)} Scrap banked.',
          detail: !sameOwner || !snapshot.hasData
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 10.0;
                    final columns =
                        constraints.maxWidth >= 365 &&
                            MediaQuery.textScalerOf(context).scale(1) <= 1.3
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final offer in snapshot.data!)
                          ClickButton(
                            width: width,
                            text:
                                '${formatNumber(offer.amount)} Scrap · ${offer.product.price}',
                            onTap: _store.busy || _store.awaitingPayment
                                ? null
                                : () => _store.buy(offer.product, widget.owner),
                          ),
                      ],
                    );
                  },
                ),
          actions: GameNoticeActions(
            primary: ClickButton(
              text: 'Close',
              onTap: () => Navigator.of(context).pop(),
            ),
            secondary: !sameOwner
                ? null
                : snapshot.hasError
                ? ClickButton(
                    text: 'Retry',
                    onTap: () => setState(() => _offers = _store.load()),
                  )
                : ClickButton(
                    text: 'Check status',
                    onTap: _store.busy
                        ? null
                        : () => _store.recover(refresh: true),
                  ),
          ),
        ),
      );
    },
  );
}
