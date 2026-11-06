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
    child: ListenableBuilder(
      listenable: source,
      builder: (context, _) => GameNotice(
        eyebrow: 'SCRAP',
        title: 'WALLET',
        message:
            'Scrap: ${source.profileReady ? walletAmount(source.profile.scrap) : '—'}\n'
            '${source.profileSaveFailed
                ? 'Save needed. Retry before spending.'
                : source.canSpend || readOnly
                ? 'Banked Solo Scrap.'
                : 'Sign in with email to spend Scrap.'}\n\n'
            'Online Scrap: ${source.onlineScrap == null ? '—' : walletAmount(source.onlineScrap!)}\n'
            '${source.onlineScrap == null ? 'Check your balance in Online.' : 'Last checked in Online.'}\n'
            'Separate from spendable Solo Scrap.',
        actions: GameNoticeActions(
          primary: ClickButton(
            text: 'Close',
            onTap: () => Navigator.of(context).pop(),
          ),
          secondary: source.profileSaveFailed
              ? ClickButton(
                  text: 'Retry save',
                  onTap: () async {
                    await source.saveProfile();
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
              : null,
        ),
      ),
    ),
  ),
);
