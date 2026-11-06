import 'package:regun/desktop/desktop_combat_kit.dart';
import 'package:regun/desktop/web_landscape_prompt.dart';
import 'package:regun/desktop/desktop_field_frame.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:regun/desktop/desktop_combat_surface.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
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
  bool _gameLoadFailed = false;
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
      desktopInput: desktopInputAvailable ? DesktopCombatInput() : null,
      loadout: widget.loadout,
      upgradeFeelMode: widget.upgradeFeelMode,
      reviewControlledSpawns: widget.reviewControlledSpawns,
      resumeSnapshot: widget.resumeSnapshot,
      runStore: widget.runStore,
      recoveryTransport: widget.recoveryTransport,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_admissionDenied) return;
    final blocked = WebLandscapePrompt.blocksPlay(context);
    if (blocked == _myGame.viewportBlocked) return;
    _myGame.viewportBlocked = blocked;
    if (!blocked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_myGame.viewportBlocked || !_myGame.isMounted) return;
      if (_myGame.gameState.gameplayState == GameplayState.playing) {
        _myGame.pauseGame();
      } else {
        _myGame.resetInput();
      }
    });
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

  Widget _gameLoadError(BuildContext context, Object error) {
    if (!_gameLoadFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _gameLoadFailed) return;
        debugPrint('Regun could not load the arena: $error');
        setState(() => _gameLoadFailed = true);
      });
    }
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Center(
        child: GameNotice(
          eyebrow: 'RE-GUN',
          title: 'ARENA UNAVAILABLE',
          message: 'The arena could not load. Go back and try again.',
          actions: ClickButton(
            text: 'Go back',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _skipTrainingIntro() async {
    if (_skippingTraining) return;
    setState(() => _skippingTraining = true);
    await _myGame.completeTraining();
    if (_myGame.isMounted) await _myGame.leaveRun();
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
              message: 'Earn this weapon before equipping it.',
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
                    if (_myGame.desktopInput == null)
                      RiverpodAwareGameWidget(
                        key: gameWidgetKey,
                        game: _myGame,
                        errorBuilder: _gameLoadError,
                      )
                    else
                      Consumer(
                        child: RiverpodAwareGameWidget(
                          key: gameWidgetKey,
                          game: _myGame,
                          autofocus: false,
                          errorBuilder: _gameLoadError,
                        ),
                        builder: (context, ref, child) => DesktopCombatSurface(
                          game: _myGame,
                          playing:
                              !_trainingIntro &&
                              ref.watch(
                                    gameNotifierProvider.select(
                                      (state) => state.gameplayState,
                                    ),
                                  ) ==
                                  GameplayState.playing,
                          child: child!,
                        ),
                      ),
                    Consumer(
                      builder: (context, ref, _) {
                        if (_gameLoadFailed) return const SizedBox.shrink();
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
                                        GameplayState.paused,
                                    skipping: _skippingTraining,
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

  double get _hudScale => desktopInputAvailable
      ? 1
      : GameLayout.uiScale(MediaQuery.sizeOf(context));

  EdgeInsets get _desktopHudInsets {
    if (!desktopInputAvailable) return EdgeInsets.zero;
    final size = MediaQuery.sizeOf(context);
    final world = GameLayout.desktopWorld(size);
    final fitted = applyBoxFit(BoxFit.contain, world, size).destination;
    return EdgeInsets.symmetric(
      horizontal: (size.width - fitted.width) / 2 + 20,
      vertical: (size.height - fitted.height) / 2 + 12,
    );
  }

  Widget _hud(GameState state, GameNotifier notifier) => SafeArea(
    minimum: _desktopHudInsets,
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
        _hudHeader(
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
                style: TextStyle(
                  fontFamily: FontFam.pressStart,
                  fontSize: desktopInputAvailable ? 12 : 10,
                  color: _brass,
                ),
              ),
              const SizedBox(width: 20),
              ValueListenableBuilder<int>(
                valueListenable: _myGame.damageFeedback.healthLost,
                builder: (context, lost, _) => Semantics(
                  label: 'Health ${state.health}',
                  child: Container(
                    width: desktopInputAvailable ? 106 : 90 * _hudScale,
                    height: desktopInputAvailable ? 54 : 44 * _hudScale,
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
                                    fontSize: desktopInputAvailable ? 25 : 20,
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
        ),
        ValueListenableBuilder<int>(
          valueListenable: _myGame.revision,
          builder: (context, _, child) {
            final bosses = _myGame.bosses
                .where((boss) => boss.isLoaded && !boss.isRemoving)
                .toList();
            final lodestar = _myGame.lodestarCandidate;
            if (lodestar != null && lodestar.prepared) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: BossHealthStrip(
                      name: 'LODESTAR',
                      fraction: lodestar.combatHealth.fraction,
                      enraged:
                          lodestar.fight.enraged && !lodestar.fight.defeated,
                    ),
                  ),
                  if (lodestar.fight.finished)
                    ClickButton(
                      text: 'Fight again',
                      width: 155,
                      height: 40,
                      onTap: _myGame.practiceLodestar,
                    ),
                ],
              );
            }
            final ariet = _myGame.arietCandidate;
            if (ariet != null && ariet.prepared) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: BossHealthStrip(
                      name: 'ARIET',
                      fraction: ariet.combatHealth.fraction,
                      enraged:
                          ariet.combatHealth.fraction <= .5 &&
                          !ariet.combatHealth.isDead,
                    ),
                  ),
                  if (ariet.fight.finished)
                    ClickButton(
                      text: 'Fight again',
                      width: 155,
                      height: 40,
                      onTap: _myGame.practiceAriet,
                    ),
                ],
              );
            }
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
        if (desktopInputAvailable)
          ListenableBuilder(
            listenable: Listenable.merge([
              _myGame.desktopKitStatus,
              notifier.reloadProgress,
              notifier.quickRefillProgress,
            ]),
            builder: (context, _) {
              final kit = _myGame.desktopKitStatus.value;
              return DesktopCombatKit(
                weapon: _myGame.loadout.weapon,
                ammo: state.noOfBullets,
                capacity: state.maxBullets,
                dash: kit.dash,
                grenade: kit.grenade,
                dashRecharge: kit.dashRecharge,
                grenadeRecharge: kit.grenadeRecharge,
                controller: kit.controller,
                reducedMotion: _myGame.preferences.reducedMotion,
                reload: state.reloading ? notifier.reloadProgress.value : -1,
                refill: notifier.quickRefillProgress.value,
                tactical: notifier.reloadTactical,
                breachEngine: _myGame.breachEngine,
              );
            },
          )
        else
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
                            valueListenable:
                                _myGame.gameNotifier.reloadProgress,
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
                              textAlign: TextAlign.center,
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
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: desktopInputAvailable ? 24 : 18,
            color: _paper,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: desktopInputAvailable ? 11 : 8,
            letterSpacing: 1.4,
            color: _muted,
          ),
        ),
      ],
    ),
  );

  Widget _hudHeader(Widget row) {
    if (!desktopInputAvailable) return row;
    return LayoutBuilder(
      builder: (context, box) {
        final comfortableWidth =
            440 * MediaQuery.textScalerOf(context).scale(1);
        if (box.maxWidth >= comfortableWidth) return row;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: comfortableWidth, child: row),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      GamePageRoute(
        builder: (_) => SettingsView(onControlsChanged: _myGame.setControls),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _pauseMenu() =>
      desktopInputAvailable ? _desktopPauseMenu() : _mobilePauseMenu();

  Widget _desktopPauseMenu() {
    final training = widget.loadout.training;
    final state = _myGame.gameState;
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        ClickButton(
          text: 'Resume',
          height: 76,
          fontSize: 18,
          autofocus: true,
          glyph: PixelGlyph.play,
          onTap: _myGame.resumeGame,
        ),
        ClickButton(
          text: 'Settings',
          height: 60,
          fontSize: 14,
          glyph: PixelGlyph.settings,
          buttonColor: _muted,
          onTap: _openSettings,
        ),
        ClickButton(
          text: 'Restart',
          height: 60,
          fontSize: 14,
          buttonColor: _muted,
          onTap: () => _requestRunAction(restart: true),
        ),
        ClickButtonM(
          key: const Key('pause-menu-home'),
          text: 'Menu',
          height: 60,
          fontSize: 14,
          onTap: () => _requestRunAction(),
        ),
        if (_myGame.gameNotifier.canFuse)
          ClickButton(
            text: 'Fuse core',
            height: 60,
            fontSize: 14,
            onTap: _myGame.gameNotifier.openBossCore,
          ),
      ],
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          training ? 'Practice' : 'Run summary',
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: _paper,
          ),
        ),
        if (_myGame.saveIssue != null)
          const GameNoticeStrip(
            message: 'Run could not be saved. Stay here and try Menu again.',
          ),
        if (training)
          ..._trainingSections()
        else
          RunPauseSummary(
            desktop: true,
            state: state,
            loadout: _myGame.loadout,
            reloadSeconds: _myGame.gameNotifier.reloadRemainingSeconds,
          ),
      ],
    );
    return Positioned.fill(
      child: DesktopFieldFrame(
        openCenter: MediaQuery.sizeOf(context).width >= 840,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 740;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  _myGame.loadout.arena.title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: _brass,
                  ),
                ),
                Text(
                  'PAUSED',
                  style: TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: wide ? 48 : 30,
                    height: 1.3,
                    color: _paper,
                  ),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    const WalletBar(showLabels: false, readOnly: true),
                  ],
                ),
                const Divider(height: 36, color: Color(0xff756044)),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: (box.maxWidth * .26).clamp(250, 420),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(child: actions),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: (box.maxWidth * .40).clamp(360, 640),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Color(0xffad8957),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: summary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 24,
                            children: [actions, summary],
                          ),
                        ),
                ),
                const Divider(height: 32, color: Color(0xff756044)),
                Text(
                  training
                      ? 'TRAINING  /  ${runTime(state.survivalSeconds)}'
                      : 'SURVIVAL  /  ${runTime(state.survivalSeconds)}  /  +${formatNumber(_myGame.earnedScrap)} SCRAP',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: _brass,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mobilePauseMenu() => Positioned.fill(
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
                          const WalletBar(showLabels: false, readOnly: true),
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
        preferences: _myGame.preferences,
        builder: (weapons) => MenuCardGrid(
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
          if (_myGame.lodestarTrial) ...[
            const SizedBox(height: 12),
            MenuCardGrid(
              minColumnWidth: 160,
              children: [
                ClickButtonM(
                  text: 'All attacks',
                  height: 48,
                  onTap: () => _myGame.practiceLodestarMove(null),
                ),
                for (final move in LodestarMove.values)
                  ClickButtonM(
                    text: move.name,
                    height: 48,
                    onTap: () => _myGame.practiceLodestarMove(move),
                  ),
              ],
            ),
          ],
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
              ClickButtonM(
                key: const Key('practice-boss-lodestar'),
                text: 'Lodestar',
                height: 48,
                onTap: _myGame.practiceLodestar,
              ),
              ClickButtonM(
                key: const Key('practice-boss-ariet'),
                text: 'Ariet',
                height: 48,
                onTap: _myGame.practiceAriet,
              ),
              for (final kind in BossKind.active.where(
                (kind) => kind != BossKind.ariet && kind != BossKind.lodestar,
              ))
                ClickButtonM(
                  key: kind == BossKind.walker
                      ? const Key('practice-boss-walker')
                      : null,
                  text: kind.title,
                  height: 48,
                  onTap: kind == BossKind.walker
                      ? _myGame.practiceWalker
                      : () => _myGame.practiceBoss(kind),
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
    final desktop = desktopInputAvailable;
    final heading = Wrap(
      alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: FontFam.pressStart,
            fontSize: desktop ? 32 : 16,
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
    );
    final cards = MenuCardGrid(
      minColumnWidth: 210,
      children: [
        for (final id in state.evolutionChoices)
          _upgradeCard(
            fusionRecipes.firstWhere((r) => r.id == id).title,
            fusionRecipes.firstWhere((r) => r.id == id).description,
            'FUSION',
            () => _myGame.gameNotifier.fuse(id, offerId: state.offerId),
            glyph: fusionGlyph(id),
          ),
        if (_myGame.gameNotifier.support.offer case final card?)
          _upgradeCard(
            '${card.title} ${card.rankLabel}',
            card.description(
              _myGame.gameNotifier.weaponPower.snapshot?.values ?? {},
            ),
            'SUPPORT / ${(_myGame.gameNotifier.support.tiers[card.family.name] ?? 0) == supportMaxTier ? 'DEPLOY AGAIN' : 'TEMPORARY'}',
            () => _myGame.gameNotifier.chooseSupport(
              card.id,
              offerId: state.offerId,
            ),
            artwork: SupportThumbnail(card: card, width: 48, height: 40),
            onBan:
                state.bans > 0 && _myGame.gameNotifier.offerSource != 'practice'
                ? () => _myGame.gameNotifier.banSupport(
                    card.id,
                    offerId: state.offerId,
                  )
                : null,
          ),
        for (final choice in state.powerUpChoices)
          _upgradeCard(
            choice == PowerUp.dashCapacity && state.rank(choice) > 0
                ? 'Triple Dash'
                : choice.title,
            upgradeDescription(choice, rank: state.rank(choice)),
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
              description: upgradeDescription(choice, rank: state.rank(choice)),
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
                ? () => _myGame.gameNotifier.ban(choice, offerId: state.offerId)
                : null,
          ),
      ],
    );
    final canReroll =
        state.evolutionChoices.isEmpty && state.rerolls > 0 && !practice;
    final reroll = Padding(
      padding: EdgeInsets.only(top: desktop ? 20 : 8),
      child: ClickButtonM(
        key: const Key('upgrade-reroll'),
        text: 'Reroll (${state.rerolls})',
        width: 170 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
        height: 48,
        onTap: () => _myGame.gameNotifier.reroll(offerId: state.offerId),
      ),
    );
    final scroll = SingleChildScrollView(
      key: const Key('upgrade-offer-scroll'),
      child: desktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cards,
                if (canReroll)
                  Align(alignment: Alignment.centerLeft, child: reroll),
              ],
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (cards.children.length * 282 - 12)
                      .clamp(210, 900)
                      .toDouble(),
                ),
                child: cards,
              ),
            ),
    );
    if (desktop) {
      return Positioned.fill(
        child: DesktopFieldFrame(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (cards.children.length.clamp(1, 3) * 300).toDouble(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const Divider(height: 28, color: Color(0xff756044)),
                  Flexible(child: scroll),
                  const Divider(height: 24, color: Color(0xff756044)),
                  Text(
                    '${_myGame.loadout.arena.title.toUpperCase()}  /  ${runTime(state.survivalSeconds)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _brass,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB30D0A10),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            children: [
              heading,
              const SizedBox(height: 8),
              Expanded(child: scroll),
              if (canReroll) reroll,
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
      color: desktopInputAvailable ? const Color(0xff292820) : _panel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).height < 460 ? 12 : 16,
          ),
          constraints: BoxConstraints(
            minHeight: desktopInputAvailable ? 220 : 148,
          ),
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
              if (desktopInputAvailable)
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(foregroundColor: _brass),
                  child: const Text(
                    'Choose',
                    style: TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
