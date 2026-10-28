import 'package:regun/utils/format_number.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/widgets/support_thumbnail.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/widgets/boss_health_strip.dart';
import 'package:regun/widgets/rank_path_preview.dart';
import 'package:regun/services/economy/armory_repository.dart';
import 'package:regun/widgets/solo_revive_panel.dart';
import 'package:regun/systems/training_pressure.dart';
import 'package:regun/widgets/training_weapon_browser.dart';
import 'package:regun/widgets/run_results_panel.dart';
import 'package:regun/models/economy/career_progress.dart';
import 'package:regun/widgets/boss_victory_banner.dart';
import 'package:regun/widgets/wallet_bar.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/widgets/upgrade_offer_copy.dart';
import 'package:regun/systems/upgrade_details.dart';
import 'package:regun/presentation/game_layout.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/run_pause_summary.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/widgets/practice_section.dart';
import 'package:regun/widgets/weapon_practice_tile.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/training_notice.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/theme/upgrade_glyph.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:regun/data/challenges.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/views/settings_view.dart';

import 'dart:async';

import 'package:regun/data/loadout.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

const _brass = Color(0xffE1BA78);
const _paper = Color(0xffE5DDD1);
const _muted = Color(0xffB2A8B4);
const _panel = Color(0xf51D1821);

