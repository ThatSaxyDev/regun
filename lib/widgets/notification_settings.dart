import 'package:flutter/material.dart';

import 'package:regun/services/push/push_service.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/settings_section.dart';

const _ink = Color(0xffDED4C5);
const _quiet = Color(0xff9A9086);

const _bodyStyle = TextStyle(
  fontFamily: FontFam.orbitron,
  fontSize: 13,
  height: 1.5,
  color: _ink,
);
const _captionStyle = TextStyle(
  fontFamily: FontFam.orbitron,
  fontSize: 12,
  height: 1.5,
  color: _quiet,
);

/// Notification controls. Only rendered where push exists; the master switch is
/// mirrored locally and on the server, and the OS permission always wins.
class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  PushService get push => PushService.shared;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!push.supported) {
      return const SettingsSection(
        title: 'Notifications',
        children: [
          Text(
            'Push notifications are available on iOS, Android, and supported Mac builds.',
            style: _bodyStyle,
          ),
        ],
      );
    }
    return ValueListenableBuilder<PushStatus>(
      valueListenable: push.status,
      builder: (context, status, _) =>
          ValueListenableBuilder<Map<String, bool>>(
            valueListenable: push.preferences,
            builder: (context, prefs, _) => SettingsSection(
              title: 'Notifications',
              children: [
                // The toggle already shows the state, so the status line only
                // appears where there is no toggle to read.
                if (status == PushStatus.notDetermined) ...[
                  _statusLine(status),
                  ClickButtonM(
                    text: _busy ? 'Asking…' : 'Enable notifications',
                    width: 240,
                    height: 48,
                    onTap: () => _run(() => push.requestPermission()),
                  ),
                ],
                if (status == PushStatus.denied) ...[
                  _statusLine(status),
                  const GameNoticeStrip(
                    message: 'Turn notifications on in system settings to receive alerts.',
                  ),
                ],
                if (status == PushStatus.unconfigured ||
                    status == PushStatus.unavailable)
                  const GameNoticeStrip(
                    message: 'Notifications are unavailable in this build.',
                  ),
                if (status == PushStatus.enabled ||
                    status == PushStatus.optedOut) ...[
                  _toggle(
                    'Allow notifications',
                    prefs['master'] == true,
                    (value) => _run(() => push.setMaster(value)),
                  ),
                  if (prefs['master'] == true && !push.mac) ...[
                    _toggle(
                      'Return reminders',
                      prefs['returnReminders'] == true,
                      (value) => _run(() => push.setReturnReminders(value)),
                    ),
                    const Text(
                      'Leaderboard changes and reminders after time away.',
                      style: _captionStyle,
                    ),
                  ],
                ],
              ],
            ),
          ),
    );
  }

  Widget _statusLine(PushStatus status) {
    final (text, color) = switch (status) {
      PushStatus.enabled => ('On', const Color(0xff9BD49B)),
      PushStatus.optedOut => ('Off', _quiet),
      PushStatus.denied => ('Off in system settings', const Color(0xffD49B9B)),
      PushStatus.notDetermined => ('Not enabled', _quiet),
      PushStatus.unconfigured => ('Not configured', _quiet),
      PushStatus.unsupported => ('Unavailable', _quiet),
      PushStatus.unavailable => ('Unavailable', const Color(0xffD49B9B)),
    };
    return Row(
      children: [
        const Expanded(child: Text('Status', style: _bodyStyle)),
        Text(text, style: _bodyStyle.copyWith(color: color)),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> update) =>
      SettingsChoice(
        label: label,
        options: [
          PixelOption(
            label: 'Off',
            selected: !value,
            onTap: () => update(false),
          ),
          PixelOption(label: 'On', selected: value, onTap: () => update(true)),
        ],
      );
}
