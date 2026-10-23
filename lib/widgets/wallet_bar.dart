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
  final digits = value.toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// Banked profile value only. Run XP, cores and provisional Scrap never enter
/// this display. Credits deliberately remain unknown until a real wallet exists.
class WalletBar extends StatelessWidget {
  const WalletBar({super.key, this.preferences, this.showLabels = true});
  final LocalPreferences? preferences;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final source = preferences ?? LocalPreferences.shared;
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) => Align(
        widthFactor: 1,
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 6,
          children: [
            _BalanceCell(
              label: 'SCRAP',
              showLabel: showLabels,
              amount: source.profileReady
                  ? walletAmount(source.profile.scrap)
                  : '—',
              glyph: PixelGlyph.shards,
              color: const Color(0xffE1BA78),
              pending: source.profileSaveFailed,
              onTap: () => showWallet(context, source),
            ),
            _BalanceCell(
              label: 'CREDITS',
              showLabel: showLabels,
              amount: '—',
              glyph: PixelGlyph.star,
              color: const Color(0xff9CACAB),
              onTap: () => showWallet(context, source),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.label,
    required this.amount,
    required this.glyph,
    required this.color,
    required this.onTap,
    this.pending = false,
    this.showLabel = true,
  });
  final String label, amount;
  final PixelGlyph glyph;
  final Color color;
  final VoidCallback onTap;
  final bool pending, showLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${label.toLowerCase()} $amount${pending ? ', save needed' : ''}. Wallet details',
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
                PixelIcon(glyph, color: color, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showLabel) ...[
                        Text(
                          label,
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
  LocalPreferences source,
) => showDialog<void>(
  context: pageContext,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ListenableBuilder(
      listenable: source,
      builder: (context, _) => GameNotice(
        eyebrow: 'YOUR BALANCES',
        title: 'WALLET',
        message:
            'Scrap: ${source.profileReady ? walletAmount(source.profile.scrap) : '—'}\n'
            '${source.profileSaveFailed
                ? 'Save needed. Retry before spending.'
                : source.canSpend
                ? 'Solo earnings. Connect to buy styles. Owned styles work offline.'
                : 'Sign in with email to spend Scrap.'}\n\n'
            'Credits: —\nNot available yet.\n\n'
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
              : !source.canSpend
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
