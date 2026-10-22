import 'package:regun/widgets/app_update_gate.dart';
import 'package:regun/services/online_availability.dart';
import 'package:regun/widgets/online_coming_soon.dart';
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
import 'package:regun/widgets/home_menu.dart';

class MenuView extends ConsumerStatefulWidget {
  const MenuView({super.key});
  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView>
    with WidgetsBindingObserver {
  late final OnlineAvailability _online;
  Timer? _policyTimer;
  bool _foreground = true, _openingOnline = false;
  Map<String, dynamic>? _saved;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _online = ref.read(onlineAvailabilityProvider)..addListener(_policyChanged);
    _policyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && (ModalRoute.of(context)?.isCurrent ?? false)) {
        unawaited(_online.refresh());
      }
    });
    unawaited(_refresh());
  }

  void _policyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && (ModalRoute.of(context)?.isCurrent ?? false)) {
      unawaited(_online.refresh());
    }
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _online.removeListener(_policyChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openOnline() async {
    if (_openingOnline) return;
    setState(() => _openingOnline = true);
    try {
      final allowed = await _online.refresh();
      if (!mounted ||
          !_foreground ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      if (allowed) {
        await _open(const OnlineView());
      } else {
        showOnlineComingSoon(context);
      }
    } finally {
      if (mounted) setState(() => _openingOnline = false);
    }
  }

  Future<void> _refresh() async {
    unawaited(_online.refresh());
    await LocalPreferences.shared.load();
    final saved = await RunStore.shared.read(validate: RunCheckpoint.valid);
    if (!mounted) return;
    final audio = ref.read(soloudPlayProvider);
    audio.configure(
      music: LocalPreferences.shared.musicVolume,
      sfx: LocalPreferences.shared.sfxVolume,
    );
    unawaited(audio.playMusic('menu'));
    setState(() {
      _saved =
          saved != null &&
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Replace saved run?',
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 18,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ClickButton(
                      text: 'New run',
                      width: 140,
                      height: 48,
                      onTap: () => Navigator.pop(context, true),
                    ),
                    ClickButtonM(
                      text: 'Keep run',
                      width: 140,
                      height: 48,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (replace != true || !mounted) return;
    }
    if (!LocalPreferences.shared.profile.tutorialComplete) {
      await _open(
        const BaseView(
          loadout: Loadout(training: true),
          showTrainingIntro: true,
        ),
      );
    } else {
      await _open(const LoadoutView());
    }
  }

  void _continue() {
    try {
      final loadout = Loadout.fromJson(
        Map<String, dynamic>.from(_saved!['loadout'] as Map),
      );
      _open(BaseView(loadout: loadout, resumeSnapshot: _saved));
    } on Object {
      setState(() => _saved = null);
    }
  }

  @override
  Widget build(BuildContext context) => AppUpdateGate(
    child: Scaffold(
      backgroundColor: const Color(0xff171319),
      body: HomeMenu(
        ready: _ready,
        bestScore: LocalPreferences.shared.bestScore,
        reducedMotion: LocalPreferences.shared.reducedMotion,
        onContinue: _saved == null ? null : _continue,
        onPlay: _play,
        onlineAvailable: _online.enabled,
        onlineChecking:
            _openingOnline || _online.state == OnlineAvailabilityState.checking,
        onOnline: _openOnline,
        onTraining: () => _open(const LoadoutView(training: true)),
        onCollection: () => _open(const CollectionView()),
        onSettings: () => _open(const SettingsView(allowProgressReset: true)),
      ),
    ),
  );
}
