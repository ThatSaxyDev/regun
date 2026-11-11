import 'package:flutter/material.dart';

import 'package:regun/services/push/push_service.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/settings_section.dart';

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
            'Push notifications are available in the mobile app.',
            style: TextStyle(fontSize: 13, color: Color(0xffB9AE9C)),
          ),
        ],
      );
    }
    return ValueListenableBuilder<PushStatus>(
      valueListenable: push.status,
      builder: (context, status, _) => ValueListenableBuilder<Map<String, bool>>(
        valueListenable: push.preferences,
        builder: (context, prefs, _) => SettingsSection(
          title: 'Notifications',
          children: [
            _statusLine(status),
            if (status == PushStatus.notDetermined)
              ClickButtonM(
                text: _busy ? 'Asking…' : 'Enable notifications',
                width: 240,
                height: 48,
                onTap: () => _run(() => push.requestPermission()),
              ),
            if (status == PushStatus.denied)
              const GameNoticeStrip(
                message:
                    'Notifications are off in system settings. Turn them on there to receive alerts.',
              ),
            if (status == PushStatus.unconfigured || status == PushStatus.unavailable)
              const GameNoticeStrip(
                message: 'Notifications are unavailable in this build.',
              ),
            if (status == PushStatus.enabled || status == PushStatus.optedOut) ...[
              _toggle(
                'Allow notifications',
                prefs['master'] == true,
                (value) => _run(() => push.setMaster(value)),
              ),
              _toggle(
                'Leaderboards',
                prefs['leaderboards'] == true,
                (value) => _run(() => push.setCategory('leaderboards', value)),
              ),
              _toggle(
                'Events and updates',
                prefs['events'] == true,
                (value) => _run(() => push.setCategory('events', value)),
              ),
              _toggle(
                'Come-back reminders',
                prefs['reengagement'] == true,
                (value) => _run(() => push.setCategory('reengagement', value)),
              ),
              const Text(
                'Account and purchase notices are always sent when needed for security.',
                style: TextStyle(fontSize: 12, color: Color(0xff8A8175)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusLine(PushStatus status) {
    final (text, color) = switch (status) {
      PushStatus.enabled => ('On', const Color(0xff9BD49B)),
      PushStatus.optedOut => ('Off', const Color(0xffB9AE9C)),
      PushStatus.denied => ('Off in system settings', const Color(0xffD49B9B)),
      PushStatus.notDetermined => ('Not enabled', const Color(0xffB9AE9C)),
      PushStatus.unconfigured => ('Not configured', const Color(0xffB9AE9C)),
      PushStatus.unsupported => ('Unavailable', const Color(0xffB9AE9C)),
      PushStatus.unavailable => ('Unavailable', const Color(0xffD49B9B)),
    };
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Status',
            style: TextStyle(fontSize: 13, color: Color(0xffE5DDD1)),
          ),
        ),
        Text(text, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> update) =>
      SettingsChoice(
        label: label,
        options: [
          PixelOption(label: 'Off', selected: !value, onTap: () => update(false)),
          PixelOption(label: 'On', selected: value, onTap: () => update(true)),
        ],
      );
}
