import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/views/settings_view.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/utils/constants.dart';

class OnlineMatchMenu extends StatefulWidget {
  const OnlineMatchMenu({
    super.key,
    required this.session,
    required this.resume,
  });
  final OnlineSession session;
  final VoidCallback resume;
  @override
  State<OnlineMatchMenu> createState() => _OnlineMatchMenuState();
}

class _OnlineMatchMenuState extends State<OnlineMatchMenu> {
  OnlineSession get session => widget.session;
  bool _confirming = false;
  Future<void> _leave() async {
    if (_confirming || session.busy) return;
    setState(() => _confirming = true);
    try {
      final forfeits =
          session.room?.mode == 'versus' && session.match?.phase != 'finished';
      final accepted = await confirmRunAction(
        context,
        eyebrow: 'RE-GUN / ONLINE',
        title: 'LEAVE MATCH?',
        message: forfeits
            ? 'Leaving now forfeits this match.'
            : 'You will leave this room. Other players can keep playing.',
        action: 'Leave match',
        destructive: true,
      );
      if (!mounted || !accepted) return;
      session.menuOpen = false;
      unawaited(session.leave());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xe8141117),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Match menu',
                style: TextStyle(
                  fontFamily: FontFam.pressStart,
                  color: Color(0xffE5DDD1),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                session.me?.expired == true
                    ? 'Reconnect window ended. Leave to join another room.'
                    : 'The match continues while this menu is open.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  color: Color(0xffB9B7AF),
                ),
              ),
              const SizedBox(height: 20),
              ClickButton(text: 'Return to match', onTap: widget.resume),
              const SizedBox(height: 12),
              ClickButton(
                text: 'Settings',
                glyph: PixelGlyph.settings,
                buttonColor: const Color(0xffB2A8B4),
                height: 48,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsView())),
              ),
              const SizedBox(height: 12),
              ClickButton(
                text:
                    session.room?.mode == 'versus' &&
                        session.match?.phase != 'finished'
                    ? 'Leave (forfeit)'
                    : 'Leave room',
                onTap: session.busy || _confirming ? null : _leave,
              ),
              if (session.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GameNoticeStrip(message: session.error),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
