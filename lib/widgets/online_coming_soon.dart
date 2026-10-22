import 'package:flutter/material.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

Future<void> showOnlineComingSoon(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: const Color(0xD9100D14),
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(16),
    child: GameNotice(
      eyebrow: 'RE-GUN / ONLINE',
      title: 'COMING SOON',
      message: 'Co-op and versus are on the way. Stay tuned.',
      actions: GameNoticeActions(
        primary: ClickButton(
          text: 'Got it',
          height: 48,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  ),
);
