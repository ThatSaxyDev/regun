import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

Future<bool> showAccountFlow(
  BuildContext context,
  AccountController account, {
  bool online = false,
  bool rename = false,
  bool reverify = false,
  bool changeEmail = false,
  VoidCallback? onShown,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9100D14),
      builder: (_) => AccountFlow(
        account: account,
        online: online,
        rename: rename,
        reverify: reverify,
        changeEmail: changeEmail,
        onShown: onShown,
      ),
    ) ??
    false;

class AccountField extends StatelessWidget {
  const AccountField({
    super.key,
    required this.controller,
    required this.label,
    this.code = false,
    this.email = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final bool code, email, enabled;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: TextCapitalization.none,
    autofillHints: code
        ? [AutofillHints.oneTimeCode]
        : email
        ? [AutofillHints.email]
        : [AutofillHints.username],
    keyboardType: code
        ? TextInputType.number
        : email
        ? TextInputType.emailAddress
        : TextInputType.text,
    inputFormatters: code
        ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ]
        : [LengthLimitingTextInputFormatter(email ? 254 : 16)],
    style: TextStyle(
      fontFamily: FontFam.orbitron,
      color: const Color(0xffE5DDD1),
      fontSize: code ? 22 : 14,
      letterSpacing: code ? 8 : 0,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: FontFam.orbitron,
        color: Color(0xffB2A8B4),
      ),
      filled: true,
      fillColor: const Color(0xff171319),
      contentPadding: const EdgeInsets.all(16),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xff75604C)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xff75604C)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xffE1BA78), width: 2),
      ),
    ),
  );
}

class AccountFlow extends StatefulWidget {
  const AccountFlow({
    super.key,
    required this.account,
    this.online = false,
    this.rename = false,
    this.reverify = false,
    this.changeEmail = false,
    this.onShown,
  });
  final AccountController account;
  final bool online, rename, reverify, changeEmail;
  final VoidCallback? onShown;
  @override
  State<AccountFlow> createState() => _AccountFlowState();
}

