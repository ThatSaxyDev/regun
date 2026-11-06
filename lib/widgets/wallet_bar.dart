import 'package:regun/services/apple_scrap_store.dart';
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
  });
  final LocalPreferences? preferences;
  final bool showLabels, readOnly;

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
          onTap: () => showWallet(context, source, readOnly: readOnly),
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
  });
  final String amount;
  static const color = Color(0xffE1BA78);
  final VoidCallback onTap;
  final bool pending, showLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Scrap $amount${pending ? ', save needed' : ''}. Wallet details',
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
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelIcon(PixelGlyph.shards, color: color, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showLabel) ...[
                        const Text(
                          'SCRAP',
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 8,
                            letterSpacing: 1,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        amount,
                        style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xffEEE5D4),
                        ),
                      ),
                      if (pending)
                        const Text(
                          'SAVE NEEDED',
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 8,
                            color: Color(0xffE1BA78),
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

Future<void> showWallet(
  BuildContext pageContext,
  LocalPreferences source, {
  bool readOnly = false,
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
            : !readOnly && AppleScrapStore.supported
            ? ClickButton(
                text: 'Buy Scrap',
                onTap: () async {
                  Navigator.of(context).pop();
                  if (pageContext.mounted) await showScrapStore(pageContext);
                },
              )
            : !readOnly && !source.canSpend
            ? ClickButton(
                text: 'Sign in',
                onTap: () async {
                  Navigator.of(context).pop();
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
