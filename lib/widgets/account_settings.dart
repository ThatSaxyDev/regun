import 'package:regun/services/player_registry.dart';
import 'package:flutter/material.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/settings_section.dart';
import 'package:regun/utils/constants.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({
    super.key,
    required this.account,
    required this.manage,
  });
  final AccountController account;
  final bool manage;
  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  bool busy = false;
  String error = '';
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } on AccountError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Account service unavailable. Your progress stays on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.account,
    builder: (context, _) {
      final account = widget.account;
      const style = TextStyle(
        fontFamily: FontFam.orbitron,
        fontSize: 12,
        height: 1.5,
        color: Color(0xffB2A8B4),
      );
      return SettingsSection(
        title: 'Account',
        children: [
          Text(
            account.username.isNotEmpty
                ? account.username
                : 'Saved on this device',
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              color: Color(0xffE5DDD1),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!account.verified)
            ValueListenableBuilder<String>(
              valueListenable: PlayerRegistry.shared.guestName,
              builder: (context, name, _) => Text(name, style: style),
            ),
          if (account.email.isNotEmpty) Text(account.email, style: style),
          if (account.verified) Text(account.saveLabel, style: style),
          if (account.verified && account.issue.isNotEmpty)
            Text(account.issue, style: style),
          if (!widget.manage)
            const Text(
              'Manage your account from the main menu Settings.',
              style: style,
            ),
          if (widget.manage) ...[
            const SizedBox(height: 12),
            if (!account.verified)
              ClickButton(
                text: 'Connect email',
                onTap: busy ? null : () => showAccountFlow(context, account),
              ),
            if (account.verified) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (account.needsSignIn ||
                      !account.ready ||
                      account.conflict ||
                      !account.attached ||
                      account.issue.isNotEmpty)
                    ClickButton(
                      text: account.needsSignIn
                          ? 'Sign in again'
                          : account.conflict
                          ? 'Resolve progress'
                          : account.ready
                          ? 'Retry backup'
                          : 'Finish setup',
                      width: 180,
                      onTap: busy
                          ? null
                          : () => run(() async {
                              if (account.needsSignIn) {
                                final verified = await showAccountFlow(
                                  context,
                                  account,
                                  reverify: true,
                                );
                                if (verified == true) await account.sync();
                              } else if (!account.ready ||
                                  account.conflict ||
                                  !account.attached) {
                                await showAccountFlow(context, account);
                              } else {
                                await account.sync();
                              }
                            }),
                    ),
                  ClickButton(
                    text: 'Change username',
                    width: 200,
                    onTap: busy
                        ? null
                        : () => showAccountFlow(context, account, rename: true),
                  ),
                ],
              ),
              SettingsChoice(
                label: 'Send me Regun news and offers',
                options: [
                  for (final enabled in [false, true])
                    PixelOption(
                      label: enabled ? 'On' : 'Off',
                      selected:
                          (account.account?['marketing'] == true) == enabled,
                      onTap: () {
                        if (!busy) run(() => account.marketing(enabled));
                      },
                    ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final accepted = await confirmRunAction(
                              context,
                              title: 'SIGN OUT?',
                              message: account.pending
                                  ? 'Some progress is waiting for cloud backup. This device keeps its local copy.'
                                  : 'Your cloud progress stays with your account.',
                              action: 'Sign out',
                            );
                            if (accepted) await account.signOut();
                          }),
                    child: const Text('Sign out', style: style),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final accepted = await confirmRunAction(
                              context,
                              title: 'DELETE ACCOUNT?',
                              message: 'Your cloud profile and progress will be deleted. This cannot be undone.',
                              action: 'Delete account',
                              destructive: true,
                            );
                            if (!accepted || !context.mounted) return;
                            final verified = await showAccountFlow(
                              context,
                              account,
                              reverify: true,
                            );
                            if (verified) await account.deleteAccount();
                          }),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(
                        color: Color(0xffDD826C),
                        fontFamily: FontFam.orbitron,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (error.isNotEmpty)
              Text(
                error,
                style: style.copyWith(color: const Color(0xffDD826C)),
              ),
          ],
        ],
      );
    },
  );
}
