import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/training_notice.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/theme/upgrade_glyph.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/widgets/pixel_icon.dart';
import 'package:regun/data/challenges.dart';
import 'package:regun/widgets/control_arranger.dart';
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
import 'package:regun/widgets/controls_editor.dart';
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
    this.resumeSnapshot,
    this.runStore,
  });
  final RunStore? runStore;
  final Loadout loadout;
  final bool showTrainingIntro;
  final Map<String, dynamic>? resumeSnapshot;
  @override
  State<BaseView> createState() => _BaseViewState();
}

class _BaseViewState extends State<BaseView> with WidgetsBindingObserver {
  late final RegunGame _myGame;
  final gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState>();
  bool _editingControls = false;
  bool _arranging = false;
  bool _leaving = false;
  late bool _trainingIntro;
  bool _skippingTraining = false;
  bool _changingWeapon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trainingIntro = widget.loadout.training && widget.showTrainingIntro;
    _myGame = RegunGame(
      context,
      startPaused: _trainingIntro,
      loadout: widget.loadout,
      resumeSnapshot: widget.resumeSnapshot,
      runStore: widget.runStore,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _myGame.leaveRun();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _skipTrainingIntro() async {
    if (_skippingTraining) return;
    setState(() => _skippingTraining = true);
    await _myGame.completeTraining();
    await _myGame.leaveRun();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoadoutView()));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
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
                            _myGame.saveIssue == null
                            ? const SizedBox.shrink()
                            : Positioned(
                                top: 64,
                                left: 24,
                                right: 24,
                                child: IgnorePointer(
                                  child: Text(
                                    _myGame.saveIssue!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _brass,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (!_trainingIntro &&
                          state.gameplayState != GameplayState.gameOver)
                        _hud(state, ref.read(gameNotifierProvider.notifier)),
                      if (state.gameplayState == GameplayState.powerup)
                        _upgradePicker(state),
                      if (!_trainingIntro &&
                          state.gameplayState == GameplayState.paused)
                        _arranging
                            ? ControlArranger(
                                layout: _myGame.controls,
                                available: _myGame.controlCanvasRect,
                                onChanged: (layout) =>
                                    setState(() => _myGame.setControls(layout)),
                                onDone: () =>
                                    setState(() => _arranging = false),
                              )
                            : _editingControls
                            ? _controlEditor()
                            : _pauseMenu(),
                      if (state.gameplayState == GameplayState.gameOver)
                        _results(state),
                      if (_trainingIntro) ...[
                        const ModalBarrier(
                          dismissible: false,
                          color: Color(0xB3100D14),
                        ),
                        SafeArea(
                          minimum: const EdgeInsets.all(16),
                          child: Center(
                            child: TrainingNotice(
                              ready:
                                  state.gameplayState == GameplayState.paused &&
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
              onPressed: _myGame.pauseGame,
              icon: SizedBox(
                width: 22,
                height: 24,
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
                  width: 90,
                  height: 44,
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
            _readout('${state.kills}', 'KILLS'),
            const SizedBox(width: 12),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: _myGame.revision,
          builder: (context, _, child) {
            final bosses = _myGame.bosses
                .where((boss) => boss.isLoaded && !boss.isRemoving)
                .toList();
            if (bosses.isEmpty) return const SizedBox.shrink();
            return IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final boss in bosses)
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: const Color(0xD91D1821),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(boss as BossEncounter).kind.title.toUpperCase()}${(boss as BossEncounter).enraged ? ' / ENRAGED' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: FontFam.pressStart,
                                  fontSize: bosses.length > 1 ? 8 : 10,
                                  color: _paper,
                                ),
                              ),
                              const SizedBox(height: 7),
                              LinearProgressIndicator(
                                value:
                                    (boss as CombatEnemy).combatHealth.fraction,
                                minHeight: 5,
                                color: const Color(0xffC782A3),
                                backgroundColor: const Color(0xff392B3D),
                              ),
                            ],
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
        if (widget.loadout.training &&
            !_myGame.bossRush &&
            _myGame.bosses.isEmpty)
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
            height: 100,
            width: 220,
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
                    ? TickerMode(
                        enabled: state.gameplayState == GameplayState.playing,
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

  Widget _overlay({required Widget child}) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xB30D0A10),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );

  Widget _heading(String text, {String? subtitle}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: FontFam.pressStart,
          fontSize: 22,
          height: 1.5,
          color: _paper,
        ),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
    ],
  );

  Widget _pauseMenu() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heading('TAKE A BREATHER', subtitle: 'The horde can wait.'),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            ClickButton(
              onTap: _myGame.resumeGame,
              text: 'Resume',
              width: 140,
              height: 52,
            ),
            ClickButton(
              onTap: () => setState(() => _editingControls = true),
              text: 'Controls',
              width: 140,
              height: 52,
            ),
            ClickButton(
              onTap: _myGame.restartGame,
              text: 'Restart',
              width: 140,
              height: 52,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_myGame.gameNotifier.canFuse)
          ClickButton(
            text: 'Fuse core',
            width: 150,
            height: 48,
            onTap: _myGame.gameNotifier.openBossCore,
          ),
        ClickButtonM(
          text: 'Settings',
          width: 140,
          height: 48,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SettingsView(onControlsChanged: _myGame.setControls),
            ),
          ),
        ),
        if (widget.loadout.training) ...[
          const SizedBox(height: 24),
          _practiceGroup('WEAPON PRACTICE', [
            for (final weapon in WeaponType.values)
              PixelOption(
                label: weapon.title,
                width: 190,
                selected: weapon == _myGame.loadout.weapon,
                onTap: () async {
                  if (_changingWeapon) return;
                  setState(() => _changingWeapon = true);
                  try {
                    await _myGame.changeTrainingWeapon(weapon);
                  } finally {
                    if (mounted) setState(() => _changingWeapon = false);
                  }
                },
              ),
          ]),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Take damage',
                    style: TextStyle(
                      fontFamily: FontFam.orbitron,
                      color: _paper,
                      fontSize: 14,
                    ),
                  ),
                ),
                PixelOption(
                  label: 'Off',
                  width: 80,
                  selected: !_myGame.trainingDamage,
                  onTap: () => setState(() => _myGame.setTrainingDamage(false)),
                ),
                const SizedBox(width: 8),
                PixelOption(
                  label: 'On',
                  width: 80,
                  selected: _myGame.trainingDamage,
                  onTap: () => setState(() => _myGame.setTrainingDamage(true)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fall. Return to center. Keep your build.',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.loadout.arena == ArenaType.breach) ...[
            _practiceGroup('SUPPLY PRACTICE', [
              ClickButton(
                text: 'Call airdrop',
                height: 48,
                onTap: _myGame.practiceSupplyDrop,
              ),
            ]),
            const SizedBox(height: 24),
          ],
          _practiceGroup('RANDOM BOSS RUSH', [
            ClickButton(
              text: 'Start rush',
              height: 48,
              onTap: _myGame.startBossRush,
            ),
            if (_myGame.bossRush)
              ClickButton(
                text: 'Next round',
                height: 48,
                onTap: _myGame.nextBossRushRound,
              ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Random bosses. Sometimes two.',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 24),
          _practiceGroup('BOSS PRACTICE', [
            for (final kind in BossKind.values)
              ClickButton(
                text: kind.title,
                height: 48,
                onTap: () => _myGame.practiceBoss(kind),
              ),
          ]),
          const SizedBox(height: 24),
          _practiceGroup('FUSION PRACTICE', [
            for (final recipe in fusionRecipes)
              ClickButton(
                text: recipe.title,
                height: 48,
                onTap: () => _myGame.gameNotifier.prepareTrainingFusion(recipe),
              ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Choose the fusion on the next screen.',
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              color: _muted,
            ),
          ),
        ],
        const SizedBox(height: 14),
        ClickButtonM(onTap: _leave, text: 'Menu', width: 140, height: 48),
      ],
    ),
  );

  Widget _practiceGroup(String title, List<Widget> actions) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: FontFam.pressStart,
            fontSize: 10,
            color: Color(0xffE1BA78),
          ),
        ),
        const SizedBox(height: 12),
        MenuCardGrid(minColumnWidth: 160, children: actions),
      ],
    ),
  );

  Widget _controlEditor() => _overlay(
    child: ControlsEditor(
      layout: _myGame.controls,
      onChanged: (layout) => setState(() => _myGame.setControls(layout)),
      onDone: () => setState(() => _editingControls = false),
      onArrange: () => setState(() => _arranging = true),
    ),
  );

  Widget _upgradePicker(GameState state) => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heading(
          state.evolutionChoices.isNotEmpty
              ? 'FUSE'
              : _myGame.gameNotifier.supplyOffer
              ? 'AIRDROP'
              : 'UPGRADE',
          subtitle: state.evolutionChoices.isNotEmpty
              ? null
              : _myGame.gameNotifier.supplyOffer
              ? 'Supply secured'
              : 'Level ${state.currentLevel}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final id in state.evolutionChoices)
              _upgradeCard(
                fusionRecipes.firstWhere((r) => r.id == id).title,
                fusionRecipes.firstWhere((r) => r.id == id).description,
                'FUSION',
                () => _myGame.gameNotifier.fuse(id, offerId: state.offerId),
                glyph: fusionGlyph(id),
              ),
            for (final choice in state.powerUpChoices)
              _upgradeCard(
                choice.title,
                choice.description,
                choice == PowerUp.salvage
                    ? 'RECOVERY'
                    : '${choice.group.name.toUpperCase()} / ${state.rank(choice) + 1} OF ${choice.maxRank}${choice.group == UpgradeGroup.special && state.rank(choice) == 0 && state.ranks.keys.where((p) => p.group == UpgradeGroup.special).length == 5 ? ' / FINAL SLOT' : ''}',
                () => _myGame.gameNotifier.applyPowerUp(
                  choice,
                  offerId: state.offerId,
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
        if (state.evolutionChoices.isEmpty && state.rerolls > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClickButtonM(
              text: 'Reroll (${state.rerolls})',
              width: 170,
              height: 44,
              onTap: () => _myGame.gameNotifier.reroll(offerId: state.offerId),
            ),
          ),
      ],
    ),
  );

  Widget _upgradeCard(
    String title,
    String description,
    String category,
    VoidCallback onTap, {
    VoidCallback? onBan,
    PixelGlyph glyph = PixelGlyph.star,
  }) => SizedBox(
    width: 210,
    child: Material(
      color: _panel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 148),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff75604C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PixelIcon(glyph, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 9,
                        color: _brass,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: FontFam.pressStart,
                  fontSize: 11,
                  height: 1.6,
                  color: _paper,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 12,
                  height: 1.4,
                  color: _muted,
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

  Widget _results(GameState state) => _overlay(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _heading('END OF THE LINE'),
          if (state.causeOfDeath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.causeOfDeath,
                style: const TextStyle(color: _muted),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _readout(runTime(state.survivalSeconds), 'SURVIVED'),
              _readout('${state.kills}', 'KILLS'),
              _readout('${state.bosses}', 'BOSSES'),
              _readout('${state.score}', 'SCORE'),
              _readout('+${_myGame.earnedScrap}', 'SCRAP'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_myGame.assisted ? 'ASSISTED BEST ${_myGame.preferences.profile.assistedBestScore}' : 'BEST ${_myGame.preferences.bestScore}'}  /  LONGEST ${runTime(_myGame.assisted ? _myGame.preferences.profile.assistedBestSeconds : _myGame.preferences.bestSeconds)}',
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 12,
              color: _brass,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final entry in state.ranks.entries)
                  Text(
                    '${entry.key.title} ${entry.value}',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                for (final id in state.evolutions)
                  Text(
                    fusionRecipes.firstWhere((r) => r.id == id).title,
                    style: const TextStyle(fontSize: 11, color: _brass),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _myGame.revision,
            builder: (context, _, child) => _myGame.newUnlocks.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Unlocked: ${_myGame.newUnlocks.map((id) => challenges.firstWhere((c) => c.id == id).reward).join(', ')}',
                      style: const TextStyle(fontSize: 11, color: _brass),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ClickButton(
                onTap: _myGame.restartGame,
                text: 'Restart',
                width: 160,
                height: 54,
              ),
              ClickButtonM(onTap: _leave, text: 'Menu', width: 140, height: 54),
            ],
          ),
        ],
      ),
    ),
  );
}