String runTime(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class BaseView extends StatefulWidget {
  const BaseView({
    super.key,
    this.loadout = const Loadout(),
    this.showTrainingIntro = false,
    this.upgradeFeelMode = UpgradeFeelMode.full,
    this.upgradeFeelReview = false,
    this.reviewControlledSpawns = false,
    this.resumeSnapshot,
    this.runStore,
    this.recoveryTransport,
  });
  final RunStore? runStore;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  recoveryTransport;
  final Loadout loadout;
  final UpgradeFeelMode upgradeFeelMode;
  final bool upgradeFeelReview;
  final bool reviewControlledSpawns;
  final bool showTrainingIntro;
  final Map<String, dynamic>? resumeSnapshot;
  @override
  State<BaseView> createState() => _BaseViewState();
}

class _BaseViewState extends State<BaseView> with WidgetsBindingObserver {
  bool _admissionDenied = false;
  late final RegunGame _myGame;
  final gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState>();
  bool _leaving = false;
  bool _confirmingAction = false;
  late bool _trainingIntro;
  late final bool _guidedTraining;
  bool _skippingTraining = false;
  bool _changingWeapon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _guidedTraining =
        widget.loadout.training &&
        widget.showTrainingIntro &&
        !LocalPreferences.shared.profile.tutorialComplete;
    _trainingIntro = _guidedTraining;
    _admissionDenied =
        !widget.loadout.training &&
        !LocalPreferences.shared.profile.weaponUnlocked(widget.loadout.weapon);
    if (_admissionDenied) return;
    _myGame = RegunGame(
      context,
      startPaused: _trainingIntro,
      loadout: widget.loadout,
      upgradeFeelMode: widget.upgradeFeelMode,
      reviewControlledSpawns: widget.reviewControlledSpawns,
      resumeSnapshot: widget.resumeSnapshot,
      runStore: widget.runStore,
      recoveryTransport: widget.recoveryTransport,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_admissionDenied) return;
    _myGame.applicationActive = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed && _myGame.isMounted) {
      _myGame.pauseGame();
      _myGame.resetInput();
      // This also stops the cosmetic slow world if a picker was open.
      _myGame.pauseEngine();
      unawaited(_myGame.saveCheckpoint());
      _myGame.audio.pauseMusic(true);
    } else if (_myGame.isMounted &&
        _myGame.gameState.gameplayState == GameplayState.powerup) {
      _myGame.resumeEngine();
    }
  }

  @override
  void dispose() {
    if (!_admissionDenied) _myGame.disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _myGame.leaveRun();
    if (!_myGame.loadout.training && _myGame.saveIssue != null) {
      _leaving = false;
      if (mounted) setState(() {});
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _requestRunAction({bool restart = false}) async {
    if (_confirmingAction || _leaving) return;
    if (_myGame.gameState.gameplayState == GameplayState.gameOver) {
      if (restart) {
        _myGame.restartGame();
      } else {
        await _leave();
      }
      return;
    }
    _myGame.pauseGame();
    _myGame.resetInput();
    _confirmingAction = true;
    try {
      final training = _myGame.loadout.training;
      final accepted = await confirmRunAction(
        context,
        title: restart ? 'RESTART RUN?' : 'RETURN TO MENU?',
        message: restart
            ? training
                  ? 'This practice session and its build will reset.'
                  : 'Your current run and upgrades will be replaced.'
            : training
            ? 'This practice session will end.'
            : 'Your run will be saved for Continue.',
        action: restart
            ? 'Restart'
            : training
            ? 'Leave training'
            : 'Save & leave',
        destructive: restart || training,
      );
      if (!mounted || !accepted) return;
      if (restart) {
        _myGame.restartGame();
      } else {
        await _leave();
      }
    } finally {
      _confirmingAction = false;
    }
  }

  Future<void> _skipTrainingIntro() async {
    if (_skippingTraining) return;
    setState(() => _skippingTraining = true);
    await _myGame.completeTraining();
    await _myGame.leaveRun();
    if (!mounted) return;
    final completion = Completer<void>();
    try {
      final next = await Navigator.of(context)
          .pushReplacement<dynamic, Future<void>>(
            GamePageRoute<dynamic>(builder: (_) => const LoadoutView()),
            result: completion.future,
          );
      if (next is Future<void>) await next;
    } finally {
      completion.complete();
    }
  }

  @override
  Widget build(BuildContext context) => _admissionDenied
      ? Scaffold(
          backgroundColor: const Color(0xff141117),
          body: Center(
            child: GameNotice(
              eyebrow: 'RE-GUN / ARMORY',
              title: 'WEAPON LOCKED',
              message: 'Unlock this weapon before starting a normal run. Try it freely in Training.',
              actions: ClickButton(
                text: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        )
      : PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_requestRunAction());
          },
          child: ProviderScope(
            overrides: [gameNotifierProvider.overrideWith(GameNotifier.new)],
            child: Scaffold(
              body: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: FontFam.orbitron),
                child: Stack(
                  children: [
                    RiverpodAwareGameWidget(key: gameWidgetKey, game: _myGame),
                    Consumer(
                      builder: (context, ref, _) {
                        final state = ref.watch(gameNotifierProvider);
                        // Results use Positioned.fill after the HUD is removed.
                        // Keep the overlay full-screen even when no save warning exists.
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: _myGame.revision,
                              builder: (context, _, child) =>
                                  _myGame.saveIssue == null ||
                                      state.gameplayState ==
                                          GameplayState.paused
                                  ? const SizedBox.shrink()
                                  : Positioned(
                                      top: 64,
                                      left: 24,
                                      right: 24,
                                      child: IgnorePointer(
                                        child: GameNoticeStrip(
                                          message: _myGame.saveIssue!,
                                        ),
                                      ),
                                    ),
                            ),
                            if (!_trainingIntro &&
                                state.gameplayState != GameplayState.gameOver &&
                                state.gameplayState != GameplayState.paused)
                              _hud(
                                state,
                                ref.read(gameNotifierProvider.notifier),
                              ),
                            if (!_trainingIntro &&
                                state.gameplayState == GameplayState.playing)
                              Positioned(
                                top: 58,
                                left: 24,
                                right: 24,
                                child: ValueListenableBuilder<BossKind?>(
                                  valueListenable: _myGame.bossVictory.current,
                                  builder: (context, kind, _) => kind == null
                                      ? const SizedBox.shrink()
                                      : BossVictoryBanner(
                                          kind: kind,
                                          verb: _myGame.bossVictory.verb,
                                        ),
                                ),
                              ),
                            if (state.gameplayState == GameplayState.powerup)
                              _upgradePicker(state),
                            if (!_trainingIntro &&
                                state.gameplayState == GameplayState.paused)
                              _pauseMenu(),
                            if (state.gameplayState == GameplayState.gameOver)
                              _results(state),
                            ValueListenableBuilder<int>(
                              valueListenable: _myGame.revision,
                              builder: (context, _, child) =>
                                  _myGame.recovery.pending
                                  ? _recoveryPanel()
                                  : const SizedBox.shrink(),
                            ),
                            if (_trainingIntro) ...[
                              const ModalBarrier(
                                dismissible: false,
                                color: Color(0xD9100D14),
                              ),
                              SafeArea(
                                minimum: const EdgeInsets.all(16),
                                child: Center(
                                  child: TrainingNotice(
                                    ready:
                                        state.gameplayState ==
                                            GameplayState.paused &&
                                        !_skippingTraining,
                                    onStart: () {
                                      setState(() => _trainingIntro = false);
                                      _myGame.gameNotifier.playGame();
                                    },
                                    onSkip: _skipTrainingIntro,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

  double get _hudScale => GameLayout.uiScale(MediaQuery.sizeOf(context));

  Widget _hud(GameState state, GameNotifier notifier) => SafeArea(
    child: Column(
      children: [
        IgnorePointer(
          child: LinearProgressIndicator(
            value: (state.xP / state.noOfCoinsToUpgrade.floor()).clamp(0, 1),
            minHeight: 3,
            color: _brass,
            backgroundColor: const Color(0x66352A35),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Pause',
              constraints: BoxConstraints(
                minWidth: 48 * _hudScale,
                minHeight: 48 * _hudScale,
              ),
              onPressed: _myGame.pauseGame,
              icon: SizedBox(
                width: 22 * _hudScale,
                height: 24 * _hudScale,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 7, color: _paper),
                    Container(width: 7, color: _paper),
                  ],
                ),
              ),
            ),
            _readout(runTime(state.survivalSeconds), 'SURVIVAL'),
            const Spacer(),
            Text(
              'L${state.currentLevel} / C${state.bosses ~/ 3 + 1}',
              style: const TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: 10,
                color: _brass,
              ),
            ),
            const SizedBox(width: 20),
            ValueListenableBuilder<int>(
              valueListenable: _myGame.damageFeedback.healthLost,
              builder: (context, lost, _) => Semantics(
                label: 'Health ${state.health}',
                child: Container(
                  width: 90 * _hudScale,
                  height: 44 * _hudScale,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: lost > 0
                        ? const Color(0x993D2525)
                        : Colors.transparent,
                    border: Border.all(
                      color: lost > 0
                          ? const Color(0xffEF8B76)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/heart.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${state.health}',
                                style: TextStyle(
                                  fontFamily: FontFam.orbitron,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: lost > 0
                                      ? const Color(0xffEF8B76)
                                      : _paper,
                                ),
                              ),
                              if (lost > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '-$lost',
                                      style: const TextStyle(
                                        fontFamily: FontFam.pressStart,
                                        fontSize: 7,
                                        color: Color(0xffEF8B76),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Image.asset(
                                      'assets/images/heart.png',
                                      key: const Key('health-loss-heart'),
                                      width: 12,
                                      height: 12,
                                      filterQuality: FilterQuality.none,
                                      excludeFromSemantics: true,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            _readout(formatNumber(state.kills), 'KILLS'),
            const SizedBox(width: 12),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: _myGame.revision,
          builder: (context, _, child) {
            final bosses = _myGame.bosses
                .where((boss) => boss.isLoaded && !boss.isRemoving)
                .toList();
            final walker = _myGame.walkerCandidate;
            if (walker != null && walker.prepared) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: BossHealthStrip(
                      name: 'WALKER',
                      fraction: walker.combatHealth.fraction,
                      enraged:
                          walker.combatHealth.fraction <= .5 &&
                          !walker.combatHealth.isDead,
                    ),
                  ),
                  Text(
                    walker.fight.label,
                    style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 11,
                      color: _brass,
                    ),
                  ),
                  if (walker.fight.finished)
                    ClickButton(
                      text: 'Fight again',
                      width: 155,
                      height: 40,
                      onTap: _myGame.practiceWalker,
                    ),
                ],
              );
            }
            if (bosses.isEmpty) return const SizedBox.shrink();
            return IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final boss in bosses)
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: BossHealthStrip(
                            key: ValueKey(
                              'boss-health-${(boss as BossEncounter).kind.name}',
                            ),
                            name: (boss as BossEncounter).kind.title,
                            fraction:
                                (boss as CombatEnemy).combatHealth.fraction,
                            enraged: (boss as BossEncounter).enraged,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (notifier.canFuse && state.gameplayState == GameplayState.playing)
          ClickButtonM(
            text: 'Fuse core',
            width: 150,
            height: 40,
            onTap: notifier.openBossCore,
          ),
        if (widget.loadout.training && _myGame.bossRush)
          ValueListenableBuilder<int>(
            valueListenable: _myGame.revision,
            builder: (context, _, child) => Text(
              'BOSS RUSH / ROUND ${_myGame.bossRushRound} / PRACTICE HEALTH',
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                color: _brass,
              ),
            ),
          ),
        if (_guidedTraining && !_myGame.bossRush && _myGame.bosses.isEmpty)
          ValueListenableBuilder<int>(
            valueListenable: _myGame.revision,
            builder: (context, _, child) => Column(
              children: [
                Text(
                  _myGame.trainingHint,
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 12,
                    color: _brass,
                  ),
                ),
                if (_myGame.trainingStep < 5)
                  ClickButtonM(
                    text: 'Skip',
                    width: 100,
                    height: 44,
                    onTap: () async {
                      await _myGame.completeTraining();
                      await _leave();
                    },
                  ),
                if (_myGame.trainingStep >= 5)
                  ClickButton(
                    text: 'Ready',
                    width: 130,
                    height: 44,
                    onTap: () async {
                      await _myGame.completeTraining();
                      await _leave();
                    },
                  ),
              ],
            ),
          ),
        const Spacer(),
        IgnorePointer(
          child: SizedBox(
            height: 100 * _hudScale,
            width: 220 * _hudScale,
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: notifier.quickRefillProgress,
                builder: (context, refill, child) => refill >= 0
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WeaponReloadDisplay(
                            weapon: _myGame.loadout.weapon,
                            progress: _myGame.preferences.reducedMotion
                                ? 1
                                : refill,
                            shells: 1,
                            reducedMotion: _myGame.preferences.reducedMotion,
                          ),
                          const Text(
                            'MAG READY',
                            style: TextStyle(
                              fontFamily: FontFam.pressStart,
                              fontSize: 8,
                              color: _brass,
                            ),
                          ),
                        ],
                      )
                    : child!,
                child: state.reloading
                    ? ValueListenableBuilder<bool>(
                        valueListenable: _myGame.confirmationHolding,
                        builder: (context, held, child) => TickerMode(
                          enabled:
                              state.gameplayState == GameplayState.playing &&
                              !held,
                          child: child!,
                        ),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _myGame.gameNotifier.reloadProgress,
                          builder: (context, progress, _) =>
                              WeaponReloadDisplay(
                                weapon: _myGame.loadout.weapon,
                                progress: progress,
                                tactical: notifier.reloadTactical,
                                reducedMotion:
                                    _myGame.preferences.reducedMotion,
                                shells: state.maxBullets - state.noOfBullets,
                              ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _myGame.loadout.weapon.title.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: FontFam.pressStart,
                              fontSize: 8,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_myGame.breachEngine)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'BREACH ENGINE',
                                style: TextStyle(
                                  fontFamily: FontFam.pressStart,
                                  fontSize: 9,
                                  color: _brass,
                                ),
                              ),
                            ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: List.generate(
                              state.maxBullets.clamp(0, 15),
                              (i) => Container(
                                width: 6,
                                height: 17,
                                color:
                                    i <
                                        ((_myGame.loadout.weapon ==
                                                        WeaponType.prismCutter
                                                    ? state.maxBullets -
                                                          state.noOfBullets
                                                    : state.noOfBullets) /
                                                state.maxBullets *
                                                state.maxBullets.clamp(0, 15))
                                            .ceil()
                                    ? _brass
                                    : const Color(0x88695A66),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _myGame.loadout.weapon == WeaponType.prismCutter
                                ? 'HEAT ${state.maxBullets - state.noOfBullets} / ${state.maxBullets}'
                                : '${state.noOfBullets} / ${state.maxBullets}',
                            style: const TextStyle(
                              fontFamily: FontFam.orbitron,
                              fontSize: 12,
                              color: _paper,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _readout(String value, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 18,
            color: _paper,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 1.4,
            color: _muted,
          ),
        ),
      ],
    ),
  );

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      GamePageRoute(
        builder: (_) => SettingsView(onControlsChanged: _myGame.setControls),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _pauseMenu() => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xe8141117),
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            widget.loadout.training
                                ? 'TRAINING PAUSED'
                                : 'PAUSED',
                            style: const TextStyle(
                              fontFamily: FontFam.pressStart,
                              fontSize: 14,
                              height: 1.6,
                              color: _paper,
                            ),
                          ),
                          const WalletBar(showLabels: false),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ClickButtonM(
                      key: const Key('pause-menu-home'),
                      onTap: () => _requestRunAction(),
                      text: 'Menu',
                      width: 100,
                      height: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClickButton(
                        onTap: _myGame.resumeGame,
                        text: 'Resume',
                        glyph: PixelGlyph.play,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClickButton(
                        onTap: () => _requestRunAction(restart: true),
                        buttonColor: _muted,
                        text: 'Restart',
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClickButton(
                        onTap: _openSettings,
                        text: 'Settings',
                        glyph: PixelGlyph.settings,
                        buttonColor: _muted,
                        height: 48,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_myGame.saveIssue != null) ...[
                  const GameNoticeStrip(
                    message:
                        'Run could not be saved. Stay here and try Menu again.',
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: MenuScrollBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.loadout.training) ...[
                          Text(
                            'This run: +${formatNumber(_myGame.earnedScrap)} Scrap',
                            style: const TextStyle(color: _brass, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_myGame.gameNotifier.canFuse) ...[
                          ClickButton(
                            text: 'Fuse core',
                            height: 48,
                            onTap: _myGame.gameNotifier.openBossCore,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.loadout.training)
                          ..._trainingSections()
                        else
                          RunPauseSummary(
                            state: _myGame.gameState,
                            loadout: _myGame.loadout,
                            reloadSeconds:
                                _myGame.gameNotifier.reloadRemainingSeconds,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _trainingSections() => [
    PracticeSection(
      key: const Key('practice-ranks'),
      title: 'RANK COMPARISON',
      summary: 'Compare III, IV and VIII with this loadout',
      builder: (_) => RankPathPreview(
        state: _myGame.gameState,
        weapon: _myGame.loadout.weapon,
        character: _myGame.loadout.character,
        power: _myGame.gameNotifier.weaponPower,
      ),
    ),
    const SizedBox(height: 12),
    PracticeSection(
      key: const Key('practice-weapons'),
      title: 'WEAPON PRACTICE',
      summary: '${_myGame.loadout.weapon.title} equipped / choose a weapon',
      builder: (_) => TrainingWeaponBrowser(
        selected: _myGame.loadout.weapon,
        preferences: _myGame.preferences,
        builder: (weapons, details) => MenuCardGrid(
          minColumnWidth: 180,
          children: [
            for (final weapon in weapons)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WeaponPracticeTile(
                    key: ValueKey('practice-weapon-${weapon.name}'),
                    weapon: weapon,
                    selected: weapon == _myGame.loadout.weapon,
                    onTap: _changingWeapon
                        ? null
                        : () async {
                            setState(() => _changingWeapon = true);
                            try {
                              await _myGame.changeTrainingWeapon(weapon);
                            } finally {
                              if (mounted) {
                                setState(() => _changingWeapon = false);
                              }
                            }
                          },
                  ),
                  if (weapon == _myGame.loadout.weapon && details != null)
                    details,
                ],
              ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    PracticeSection(
      key: const Key('practice-survival'),
      title: 'SURVIVAL PRACTICE',
      summary: _myGame.trainingDamage
          ? 'Damage on / return after falling'
          : 'Damage off / practice safely',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsChoice(
            label: 'Take damage',
            options: [
              PixelOption(
                label: 'Off',
                width: 80,
                selected: !_myGame.trainingDamage,
                onTap: () => setState(() => _myGame.setTrainingDamage(false)),
              ),
              PixelOption(
                label: 'On',
                width: 80,
                selected: _myGame.trainingDamage,
                onTap: () => setState(() => _myGame.setTrainingDamage(true)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsChoice(
            label: 'Enemy pressure',
            options: [
              for (final pressure in TrainingPressure.values)
                PixelOption(
                  label: pressure.label,
                  width: pressure == TrainingPressure.normal ? 110 : 96,
                  selected: _myGame.trainingPressure == pressure,
                  onTap: () =>
                      setState(() => _myGame.setTrainingPressure(pressure)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _myGame.bossRush
                ? 'Boss Rush clears the field. Enemy pressure resumes in individual boss practice.'
                : 'Individual bosses fight alongside this crowd. Boss Rush stays boss-only.',
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 10,
              height: 1.5,
              color: _muted,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    if (widget.upgradeFeelReview) ...[
      PracticeSection(
        title: 'UPGRADE FEEL REVIEW',
        summary: 'Choose a comparison family',
        builder: (_) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in [
              PowerUp.heavyLoad,
              PowerUp.walkingSpeedIncrease,
              PowerUp.scrapArmour,
              PowerUp.hotShot,
              PowerUp.ricochet,
            ])
              ClickButton(
                text: p.title,
                width: 220,
                height: 48,
                onTap: () => _myGame.gameNotifier.offerUpgradeFeelPractice(p),
              ),
            ClickButton(
              text: 'Sentry Gun',
              width: 220,
              height: 48,
              onTap: () => _myGame.practiceSupport(SupportFamily.sentry),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ],
    if (widget.loadout.arena == ArenaType.breach) ...[
      PracticeSection(
        key: const Key('practice-supply'),
        title: 'SUPPLY PRACTICE',
        summary: 'Airdrop and support',
        builder: (_) => Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ClickButton(
                text: 'Call airdrop',
                width: 200,
                height: 48,
                onTap: _myGame.practiceSupplyDrop,
              ),
              for (final family in SupportFamily.values)
                ClickButton(
                  text: family == SupportFamily.sentry
                      ? 'Sentry practice'
                      : 'Aura Salad practice',
                  width: 200,
                  height: 48,
                  onTap:
                      _myGame.bossRush ||
                          _myGame.gameNotifier.support.busy.contains(
                            family.name,
                          )
                      ? null
                      : () => _myGame.practiceSupport(family),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
    PracticeSection(
      key: const Key('practice-bosses'),
      title: 'BOSS PRACTICE',
      summary: _myGame.bossRush
          ? 'Rush active / round ${_myGame.bossRushRound}'
          : 'Choose a boss or start a random rush',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ClickButton(
                text: _myGame.bossRush ? 'Restart rush' : 'Start rush',
                width: 180,
                height: 48,
                onTap: _myGame.startBossRush,
              ),
              if (_myGame.bossRush)
                ClickButtonM(
                  text: 'Next round',
                  width: 160,
                  height: 48,
                  onTap: _myGame.nextBossRushRound,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Random bosses. Sometimes two.',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 12,
              color: _muted,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'CHOOSE A BOSS',
            style: TextStyle(
              fontFamily: FontFam.pressStart,
              fontSize: 9,
              color: _brass,
            ),
          ),
          const SizedBox(height: 12),
          MenuCardGrid(
            minColumnWidth: 180,
            children: [
              for (final kind in BossKind.active)
                ClickButtonM(
                  key: kind == BossKind.walker
                      ? const Key('practice-boss-walker')
                      : null,
                  text: kind.title,
                  height: 48,
                  onTap: kind == BossKind.walker ? _myGame.practiceWalker : () => _myGame.practiceBoss(kind),
                ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    PracticeSection(
      key: const Key('practice-fusions'),
      title: 'FUSION PRACTICE',
      summary: 'Try a fusion build',
      builder: (_) => MenuCardGrid(
        minColumnWidth: 180,
        children: [
          for (final recipe in fusionRecipes)
            ClickButtonM(
              text: recipe.title,
              height: 48,
              onTap: () => _myGame.gameNotifier.prepareTrainingFusion(recipe),
            ),
        ],
      ),
    ),
  ];

  Widget _upgradePicker(GameState state) {
    final practice = _myGame.gameNotifier.offerSource == 'practice';
    final title = practice
        ? 'PRACTICE'
        : state.evolutionChoices.isNotEmpty
        ? 'FUSE'
        : _myGame.gameNotifier.supplyOffer
        ? 'AIRDROP'
        : 'UPGRADE';
    final subtitle = practice
        ? null
        : state.evolutionChoices.isNotEmpty
        ? null
        : _myGame.gameNotifier.supplyOffer
        ? 'Supply secured'
        : 'Level ${state.currentLevel}';
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB30D0A10),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 16,
                      height: 1.3,
                      color: _paper,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('upgrade-offer-scroll'),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            ((state.evolutionChoices.length +
                                            state.powerUpChoices.length +
                                            (_myGame
                                                        .gameNotifier
                                                        .support
                                                        .offer ==
                                                    null
                                                ? 0
                                                : 1)) *
                                        282 -
                                    12)
                                .clamp(210, 900)
                                .toDouble(),
                      ),
                      child: MenuCardGrid(
                        minColumnWidth: 210,
                        children: [
                          for (final id in state.evolutionChoices)
                            _upgradeCard(
                              fusionRecipes.firstWhere((r) => r.id == id).title,
                              fusionRecipes
                                  .firstWhere((r) => r.id == id)
                                  .description,
                              'FUSION',
                              () => _myGame.gameNotifier.fuse(
                                id,
                                offerId: state.offerId,
                              ),
                              glyph: fusionGlyph(id),
                            ),
                          if (_myGame.gameNotifier.support.offer
                              case final card?)
                            _upgradeCard(
                              '${card.title} ${card.rankLabel}',
                              card.description(
                                _myGame
                                        .gameNotifier
                                        .weaponPower
                                        .snapshot
                                        ?.values ??
                                    {},
                              ),
                              'AIRDROP ONLY / ${(_myGame.gameNotifier.support.tiers[card.family.name] ?? 0) == supportMaxTier ? 'DEPLOY AGAIN' : 'TEMPORARY'}',
                              () => _myGame.gameNotifier.chooseSupport(
                                card.id,
                                offerId: state.offerId,
                              ),
                              artwork: SupportThumbnail(
                                card: card,
                                width: 48,
                                height: 40,
                              ),
                              onBan:
                                  state.bans > 0 &&
                                      _myGame.gameNotifier.offerSource !=
                                          'practice'
                                  ? () => _myGame.gameNotifier.banSupport(
                                      card.id,
                                      offerId: state.offerId,
                                    )
                                  : null,
                            ),
                          for (final choice in state.powerUpChoices)
                            _upgradeCard(
                              choice == PowerUp.dashCapacity &&
                                      state.rank(choice) > 0
                                  ? 'Triple Dash'
                                  : choice.title,
                              upgradeDescription(
                                choice,
                                rank: state.rank(choice),
                              ),
                              choice == PowerUp.salvage
                                  ? 'RECOVERY'
                                  : '${choice.group.name.toUpperCase()} / ${state.rank(choice) + 1} OF ${state.rankLimit(choice)}${choice.group == UpgradeGroup.special && state.rank(choice) == 0 && state.ranks.keys.where((p) => p.group == UpgradeGroup.special).length == 5 ? ' / FINAL SLOT' : ''}',
                              () => _myGame.gameNotifier.applyPowerUp(
                                choice,
                                offerId: state.offerId,
                              ),
                              copy: UpgradeOfferCopy(
                                key: ValueKey(
                                  '${state.offerId}-${choice.name}-${state.rank(choice)}',
                                ),
                                description: upgradeDescription(
                                  choice,
                                  rank: state.rank(choice),
                                ),
                                summary: upgradeDetails(
                                  choice,
                                  state,
                                  _myGame.loadout.weapon,
                                  balance: _myGame.gameNotifier.buildBalance,
                                  power: _myGame.gameNotifier.weaponPower,
                                  character: _myGame.loadout.character,
                                  brief: true,
                                ),
                                details: upgradeDetails(
                                  choice,
                                  state,
                                  _myGame.loadout.weapon,
                                  balance: _myGame.gameNotifier.buildBalance,
                                  power: _myGame.gameNotifier.weaponPower,
                                  character: _myGame.loadout.character,
                                ),
                                initiallyExpanded: _myGame.loadout.training,
                              ),
                              glyph: choice.glyph,
                              onBan: state.bans > 0 && choice != PowerUp.salvage
                                  ? () => _myGame.gameNotifier.ban(
                                      choice,
                                      offerId: state.offerId,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (state.evolutionChoices.isEmpty &&
                  state.rerolls > 0 &&
                  _myGame.gameNotifier.offerSource != 'practice')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClickButtonM(
                    key: const Key('upgrade-reroll'),
                    text: 'Reroll (${state.rerolls})',
                    width:
                        170 *
                        MediaQuery.textScalerOf(context)
                            .scale(1)
                            .clamp(1.0, 2.0),
                    height: 48,
                    onTap: () =>
                        _myGame.gameNotifier.reroll(offerId: state.offerId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upgradeCard(
    String title,
    String description,
    String category,
    VoidCallback onTap, {
    VoidCallback? onBan,
    Widget? copy,
    Widget? artwork,
    PixelGlyph glyph = PixelGlyph.star,
  }) => SizedBox(
    key: ValueKey('upgrade-card-$title'),
    width: 210,
    child: Material(
      color: _panel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).height < 460 ? 12 : 16,
          ),
          constraints: const BoxConstraints(minHeight: 148),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff75604C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  artwork ??
                      PixelIcon(
                        glyph,
                        size: 32,
                        key: ValueKey('upgrade-glyph-$title'),
                      ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: FontFam.pressStart,
                            fontSize: 11,
                            height: 1.5,
                            color: _paper,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category,
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 9,
                            color: _brass,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              copy ??
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 12,
                      height: 1.4,
                      color: _muted,
                    ),
                  ),
              const Spacer(),
              if (onBan != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onBan,
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      overlayColor: _brass.withValues(alpha: 0.1),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text(
                      'BAN',
                      style: TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 10,
                        color: _muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _recoveryPanel() => Positioned.fill(
    child: SoloRevivePanel(
      state: _myGame.gameState,
      recovery: _myGame.recovery,
      banked: _myGame.preferences.profile.scrap,
      onBuy: _myGame.buySoloRecovery,
      onRetry: _myGame.checkSoloRecovery,
      onEnd: _myGame.endRecoveryRun,
      onMenu: _leave,
    ),
  );

  Widget _results(GameState state) => Positioned.fill(
    child: ValueListenableBuilder<int>(
      valueListenable: _myGame.revision,
      builder: (context, _, child) {
        final goal = CareerProgress(
          _myGame.preferences.profile,
          armory: ArmoryRepository.shared.catalog,
        ).next;
        return RunResultsPanel(
          state: state,
          earnedScrap: _myGame.earnedScrap,
          scrapBreakdown: _myGame.scrapReward.breakdown,
          nextGoal: goal == null ? null : '${goal.title} / ${goal.detail}',
          record:
              '${_myGame.recovery.continued
                  ? 'REVIVED BEST ${formatNumber(_myGame.preferences.profile.continuedBestScore)}'
                  : _myGame.assisted
                  ? 'ASSISTED BEST ${formatNumber(_myGame.preferences.profile.assistedBestScore)}'
                  : 'BEST ${formatNumber(_myGame.preferences.bestScore)}'} / LONGEST ${runTime(_myGame.recovery.continued
                  ? _myGame.preferences.profile.continuedBestSeconds
                  : _myGame.assisted
                  ? _myGame.preferences.profile.assistedBestSeconds
                  : _myGame.preferences.bestSeconds)}',
          unlocks: [
            for (final id in _myGame.newUnlocks)
              challenges.where((c) => c.id == id).firstOrNull?.reward ?? id,
          ],
          onRestart: _myGame.restartGame,
          onMenu: _leave,
        );
      },
    ),
  );
}