class _AccountFlowState extends State<AccountFlow> {
  final email = TextEditingController(),
      code = TextEditingController(),
      name = TextEditingController();
  String step = 'email', requestId = '', error = '';
  String? expectedAccount;
  bool busy = false;
  DateTime? resendAt;
  Timer? timer;
  AccountController get account => widget.account;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown?.call();
    });
    expectedAccount = widget.reverify || widget.changeEmail
        ? account.session?.accountId
        : null;
    email.text = widget.changeEmail ? '' : account.email;
    name.text = account.username;
    if (!widget.reverify && !widget.changeEmail && account.verified) {
      step = widget.rename || !account.ready
          ? 'name'
          : account.conflict
          ? 'conflict'
          : account.attached
          ? 'ready'
          : 'resume';
    }
    code.addListener(_changed);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && step == 'code') setState(() {});
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    name.dispose();
    super.dispose();
  }

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
          () => error = 'Could not complete setup. You can still play offline.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send() => run(() async {
    final data = await account.requestCode(
      email.text.trim(),
      changeEmail: widget.changeEmail,
    );
    if (!mounted) return;
    requestId = data['requestId'] as String;
    resendAt = DateTime.now().add(
      Duration(seconds: (data['resendAfter'] as num).toInt()),
    );
    code.clear();
    setState(() => step = 'code');
  });
  Future<void> verify() => run(() async {
    await account.verifyCode(
      requestId,
      code.text,
      expectedAccount: expectedAccount,
    );
    if (!mounted) return;
    if (widget.reverify || widget.changeEmail) {
      Navigator.pop(context, true);
      return;
    }
    if (account.ready) {
      await attach();
    } else {
      setState(() => step = 'name');
    }
  });
  Future<void> attach({bool cloud = false, bool device = false}) async {
    await account.attach(useCloud: cloud, useDevice: device);
    if (mounted) setState(() => step = account.conflict ? 'conflict' : 'ready');
  }

  Future<void> saveName() => run(() async {
    await account.rename(name.text);
    if (!mounted) return;
    if (widget.rename) {
      Navigator.pop(context, true);
      return;
    }
    await attach();
  });
  int get resendSeconds => resendAt == null
      ? 0
      : resendAt!.difference(DateTime.now()).inSeconds.clamp(0, 60);
  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      'code' => 'CHECK YOUR EMAIL',
      'name' => widget.rename ? 'CHANGE USERNAME' : 'CHOOSE YOUR USERNAME',
      'conflict' => 'CHOOSE YOUR PROGRESS',
      'resume' => 'CONNECT YOUR PROGRESS',
      'ready' =>
        account.pending || account.issue.isNotEmpty
            ? 'BACKUP PENDING'
            : 'PROGRESS SAVED',
      _ =>
        widget.changeEmail
            ? 'CHANGE EMAIL'
            : widget.online
            ? 'SET UP YOUR ONLINE ID'
            : 'SAVE YOUR PROGRESS',
    };
    final message = switch (step) {
      'code' => 'Enter the 6-digit code sent to ${email.text.trim()}.',
      'name' => 'This is the name other players will see.',
      'conflict' => 'This device and your cloud save have different progress. Choose which to use.',
      'ready' =>
        account.pending || account.issue.isNotEmpty
            ? 'Your progress is saved on this device. Cloud backup will retry when available.'
            : 'Use this email to bring your progress to another device.',
      _ =>
        widget.online
            ? 'Verify your email and choose a username to play online.'
            : 'Keep your unlocked weapons, survivors and gear when you change devices.',
    };
    final label = switch (step) {
      'code' => 'Verify code',
      'name' => 'Save username',
      'conflict' => 'Use cloud progress',
      'resume' => 'Continue',
      'ready' => widget.online ? 'Continue online' : 'Done',
      _ => 'Send code',
    };
    VoidCallback? primary = busy
        ? null
        : switch (step) {
            'code' => code.text.length == 6 ? verify : null,
            'name' => saveName,
            'conflict' => () => run(() => attach(cloud: true)),
            'resume' => () => run(() async {
              await account.status();
              await attach();
            }),
            'ready' => () => Navigator.pop(
              context,
              account.ready && account.attached,
            ),
            _ => send,
          };
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: GameNotice(
        eyebrow: 'RE-GUN / ACCOUNT',
        title: title,
        message: message,
        detail: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (step == 'email') ...[
              AccountField(
                controller: email,
                label: 'Email',
                email: true,
                enabled: !busy && !widget.reverify,
              ),
              const SizedBox(height: 8),
              const Text(
                'No password. Just a code sent to your email.',
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 11,
                  color: Color(0xffB2A8B4),
                ),
              ),
            ],
            if (step == 'code') ...[
              AccountField(
                controller: code,
                label: 'Verification code',
                code: true,
                enabled: !busy,
              ),
              Wrap(
                spacing: 16,
                children: [
                  TextButton(
                    onPressed: busy || widget.reverify
                        ? null
                        : () => setState(() => step = 'email'),
                    child: const Text(
                      'Change email',
                      style: TextStyle(
                        fontFamily: FontFam.orbitron,
                        color: Color(0xffE1BA78),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy || resendSeconds > 0 ? null : send,
                    child: Text(
                      resendSeconds > 0
                          ? 'Resend in ${resendSeconds}s'
                          : 'Resend code',
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        color: Color(0xffE1BA78),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (step == 'name') ...[
              AccountField(controller: name, label: 'Username', enabled: !busy),
              const SizedBox(height: 8),
              Text(
                widget.rename
                    ? '${account.account?['changesRemaining'] ?? 2} changes left this month.'
                    : 'You can change your username twice a month in Settings.',
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 11,
                  color: Color(0xffB2A8B4),
                ),
              ),
            ],
            if (step == 'conflict')
              Text(
                'Device: ${account.preferences.profile.totalKills} kills · ${account.preferences.profile.scrap} scrap\nCloud: ${(account.account?['cloud'] as Map?)?['payload']?['totalKills'] ?? 0} kills · ${(account.account?['cloud'] as Map?)?['payload']?['scrap'] ?? 0} scrap',
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  color: Color(0xffE5DDD1),
                  height: 1.6,
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Working…',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: Color(0xffB2A8B4),
                  ),
                ),
              ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      color: Color(0xffDD826C),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameNoticeActions(
              primary: ClickButton(text: label, onTap: primary, height: 48),
              secondary: ClickButton(
                text: step == 'ready'
                    ? 'Close'
                    : widget.online
                    ? 'Back'
                    : 'Not now',
                height: 48,
                onTap: () => Navigator.pop(context, false),
              ),
            ),
            if (step == 'conflict')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClickButton(
                  text: "Use this device's progress",
                  onTap: busy ? null : () => run(() => attach(device: true)),
                  height: 48,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
