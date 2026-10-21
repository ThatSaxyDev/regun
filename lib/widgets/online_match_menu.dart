import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/utils/constants.dart';

class OnlineMatchMenu extends StatelessWidget {
  const OnlineMatchMenu({
    super.key,
    required this.session,
    required this.resume,
  });
  final OnlineSession session;
  final VoidCallback resume;
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
              ClickButton(text: 'Return to match', onTap: resume),
              const SizedBox(height: 12),
              ClickButton(
                text:
                    session.room?.mode == 'versus' &&
                        session.match?.phase != 'finished'
                    ? 'Leave (forfeit)'
                    : 'Leave room',
                onTap: session.busy
                    ? null
                    : () {
                        session.menuOpen = false;
                        unawaited(session.leave());
                      },
              ),
              if (session.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    session.error,
                    style: const TextStyle(color: Color(0xffDD826C)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
