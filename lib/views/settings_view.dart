import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_display.dart';
import 'package:regun/desktop/desktop_controls_view.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/widgets/account_settings.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/widgets/settings_section.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/views/controls_view.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/services/run_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({
    super.key,
    this.allowProgressReset = false,
    this.onControlsChanged,
  });
  final bool allowProgressReset;
  final ValueChanged<ControlLayout>? onControlsChanged;
  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String? _accountIssue;
  String? _displayIssue;
  DesktopBindings get display => DesktopBindings.shared;

  Future<void> _fullscreen() async {
    try {
      if (await toggleDesktopFullscreen()) return;
    } catch (_) {
      // Browser or window policy denied the request.
    }
    if (mounted) setState(() => _displayIssue = 'Fullscreen is unavailable.');
  }

  Future<void> _saveDisplay() async {
    try {
      await display.save();
    } catch (_) {
      if (mounted) {
        setState(() => _displayIssue = 'Could not save display settings.');
      }
    }
  }

  LocalPreferences get settings => LocalPreferences.shared;
  Future<void> _save() async {
    ref
        .read(soloudPlayProvider)
        .configure(music: settings.musicVolume, sfx: settings.sfxVolume);
    await settings.saveSettings();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final desktop = desktopInputAvailable;
    final controls = ClickButtonM(
      text: 'Controls',
      width: 200,
      height: 48,
      onTap: () => Navigator.of(context).push(
        GamePageRoute(
          builder: (_) => desktopInputAvailable
              ? const DesktopControlsView()
              : ControlsView(onChanged: widget.onControlsChanged),
        ),
      ),
    );
    final displaySection = SettingsSection(
      title: 'Display',
      children: [
        ClickButton(text: 'Toggle fullscreen', onTap: _fullscreen),
        ClickButton(
          text: display.frameCeiling == 60
              ? 'Frame limit · 60'
              : 'Frame limit · Auto (120)',
          onTap: () {
            setState(
              () =>
                  display.frameCeiling = display.frameCeiling == 60 ? 120 : 60,
            );
            _saveDisplay();
          },
        ),
        ClickButton(
          text: 'UI scale · ${(display.uiScale.value * 100).round()}%',
          onTap: () {
            setState(
              () => display.uiScale.value = display.uiScale.value >= 1.3
                  ? .85
                  : display.uiScale.value + .15,
            );
            _saveDisplay();
          },
        ),
        if (_displayIssue case final message?) Text(message),
      ],
    );
    final audio = SettingsSection(
      title: 'Audio',
      children: [
        ControlSlider(
          label: 'Music',
          value: settings.musicVolume,
          minimum: 0,
          maximum: 1,
          onChanged: (v) {
            setState(() => settings.musicVolume = v);
            _save();
          },
        ),
        ControlSlider(
          label: 'Sound',
          value: settings.sfxVolume,
          minimum: 0,
          maximum: 1,
          onChanged: (v) {
            setState(() => settings.sfxVolume = v);
            _save();
          },
        ),
      ],
    );
    final gameplay = SettingsSection(
      title: 'Gameplay',
      children: [
        _toggle('Haptics', settings.haptics, (v) => settings.haptics = v),
        _toggle(
          'Reduced motion',
          settings.reducedMotion,
          (v) => settings.reducedMotion = v,
        ),
        _toggle(
          'Aim assist',
          settings.aimAssist,
          (v) => settings.aimAssist = v,
        ),
      ],
    );
    final account = <Widget>[
      if (_accountIssue != null) GameNoticeStrip(message: _accountIssue!),
      AccountSettings(
        account: ref.read(accountProvider),
        manage: widget.allowProgressReset,
      ),
      const SizedBox(height: 24),
      if (widget.allowProgressReset)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClickButtonM(
            text: 'Reset progress',
            width: 200,
            height: 48,
            onTap: _confirmReset,
          ),
        ),
    ];
    return MenuPage(
      title: 'SETTINGS',
      maxWidth: 560,
      desktopMaxWidth: 980,
      body: MenuScrollBody(
        child: desktop
            ? LayoutBuilder(
                builder: (context, box) {
                  final sections = [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 24,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: controls),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: displaySection,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 24,
                      children: [audio, gameplay],
                    ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (box.maxWidth >= 640)
                        Row(
                          spacing: 36,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final section in sections)
                              Expanded(child: section),
                          ],
                        )
                      else
                        Column(spacing: 32, children: sections),
                      const Divider(height: 48, color: Color(0xff51483d)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: account,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                children: [
                  controls,
                  const SizedBox(height: 24),
                  audio,
                  const SizedBox(height: 32),
                  gameplay,
                  const SizedBox(height: 32),
                  ...account,
                ],
              ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await confirmRunAction(
      context,
      eyebrow: 'RE-GUN / PROFILE',
      title: 'RESET PROGRESS?',
      message: 'Your unlocks, records and saved run will be erased.',
      action: 'Reset',
      destructive: true,
    );
    if (confirmed == true) {
      final account = ref.read(accountProvider);
      if (settings.profileOwner != 'guest') {
        try {
          await account.resetProgress();
        } catch (_) {
          if (mounted) {
            setState(
              () => _accountIssue = 'Connect to reset cloud progress. You can still play offline.',
            );
          }
          return;
        }
      } else {
        await settings.resetProgress();
      }
      await RunStore.shared.clear();
      if (mounted) setState(() {});
    }
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> update) =>
      SettingsChoice(
        label: label,
        options: [
          PixelOption(
            label: 'Off',
            selected: !value,
            onTap: () {
              setState(() => update(false));
              _save();
            },
          ),
          PixelOption(
            label: 'On',
            selected: value,
            onTap: () {
              setState(() => update(true));
              _save();
            },
          ),
        ],
      );
}
