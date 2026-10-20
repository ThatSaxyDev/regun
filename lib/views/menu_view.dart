import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/app_update_gate.dart';
import 'dart:math' as math;
import 'package:regun/widgets/app_build_label.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/views/online_view.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/home_artwork.dart';

class MenuView extends ConsumerStatefulWidget {
  const MenuView({super.key});
  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView> {
  Map<String, dynamic>? _saved;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await LocalPreferences.shared.load();
    final saved = await RunStore.shared.read(validate: RunCheckpoint.valid);
    if (!mounted) return;
    final audio = ref.read(soloudPlayProvider);
    audio.configure(
        music: LocalPreferences.shared.musicVolume,
        sfx: LocalPreferences.shared.sfxVolume);
    unawaited(audio.playMusic('menu'));
    setState(() {
      _saved = saved != null &&
              !LocalPreferences.shared.profile.settledRuns.contains(saved['id'])
          ? saved
          : null;
      _ready = true;
    });
  }

  Future<void> _open(Widget view) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => view));
    if (mounted) await _refresh();
  }

  Future<void> _play() async {
    if (_saved != null) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
              backgroundColor: const Color(0xff211B26),
              shape: const RoundedRectangleBorder(),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Replace saved run?',
                        style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 18,
                            color: Color(0xffE5DDD1))),
                    const SizedBox(height: 20),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      ClickButton(
                          text: 'New run',
                          width: 140,
                          height: 48,
                          onTap: () => Navigator.pop(context, true)),
                      ClickButtonM(
                          text: 'Keep run',
                          width: 140,
                          height: 48,
                          onTap: () => Navigator.pop(context, false)),
                    ])
                  ]))));
      if (replace != true || !mounted) return;
    }
    if (!LocalPreferences.shared.profile.tutorialComplete) {
      await _open(const BaseView(
          loadout: Loadout(training: true), showTrainingIntro: true));
    } else {
      await _open(const LoadoutView());
    }
  }

  @override
  Widget build(BuildContext context) => AppUpdateGate(
      child: Scaffold(
          backgroundColor: const Color(0xff141117),
          body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
            final inset = constraints.maxWidth < 650 ? 24.0 : 48.0;
            return Stack(children: [
              Padding(padding: const EdgeInsets.only(top: 64), child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: inset),
                        child: Row(children: [
                          Expanded(
                              flex: 5,
                              child: LayoutBuilder(builder: (context, column) {
                                final width = column.maxWidth.clamp(0.0, 280.0);
                                return Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                        width: width,
                                        child: SingleChildScrollView(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 24),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text('Re-Gun',
                                                          style: TextStyle(
                                                              fontFamily: FontFam
                                                                  .pressStart,
                                                              fontSize: 40,
                                                              color: Color(
                                                                  0xffE5DDD1)))),
                                                  const SizedBox(height: 24),
                                                  if (_saved != null) ...[
                                                    ClickButton(
                                                        text: 'Continue',
                                                        height: 48,
                                                        onTap: () {
                                                          try {
                                                            final loadout = Loadout
                                                                .fromJson(Map<
                                                                    String,
                                                                    dynamic>.from(_saved![
                                                                        'loadout']
                                                                    as Map));
                                                            _open(BaseView(
                                                                loadout:
                                                                    loadout,
                                                                resumeSnapshot:
                                                                    _saved));
                                                          } on Object {
                                                            setState(() =>
                                                                _saved = null);
                                                          }
                                                        }),
                                                    const SizedBox(height: 8),
                                                  ],
                                                  ClickButton(
                                                      text: _ready
                                                          ? 'Play'
                                                          : 'Loading',
                                                      height: 48,
                                                      onTap: _ready
                                                          ? _play
                                                          : null),
                                                  const SizedBox(height: 8),
                                                  ClickButton(
                                                      text: 'Online',
                                                      height: 44,
                                                      onTap: _ready
                                                          ? () => _open(const OnlineView())
                                                          : null),
                                                  const SizedBox(height: 28),
                                                  ClickButton(
                                                      text: 'Training',
                                                      height: 44,
                                                      onTap: _ready
                                                          ? () => _open(
                                                              const LoadoutView(
                                                                  training:
                                                                      true))
                                                          : null),
                                                  const SizedBox(height: 8),
                                                  ClickButton(
                                                      text: 'Collection',
                                                      height: 44,
                                                      onTap: _ready
                                                          ? () => _open(
                                                              const CollectionView())
                                                          : null),
                                                  if (LocalPreferences
                                                          .shared.bestScore >
                                                      0) ...[
                                                    const SizedBox(height: 16),
                                                    Text(
                                                        'BEST ${LocalPreferences.shared.bestScore}',
                                                        style: const TextStyle(
                                                            fontFamily: FontFam
                                                                .orbitron,
                                                            fontSize: 12,
                                                            color: Color(
                                                                0xffB8A78F))),
                                                  ],
                                                ]))));
                              })),
                          SizedBox(width: constraints.maxWidth < 650 ? 24 : 64),
                          Expanded(
                              flex: 6,
                              child: LayoutBuilder(builder: (context, pane) {
                                final edge = math.min(pane.maxWidth,
                                    (pane.maxHeight - 36).clamp(64.0, 280.0));
                                return Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      SizedBox.square(
                                          dimension: edge,
                                          child: const HomeArtwork()),
                                      const SizedBox(height: 8),
                                      const AppBuildLabel()
                                    ]));
                              })),
                        ]))))),
              Positioned(
                top: 8, right: 16,
                child: Tooltip(message: 'Settings', child: ClickButton(
                  key: const Key('home-settings'),
                  text: 'Settings', glyph: PixelGlyph.settings, iconOnly: true,
                  width: 52, height: 48,
                  onTap: _ready ? () => _open(
                      const SettingsView(allowProgressReset: true)) : null,
                )),
              ),
            ]);
          }))));
}
