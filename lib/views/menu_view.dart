import 'package:regun/services/player_registry.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/services/online_availability.dart';
import 'package:regun/widgets/online_coming_soon.dart';
import 'package:regun/models/run_checkpoint.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/views/online_view.dart';
import 'package:regun/widgets/home_menu.dart';

class MenuView extends ConsumerStatefulWidget {
  const MenuView({super.key});
  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView>
    with WidgetsBindingObserver {
  late final OnlineAvailability _online;
  Timer? _policyTimer, _accountIssueTimer;
  String? _accountIssue;
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
    unawaited(_checkBinaryUpdate());
  }

  Future<void> _checkBinaryUpdate() async {
    try {
      await ref.read(appUpdatesProvider).check();
    } catch (_) {
      /* Fully silent and never gates offline entry. */
    }
  }

  void _policyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && (ModalRoute.of(context)?.isCurrent ?? false)) {
      unawaited(_online.refresh());
      unawaited(ref.read(accountProvider).sync());
    }
  }

  @override
  void dispose() {
    _policyTimer?.cancel();
    _accountIssueTimer?.cancel();
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
        final account = ref.read(accountProvider);
        await account.initialize();
        if (!mounted) return;
        if (!account.ready || !account.attached) {
          final completed = await showAccountFlow(
            context,
            account,
            online: true,
          );
          if (!completed || !mounted) return;
        }
        try {
          await account.accessToken();
          await account.status();
        } on AccountError {
          if (!mounted) return;
          final completed = await showAccountFlow(
            context,
            account,
            online: true,
            reverify: true,
          );
          if (!completed || !mounted) return;
          await account.status();
        }
        if (!account.ready || !account.attached || !mounted) return;
        await _open(const OnlineView());
      } else {
        showOnlineComingSoon(context);
      }
    } on AccountError {
      if (mounted) {
        setState(
          () => _accountIssue =
              'Online sign-in is unavailable. Solo and Training are ready.',
        );
        _accountIssueTimer?.cancel();
        _accountIssueTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _accountIssue = null);
        });
      }
    } finally {
      if (mounted) setState(() => _openingOnline = false);
    }
  }

  Future<void> _refresh() async {
    unawaited(_online.refresh());
    await ref.read(accountProvider).localProfileReady;
    await LocalPreferences.shared.load();
    unawaited(
      PlayerRegistry.shared.record(
        LocalPreferences.shared.profileOwner,
        LocalPreferences.shared.profile.toJson(),
      ),
    );
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
    // Background, optional, bounded: neither Home readiness nor local Play waits.
    unawaited(ref.read(accountProvider).sync());
    if (LocalPreferences.shared.profile.tutorialComplete ||
        LocalPreferences.shared.profile.settledRuns.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_inviteAfterPlay());
      });
    }
  }

  Future<void> _open(Widget view) async {
    final account = ref.read(accountProvider);
    final localPlay = view is BaseView || view is LoadoutView;
    if (localPlay) await account.beginLocalPlay();
    try {
      if (!mounted) return;
      final completion = await Navigator.of(context)
          .push<dynamic>(GamePageRoute<dynamic>(builder: (_) => view));
      // Loadout replacement passes the actual game's completion, not just catalog disposal.
      if (completion is Future<void>) await completion;
    } finally {
      if (localPlay) account.endLocalPlay();
    }
    if (mounted) await _refresh();
  }

  bool _inviting = false;
  Future<void> _inviteAfterPlay() async {
    final account = ref.read(accountProvider);
    if (_inviting ||
        account.verified ||
        !account.api.configured ||
        !_foreground ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _inviting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('cloudInvite.v1.shown') == true) return;
      if (!mounted ||
          !_foreground ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        _inviting = false;
        return;
      }
      await showAccountFlow(
        context,
        account,
        onShown: () => unawaited(
          prefs
              .setBool('cloudInvite.v1.shown', true)
              .catchError((Object _) => false),
        ),
      );
      if (mounted) await _refresh();
    } catch (_) {
      /* Optional identity invitation must not interrupt local play. */
    }
  }

  Future<void> _play() async {
    if (_saved != null) {
      final replace = await confirmRunAction(
        context,
        eyebrow: 'RE-GUN / SAVED RUN',
        title: 'REPLACE SAVED RUN?',
        message: 'Starting a new run replaces your saved run and its upgrades.',
        action: 'New run',
        cancel: 'Keep run',
        destructive: true,
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
      if (mounted) unawaited(_inviteAfterPlay());
    } else {
      final before = LocalPreferences.shared.profile.settledRuns.length;
      await _open(const LoadoutView());
      if (mounted &&
          LocalPreferences.shared.profile.settledRuns.length > before) {
        unawaited(_inviteAfterPlay());
      }
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff171319),
    body: Stack(
      fit: StackFit.expand,
      children: [
        HomeMenu(
          ready: _ready,
          bestScore: LocalPreferences.shared.bestScore,
          reducedMotion: LocalPreferences.shared.reducedMotion,
          onContinue: _saved == null ? null : _continue,
          onPlay: _play,
          onlineAvailable: _online.enabled,
          onlineChecking:
              _openingOnline ||
              _online.state == OnlineAvailabilityState.checking,
          onOnline: _openOnline,
          onTraining: () async {
            await _open(const LoadoutView(training: true));
            if (mounted && LocalPreferences.shared.profile.tutorialComplete) {
              unawaited(_inviteAfterPlay());
            }
          },
          onCollection: () => _open(const CollectionView()),
          onSettings: () => _open(const SettingsView(allowProgressReset: true)),
        ),
        if (_accountIssue != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: IgnorePointer(
              child: GameNoticeStrip(message: _accountIssue!),
            ),
          ),
      ],
    ),
  );
}
