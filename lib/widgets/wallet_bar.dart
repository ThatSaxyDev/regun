import 'package:regun/services/scrap_store.dart';
import 'package:regun/widgets/scrap_store_dialog.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:flutter/material.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/pixel_icon.dart';

String walletAmount(int value) {
  return formatNumber(value);
}

/// Banked profile value only. Run XP, cores and provisional Scrap never enter
/// this display.
class WalletBar extends StatelessWidget {
  const WalletBar({
    super.key,
    this.preferences,
    this.showLabels = true,
    this.readOnly = false,
    this.onSignIn,
  });
  final LocalPreferences? preferences;
  final bool showLabels, readOnly;

  /// Screens that hold the local profile lease (the armory) cannot complete an
  /// account attach while they are open, so they hand sign-in back to the menu
  /// instead of raising the dialog above themselves.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final source = preferences ?? LocalPreferences.shared;
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) => Align(
        widthFactor: 1,
        alignment: Alignment.centerRight,
        child: _BalanceCell(
          showLabel: showLabels,
          amount: source.profileReady
              ? walletAmount(source.profile.scrap)
              : '—',
          pending: source.profileSaveFailed,
          purchasable: !readOnly && ScrapStore.supported,
          onTap: () => showWallet(
            context,
            source,
            readOnly: readOnly,
            onSignIn: onSignIn,
          ),
        ),
      ),
    );
  }
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.amount,
    required this.onTap,
    this.pending = false,
    this.showLabel = true,
    this.purchasable = false,
  });
  final String amount;
  static const color = Color(0xffE1BA78);
  final VoidCallback onTap;
  final bool pending, showLabel, purchasable;

  /// Desktop windows leave the chip parked in a corner, so a fixed 48pt tall
  /// cell reads as a passive readout. Grow the whole cell with the window
  /// instead of only on one platform.
  static double _scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 2200) return 2.3;
    if (width >= 1700) return 2;
    if (width >= 1300) return 1.6;
    if (width >= 900) return 1.25;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final hint = purchasable ? ', add more Scrap' : '';
    return Semantics(
      button: true,
      label: 'Scrap $amount${pending ? ', save needed' : ''}$hint. Wallet details',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: const Color(0xf01D2420),
        shape: const BeveledRectangleBorder(
          side: BorderSide(color: Color(0xff495049)),
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 48 * scale),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 8 * scale,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelIcon(
                    PixelGlyph.shards,
                    color: color,
                    size: 14 * scale,
                  ),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showLabel) ...[
                          Text(
                            'SCRAP',
                            style: TextStyle(
                              fontFamily: FontFam.orbitron,
                              fontSize: 8 * scale,
                              letterSpacing: 1,
                              color: color,
                            ),
                          ),
                          SizedBox(height: 3 * scale),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              amount,
                              style: TextStyle(
                                fontFamily: FontFam.orbitron,
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xffEEE5D4),
                              ),
                            ),
                            if (purchasable) ...[
                              SizedBox(width: 6 * scale),
                              PixelIcon(
                                PixelGlyph.plus,
                                color: color,
                                size: 12 * scale,
                              ),
                            ],
                          ],
                        ),
                        if (pending)
                          Text(
                            'SAVE NEEDED',
                            style: TextStyle(
                              fontFamily: FontFam.orbitron,
                              fontSize: 8 * scale,
                              color: const Color(0xffE1BA78),
                            ),
                          ),
                      ],
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

Future<void> showWallet(
  BuildContext pageContext,
  LocalPreferences source, {
  bool readOnly = false,
  VoidCallback? onSignIn,
}) => showDialog<void>(
  context: pageContext,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ListenableBuilder(
      listenable: source,
      builder: (context, _) {
        final close = ClickButton(
          text: 'Close',
          onTap: () => Navigator.of(context).pop(),
        );
        final action = source.profileSaveFailed
            ? ClickButton(
                text: 'Retry save',
                onTap: () async {
                  await source.saveProfile();
                },
              )
            : !readOnly && ScrapStore.supported
            ? ClickButton(
                text: 'Buy Scrap',
                onTap: () async {
                  Navigator.of(context).pop();
                  if (!pageContext.mounted) return;
                  final account = AccountController.shared;
                  await account.initialize();
                  if (!pageContext.mounted) return;
                  if (onSignIn != null &&
                      (!account.attached ||
                          account.needsSignIn ||
                          account.conflict)) {
                    onSignIn();
                    return;
                  }
                  await showScrapStore(
                    pageContext,
                    allowSignIn: onSignIn == null,
                  );
                },
              )
            : !readOnly && !source.canSpend
            ? ClickButton(
                text: 'Sign in',
                onTap: () async {
                  Navigator.of(context).pop();
                  if (onSignIn != null) {
                    onSignIn();
                    return;
                  }
                  final account = AccountController.shared;
                  await account.initialize();
                  if (pageContext.mounted) {
                    await showAccountFlow(pageContext, account);
                  }
                },
              )
            : null;
        return GameNotice(
          eyebrow: null,
          title: 'WALLET',
          titleSize: 20,
          message: null,
          detail: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Color(0xff51454C), height: 20),
              const Text(
                'Available Scrap',
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 14,
                  color: _BalanceCell.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                source.profileReady ? walletAmount(source.profile.scrap) : '—',
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffEEE5D4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                source.profileSaveFailed
                    ? 'Save your balance before spending.'
                    : !readOnly && !source.canSpend
                    ? 'Sign in to spend Scrap.'
                    : 'Spend Scrap on Armory weapons and eligible Solo revives.',
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xffE5DDD1),
                ),
              ),
            ],
          ),
          actions: GameNoticeActions(
            primary: action ?? close,
            secondary: action == null ? null : close,
          ),
        );
      },
    ),
  ),
);
