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
  LocalPreferences get settings => LocalPreferences.shared;
  Future<void> _save() async {
    ref
        .read(soloudPlayProvider)
        .configure(music: settings.musicVolume, sfx: settings.sfxVolume);
    await settings.saveSettings();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MenuPage(
    title: 'SETTINGS',
    maxWidth: 560,
    body: MenuScrollBody(
      child: Column(
        children: [
          ClickButtonM(
            text: 'Controls',
            width: 200,
            height: 48,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ControlsView(onChanged: widget.onControlsChanged),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SettingsSection(
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
          ),
          const SizedBox(height: 32),
          SettingsSection(
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
        ],
      ),
    ),
  );
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
      await settings.resetProgress();
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
