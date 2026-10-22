import 'package:flutter/material.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/game_notice.dart';

Future<bool> confirmRunAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String eyebrow = 'RE-GUN / CURRENT RUN',
  String cancel = 'Cancel',
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9100D14),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: GameNotice(
          eyebrow: eyebrow,
          title: title,
          message: message,
          actions: GameNoticeActions(
            secondary: ClickButton(
              key: const Key('run-action-cancel'),
              text: cancel,
              autofocus: true,
              height: 48,
              buttonColor: const Color(0xffA79AA9),
              onTap: () => Navigator.pop(context, false),
            ),
            primary: ClickButton(
              key: const Key('run-action-confirm'),
              text: action,
              height: 48,
              buttonColor: destructive
                  ? const Color(0xffCB7967)
                  : const Color(0xffE1BA78),
              onTap: () => Navigator.pop(context, true),
            ),
          ),
        ),
      ),
    ) ??
    false;
