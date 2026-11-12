import 'package:regun/desktop/web_landscape_prompt.dart';
import 'package:regun/desktop/desktop_menu_cursor.dart';
import 'package:regun/desktop/desktop_frame_pacer.dart';
import 'package:flutter/gestures.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:regun/desktop/desktop_combat_surface.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/presentation/footstep_cadence.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/components/map/arena_scenery.dart';
import 'package:regun/components/map/map_component.dart';
import 'package:regun/presentation/travel_gait.dart';
import 'package:regun/presentation/online_lodestar.dart';
import 'package:regun/presentation/online_walker.dart';
import 'package:regun/presentation/online_boss_presentation.dart';
import 'package:regun/presentation/boss_portal.dart';
import 'package:regun/presentation/freeze_focus.dart';
import 'package:regun/presentation/guard_feedback.dart';
import 'package:regun/presentation/mechanic_vfx.dart';
import 'package:regun/multiplayer/combat_state.dart'
    show OnlineEntity, OnlineGun;
import 'package:regun/presentation/combat_status_art.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/presentation/support_art.dart';
import 'package:regun/widgets/boss_victory_banner.dart';
import 'package:regun/presentation/mummy_walk.dart';
import 'package:regun/presentation/game_layout.dart';
import 'package:regun/systems/weapon_heading.dart';
import 'package:regun/multiplayer/local_fire_feedback.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/systems/arena_geometry.dart';

import 'dart:async';

import 'package:regun/presentation/grenade_art.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/online_combat_hud.dart';
import 'package:regun/widgets/online_match_menu.dart';
import 'package:regun/widgets/online_objectives.dart';
import 'package:regun/presentation/online_world.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/wall_art.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/online_roster.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/presentation/control_art.dart';
import 'package:regun/theme/pixel_glyph.dart';

/// Deliberately separate from RegunGame: no local director, health, checkpoint,
/// profile rewards or combat may run while the authoritative port is incomplete.
class OnlineArena extends ConsumerStatefulWidget {
  const OnlineArena({super.key, required this.session});
  final OnlineSession session;
  @override
  ConsumerState<OnlineArena> createState() => _OnlineArenaState();
}

class _OnlineArenaState extends ConsumerState<OnlineArena>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  late SoloudPlay audio;
  late final walkers = OnlineWalkers(() {
    if (mounted) setState(() {});
  });
  late final lodestars = OnlineLodestars(() {
    if (mounted) setState(() {});
  });
  final _lodestarCues = <String, int>{};
  final _walkerCues = <String, int>{};
  String? _walkerCueScope;
  final mummyWalks = <String, MummyWalk>{};
  final scorpionGaits = <String, TravelGait>{};
  final weaponHeadings = <String, WeaponHeading>{};
  final restingAim = <String, Offset>{};
  final grenadeAim = GrenadeAim();
  final localFireFeedback = LocalFireFeedback();
  final Map<int, String> pointers = {};
  final Map<String, Offset> origins = {}, knobs = {}, displayed = {};
  final Set<LogicalKeyboardKey> keys = {};
  bool _desktop = desktopInputAvailable;
  bool _viewportBlocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blocked = WebLandscapePrompt.blocksPlay(context);
    if (blocked && !_viewportBlocked) clear();
    _viewportBlocked = blocked;
  }

  final _desktopPacer = DesktopFramePacer();
  bool _controllerActive = false, _controllerArmed = false;
  late final ControllerHandler _controllerHandler = _controller;
  final _desktopKeys = <PhysicalKeyboardKey>{};
  final _controllerHeld = <ControllerAction>{};
  Offset? _mouse, _worldCenter;
  Rect _worldFrame = Rect.zero;
  double _worldScale = 1;
  bool _mouseFire = false, _mouseGrenade = false, _desktopGrenade = false;
  ({Offset direction, double power})? _desktopGrenadeTarget;
  DesktopBindings get _bindings => DesktopBindings.shared;

  void _projection(Rect frame, Offset center, double scale) {
    _worldFrame = frame;
    _worldCenter = center;
    _worldScale = scale;
  }

  void _aimMouse() {
    if (!_desktop || _controllerActive || !session.controlsEnabled) return;
    final point = _mouse, center = _worldCenter;
    if (point == null || center == null || !_worldFrame.contains(point)) {
      if (!_desktopGrenade) _desktopGrenadeTarget = null;
      if (DesktopMenuCursor.combatPointer.value == this) {
        DesktopMenuCursor.combatPointer.value = null;
      }
      return;
    }
    final player =
        displayed[session.identity] ??
        Offset(session.me?.x ?? 0, session.me?.y ?? 0);
    final direction =
        center + (point - _worldFrame.center) / _worldScale - player;
    DesktopMenuCursor.combatPointer.value = this;
    if (direction.distanceSquared > 1e-8) {
      session.aimX = direction.dx / direction.distance;
      session.aimY = direction.dy / direction.distance;
    }
    _desktopGrenadeTarget = (
      direction: Offset(session.aimX, session.aimY),
      power: GrenadeSpec.powerForDistance(direction.distance),
    );
  }

  void _setGrenade(bool held) {
    final released = _desktopGrenade && !held;
    _desktopGrenade = held;
    final target =
        _desktopGrenadeTarget ??
        (direction: Offset(session.aimX, session.aimY), power: 1.0);
    if (held) _desktopGrenadeTarget = target;
    if (released && session.controlsEnabled) {
      session.throwGrenade(aim: target.direction, power: target.power);
    }
  }

  void _mouseKeyboard() {
    if (_controllerActive || !_desktop) {
      clear();
      _controllerActive = false;
      if (!_desktop) setState(() => _desktop = true);
    }
  }

  bool _controller(ControllerFrame? frame) {
    if (!mounted ||
        _viewportBlocked ||
        ModalRoute.of(context)?.isCurrent != true ||
        !session.controlsEnabled) {
      _controllerArmed = false;
      return false;
    }
    if (frame == null) {
      if (_controllerActive) clear();
      _controllerActive = _controllerArmed = false;
      return false;
    }
    final held = {
      for (final action in ControllerAction.values)
        if (frame.button(_bindings.button(action)) >=
            (_controllerHeld.contains(action) ? .4 : .55))
          action,
    };
    Offset stick(int index) {
      final axis = Offset(frame.axis(index), frame.axis(index + 1));
      final length = axis.distance;
      if (length <= _bindings.deadZone) return Offset.zero;
      return axis /
          length *
          ((length - _bindings.deadZone) / (1 - _bindings.deadZone)).clamp(
            0,
            1,
          );
    }

    final move = stick(_bindings.swapSticks ? 2 : 0);
    final aim = stick(_bindings.swapSticks ? 0 : 2);
    final neutral = held.isEmpty && move == Offset.zero && aim == Offset.zero;
    if (!_controllerArmed) {
      _controllerArmed = neutral;
      return _controllerActive;
    }
    if (!_controllerActive) {
      if (neutral) return false;
      clear();
      _controllerActive = _controllerArmed = true;
      if (!_desktop) setState(() => _desktop = true);
    }
    final fresh = held.difference(_controllerHeld);
    _controllerHeld
      ..clear()
      ..addAll(held);
    if (fresh.contains(ControllerAction.pause)) {
      clear();
      setState(() => session.menuOpen = true);
      return true;
    }
    session.moveX = move.dx;
    session.moveY = move.dy;
    if (aim != Offset.zero) {
      session.aimX = aim.dx / aim.distance;
      session.aimY = aim.dy / aim.distance;
    }
    if (fresh.contains(ControllerAction.dash)) session.dash();
    if (fresh.contains(ControllerAction.reload)) session.reload();
    session.firing =
        session.match != null && held.contains(ControllerAction.fire);
    final grenadeHeld = held.contains(ControllerAction.grenade);
    if (aim != Offset.zero && (grenadeHeld || _desktopGrenade)) {
      _desktopGrenadeTarget = (
        direction: aim / aim.distance,
        power: GrenadeSpec.powerForDeflection(aim.distance),
      );
    }
    _setGrenade(grenadeHeld);
    if (!grenadeHeld) _desktopGrenadeTarget = null;
    return true;
  }

  KeyEventResult _desktopKey(KeyEvent event) {
    final key = event.physicalKey;
    if (!session.controlsEnabled ||
        !DesktopAction.values.any(
          (action) => _bindings.matchesKey(action, key),
        )) {
      return KeyEventResult.ignored;
    }
    _mouseKeyboard();
    if (event is KeyDownEvent) _desktopKeys.add(key);
    if (event is KeyUpEvent) _desktopKeys.remove(key);
    int held(DesktopAction action) =>
        _bindings.held(action, _desktopKeys) ? 1 : 0;
    var move = Offset(
      (held(DesktopAction.right) - held(DesktopAction.left)).toDouble(),
      (held(DesktopAction.down) - held(DesktopAction.up)).toDouble(),
    );
    if (move.distanceSquared > 1) move /= move.distance;
    session.moveX = move.dx;
    session.moveY = move.dy;
    if (event is KeyDownEvent) {
      if (_bindings.matchesKey(DesktopAction.dash, key)) session.dash();
      if (_bindings.matchesKey(DesktopAction.reload, key)) session.reload();
    }
    session.firing =
        session.match != null && (_mouseFire || held(DesktopAction.fire) > 0);
    _setGrenade(_mouseGrenade || held(DesktopAction.grenade) > 0);
    return KeyEventResult.handled;
  }

  bool artReady = false;
  MapComponent? districtMap;
  late final OnlineArtLeases leases = OnlineArtLeases(
    () => mounted ? setState(() {}) : null,
  );
  bool _controlled = false;
  String? _generation;
  final Map<String, int> _shots = {},
      _reloads = {},
      _damage = {},
      _reloadPhase = {};
  final Map<String, double> shotTimes = {}, hurtTimes = {};
  final Set<String> _warmed = {};
  final Map<String, bool> _wasReloading = {}, _wasDashing = {};
  final Map<String, double> _damageTotals = {};
  double lostHp = 0, damageAt = -10;
  final _footsteps = FootstepCadence();
  Offset? _lastFootstepPosition;
  bool _localWasDashing = false;
  final Map<String, String> _worldCues = {};
  String? _music;
  int? _offerCue;
  String? _confirmationCue;
  final bossPresentation = OnlineBossPresentation();
  void _sceneCues() {
    final scope = '${session.room?.id}:${session.match?.data['matchId']}';
    if (_walkerCueScope != scope) {
      _walkerCues.clear();
      _lodestarCues.clear();
      _walkerCueScope = scope;
    }
    final liveScorpions = <String>{};
    for (final entity in session.scene.where(
      (e) =>
          e.kind == 'enemy' &&
          e.data['kind'] == 'scorpion' &&
          e.number('health') > 0,
    )) {
      liveScorpions.add(entity.key);
      scorpionGaits
          .putIfAbsent(
            entity.key,
            () => TravelGait(phase: TravelGait.phaseFor(entity.key)),
          )
          .sample(Offset(entity.x, entity.y), entity.number('age'));
    }
    scorpionGaits.removeWhere((key, _) => !liveScorpions.contains(key));
    final liveMummies = <String>{};
    for (final entity in session.scene.where(
      (e) =>
          e.kind == 'enemy' &&
          e.data['kind'] == 'mummy' &&
          e.number('health') > 0,
    )) {
      liveMummies.add(entity.key);
      mummyWalks
          .putIfAbsent(entity.key, MummyWalk.new)
          .followSnapshot(
            Offset(entity.x, entity.y),
            age: entity.number('age'),
            walking: entity.number('phase') == 0,
            facingX: entity.data['mummyFacingX'] is num
                ? entity.number('mummyFacingX')
                : null,
          );
    }
    mummyWalks.removeWhere((key, _) => !liveMummies.contains(key));
    final audio = ref.read(soloudPlayProvider);
    if (_warmed.add('supply')) unawaited(audio.warmSupply());
    for (final e in session.scene.where(
      (e) => e.kind == 'enemy' && e.data['boss'] == true,
    )) {
      final kind = BossKind.values.byName(e.data['kind'] as String);
      if (_warmed.add('boss_${kind.name}')) {
        unawaited(
          (kind == BossKind.walker || kind == BossKind.lodestar)
              ? audio.warmWalker()
              : audio.warmBoss(kind),
        );
      }
      if (kind == BossKind.lodestar && e.data['lodestar'] is Map) {
        final state = e.data['lodestar'] as Map;
        final serial = (state['cueSerial'] as num?)?.toInt() ?? 0;
        final previous = _lodestarCues[e.key];
        _lodestarCues[e.key] = serial;
        if (previous != null &&
            serial > previous &&
            session.connected &&
            !session.suspended) {
          final sound = state['cue'];
          if (sound is String && sound.isNotEmpty) audio.play(sound);
        }
      }
      if (kind == BossKind.walker && e.data['walker'] is Map) {
        final state = e.data['walker'] as Map;
        final serial = (state['signalSerial'] as num?)?.toInt() ?? 0;
        final previous = _walkerCues[e.key];
        _walkerCues[e.key] = serial;
        if (previous != null && session.connected && !session.suspended) {
          for (final raw in state['signals'] as List? ?? []) {
            if ((raw['serial'] as num) <= previous) continue;
            final sound = switch (raw['event']) {
              'rotary' => 'sentry_fire.wav',
              'cannon' => 'shot_revolver_0.wav',
              'rocket' => 'walker_rocket_launch.wav',
              'blast' => 'blast.wav',
              'land' => 'supply_land.wav',
              'spool' => 'reload_carbine_1.wav',
              'charge' => 'supply_incoming.wav',
              'fatal' => 'supply_break.wav',
              _ => null,
            };
            if (sound != null) audio.play(sound);
          }
        }
      }
    }
    if (!session.connected) return;
    final boss = session.scene.any(
      (e) =>
          e.kind == 'enemy' && e.data['boss'] == true && e.number('health') > 0,
    );
    final theme = boss
        ? 'boss'
        : session.room?.mapId == 'foundry' ||
              session.room?.mapId.startsWith('ironworks') == true
        ? 'foundry'
        : 'breach';
    if (_music != theme) {
      _music = theme;
      unawaited(audio.playMusic(theme));
    }
    final offer = session.gun?.offerId;
    if (offer != _offerCue) {
      if (_offerCue != null && session.gun!.offers.isNotEmpty) {
        unawaited(
          audio.play(
            session.gun!.progress['source'] == 'fusion'
                ? 'fusion.wav'
                : 'level.wav',
          ),
        );
      }
      _offerCue = offer;
    }
    for (final entity in session.scene) {
      final d = entity.data;
      final cue = entity.kind == 'supply'
          ? '${d['phase']}:${(entity.number('capture') / 1).floor()}'
          : entity.kind == 'support'
          ? '${d['phase']}:${(d['shotsFired'] != null ? entity.number('shotsFired') : -entity.number('ammo')).toInt()}:${entity.number('reload') > 0}'
          : entity.kind == 'enemy'
          ? '${d['bossPhase'] ?? d['phase']}:${d['attackName']}:${entity.number('health') <= 0}'
          : '';
      final old = _worldCues[entity.key];
      final listener = session.me;
      if (old == null &&
          entity.kind == 'effect' &&
          (d['material'] == 'explosion' || d['material'] == 'upgradePulse') &&
          entity.number('age') < .15 &&
          listener != null &&
          Offset(entity.x - listener.x, entity.y - listener.y).distance < 900) {
        unawaited(
          audio.play(
            d['material'] == 'upgradePulse' ? 'upgrade_pulse.wav' : 'blast.wav',
          ),
        );
      }
      _worldCues[entity.key] = cue;
      final me = session.me;
      if (old == null ||
          old == cue ||
          me == null ||
          Offset(entity.x - me.x, entity.y - me.y).distance > 900) {
        continue;
      }
      if (entity.kind == 'support') {
        final previous = old.split(':'), phase = d['phase'];
        final aura = (d['id'] as String? ?? '').startsWith('support:aura:');
        if (previous.first != phase) {
          final sound = switch (phase) {
            'warning' => 'sentry_incoming.wav',
            'deploying' => 'supply_land.wav',
            'breaking' => 'supply_break.wav',
            'active' when aura => 'aura_start.wav',
            'fading' => 'aura_end.wav',
            _ => null,
          };
          if (sound != null) unawaited(audio.play(sound));
        }
        if (!aura && phase == 'active' && previous.length >= 3) {
          if ((d['shotsFired'] != null
                  ? entity.number('shotsFired')
                  : -entity.number('ammo')) >
              (int.tryParse(previous[1]) ?? 0)) {
            unawaited(
              audio.play(
                (d['id'] as String).endsWith('burstRifle')
                    ? 'sentry_burst.wav'
                    : 'sentry_fire.wav',
              ),
            );
          }
        }
      } else if (entity.kind == 'supply') {
        if (d['phase'] == 'active') {
          unawaited(audio.play('supply_land.wav'));
        } else if (d['phase'] == 'opened') {
          unawaited(audio.play('supply_claim.wav'));
        } else if (d['phase'] == 'breaking') {
          unawaited(audio.play('supply_break.wav'));
        } else if (d['phase'] == 'warning') {
          unawaited(audio.play('supply_incoming.wav'));
        }
        if (entity.number('capture') > 0 && d['phase'] == 'active') {
          unawaited(
            audio.play(
              'supply_charge_${entity.number('capture').floor().clamp(0, 7)}.wav',
            ),
          );
        }
      } else if (entity.kind == 'enemy') {
        final kind = BossKind.values
            .where((b) => b.name == d['kind'])
            .firstOrNull;
        if (kind?.expansion == true) {
          if (d['bossPhase'] == 'warning') {
            unawaited(audio.play('boss_${kind!.name}_warn.wav'));
          } else if (d['bossPhase'] == 'active') {
            unawaited(audio.play('boss_${kind!.name}_hit.wav'));
          } else if (d['interrupted'] == true) {
            unawaited(audio.play('boss_${kind!.name}_break.wav'));
          }
        } else if (d['kind'] == 'runner' &&
            d['phase'] == 1 &&
            !old.startsWith('1:')) {
          final offset = Offset(entity.x - me.x, entity.y - me.y);
          unawaited(
            audio.playEnemyMovement('enemy_skitter_warn.wav', offset, 850),
          );
        } else if (d['kind'] == 'ranged' &&
            d['phase'] == 0 &&
            old.startsWith('1:')) {
          unawaited(audio.play('enemy3projectile.wav'));
        }
      }
    }
    _worldCues.removeWhere((key, _) => !session.scene.any((e) => e.key == key));
  }

  final upgradeArt = UpgradeArtLease();
  final statusArt = CombatStatusArt();
  final guardFeedback = <String, GuardFeedback>{};
  final mechanicFeedback = <String, MechanicFeedback>{};
  double seconds = 0;
  Duration last = Duration.zero;
  OnlineSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    if (desktopInputAvailable) {
      DesktopController.handlers.add(_controllerHandler);
    }
    audio = ref.read(soloudPlayProvider);
    MapComponent.loadMap().then((map) {
      if (mounted) setState(() => districtMap = map);
    });
    Future.wait([
      for (final c in CharacterType.values.where((c) => c.availableOnline))
        RegunArt.shared.acquireSurvivor(c.name),
    ]).then((_) {
      if (mounted) {
        setState(() => artReady = true);
      } else {
        for (final c in CharacterType.values.where((c) => c.availableOnline)) {
          RegunArt.shared.releaseSurvivor(c.name);
        }
      }
    });
    ticker = createTicker((elapsed) {
      final elapsedSeconds = (elapsed - last).inMicroseconds / 1000000;
      last = elapsed;
      final paced = desktopInputAvailable
          ? _desktopPacer.advance(elapsedSeconds, _bindings.frameCeiling)
          : elapsedSeconds;
      if (paced == null) return;
      final dt = paced.clamp(0.0, .1);
      session.predictionReducedMotion = LocalPreferences.shared.reducedMotion;
      bossPresentation.sync(
        '${session.room?.id}:${session.match?.data['matchId']}',
        session.connected && !session.suspended ? session.match : null,
        session.scene,
        dt,
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
      if (session.match?.phase != 'confirmation' &&
          session.match?.phase != 'boss_reveal') {
        seconds += dt * (session.match?.phase == 'choice' ? .1 : 1);
      }
      if (OnlineSession.upgradeConfirmationsEnabled &&
          session.match?.phase == 'choice') {
        upgradeArt.prewarm(session.fighters.values.expand((g) => g.offers));
      }
      if (OnlineSession.upgradeConfirmationsEnabled &&
          session.match?.phase == 'confirmation') {
        upgradeArt.prewarm(
          session.upgradeReceipts.active.values.map((r) => r.family),
        );
      }
      if (_controlled && !session.controlsEnabled) clear();
      _controlled = session.controlsEnabled;
      _aimMouse();
      if (session.match?.phase == 'active') {
        session.upgradeReceipts.advanceActive(dt);
      }
      if (session.scene.any(
        (e) =>
            e.kind == 'enemy' && e.number('burn') > 0 && e.number('health') > 0,
      )) {
        statusArt.prewarmFire();
      }
      final generation =
          '${session.room?.id}:${session.match?.data['matchId']}'.hashCode;
      if (!session.connected || session.suspended) {
        mechanicFeedback.clear();
        guardFeedback.clear();
      }
      for (final entry
          in session.connected && !session.suspended
              ? session.fighters.entries
              : const <MapEntry<String, OnlineGun>>[]) {
        final p = entry.value.progress;
        (guardFeedback[entry.key] ??= GuardFeedback()).sync(
          generation,
          (p['guardAbsorptions'] as num?)?.toInt() ?? 0,
          (p['guardRecharges'] as num?)?.toInt() ?? 0,
          session.match?.phase == 'active' ? dt : 0,
        );
        final feedback = mechanicFeedback[entry.key] ??= MechanicFeedback();
        feedback.sync(
          generation,
          (p['recoveredHealth'] as num?)?.toInt() ?? 0,
          session.match?.phase == 'active' ? dt : 0,
        );
        feedback.onlineShots(
          entry.value.shots,
          acceptedPerks: (entry.value.data['shotPerks'] as num?)?.toInt(),
        );
      }
      _combatCues();
      if (session.controlsEnabled || session.match?.phase == 'active') {
        for (final m in session.members) {
          final key = m.identity.toHexString, gun = session.fighters[key];
          if (gun == null || gun.health <= 0) continue;
          final mine = key == session.identity;
          final direct = mine ? session.firing : gun.aiming;
          final aim = mine
              ? Offset(session.aimX, session.aimY)
              : Offset(m.aimX, m.aimY);
          final movement = mine
              ? Offset(session.moveX, session.moveY)
              : Offset(m.moveX, m.moveY);
          final tracker = weaponHeadings.putIfAbsent(key, WeaponHeading.new);
          final heading = tracker.advance(
            restingAim[key] ?? aim,
            movement,
            direct ? aim : Offset.zero,
            dt,
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
          restingAim[key] = heading;
          if (mine && !direct && tracker.idle > .65) {
            session.aimX = heading.dx;
            session.aimY = heading.dy;
          }
        }
      }
      lodestars.sync(
        session.scene,
        scope: '${session.room?.id}:${session.match?.data['matchId']}',
      );
      walkers.sync(
        session.scene,
        dt,
        scope: '${session.room?.id}:${session.match?.data['matchId']}',
        active:
            session.connected &&
            !session.suspended &&
            session.match?.phase == 'active',
      );
      _sceneCues();
      if (artReady) leases.update(session.scene);
      for (final member in session.members) {
        final id = member.identity.toHexString;
        if (id == session.identity &&
            session.predictionAvailable &&
            session.controlsEnabled &&
            session.predictedPosition != null) {
          displayed[id] = session.predictedPosition!;
          continue;
        }
        displayed[id] = id == session.identity
            ? Offset(member.x, member.y)
            : session.remotePosition(
                member,
                reducedMotion: LocalPreferences.shared.reducedMotion,
              );
      }
      _localMovementAudio();
      weaponHeadings.removeWhere(
        (key, _) => !session.members.any((m) => m.identity.toHexString == key),
      );
      restingAim.removeWhere(
        (key, _) => !session.members.any((m) => m.identity.toHexString == key),
      );
      displayed.removeWhere(
        (id, _) => !session.members.any((m) => m.identity.toHexString == id),
      );
      if (mounted) setState(() {});
    })..start();
  }

  void _localMovementAudio() {
    final at = displayed[session.identity];
    final member = session.me;
    final fighter = session.fighters[session.identity];
    if (at == null ||
        member == null ||
        !session.controlsEnabled ||
        fighter == null ||
        fighter.health <= 0) {
      _lastFootstepPosition = null;
      _localWasDashing = false;
      _footsteps.reset();
      return;
    }
    final previous = _lastFootstepPosition;
    _lastFootstepPosition = at;
    final dashing = session.predictionAvailable
        ? (session.movementPrediction.body?.dashRemaining ??
                  member.dashRemaining) >
              0
        : member.dashRemaining > 0;
    final landed = _localWasDashing && !dashing;
    _localWasDashing = dashing;
    if (dashing || landed) {
      _footsteps.reset();
      if (landed) unawaited(audio.playMovement('dash_land.wav'));
      return;
    }
    final distance = previous == null ? 0.0 : (at - previous).distance;
    final moving = session.moveX != 0 || session.moveY != 0;
    final variant = _footsteps.advance(moving && distance < 75 ? distance : 0);
    if (variant == null) return;
    final arena =
        ArenaType.values
            .where((a) => a.name == session.room?.mapId)
            .firstOrNull ??
        ArenaType.breach;
    final surface =
        districtMap?.footstepSurface(
          arena,
          at + const Offset(0, 30),
          legacy: false,
        ) ??
        'stone';
    unawaited(audio.playMovement('step_${surface}_$variant.wav'));
  }

  void _combatCues() {
    final accepted = session.upgradeReceipts.active[session.identity];
    if (accepted != null) {
      final key = '${accepted.generation}:${accepted.actor}:${accepted.serial}';
      if (_confirmationCue != key) {
        _confirmationCue = key;
        unawaited(audio.play('reload_carbine_1.wav'));
        if (LocalPreferences.shared.haptics) HapticFeedback.selectionClick();
      }
    }
    final connection =
        '${session.me?.generation}:${session.room?.id}:${session.connected}';
    if (connection != _generation) {
      grenadeAim.cancel();
      _generation = connection;
      restingAim.clear();
      weaponHeadings.clear();
      _worldCues.clear();
      _lastFootstepPosition = null;
      _localWasDashing = false;
      _footsteps.reset();
      mummyWalks.clear();
      scorpionGaits.clear();
      _offerCue = null;
      _shots.clear();
      _reloads.clear();
      _damage.clear();
      _damageTotals.clear();
      _reloadPhase.clear();
      _wasReloading.clear();
      _wasDashing.clear();
      localFireFeedback.reset();
      shotTimes.clear();
      hurtTimes.clear();
    }
    for (final entry in session.fighters.entries) {
      final key = entry.key, gun = entry.value;
      final weapon = WeaponType.values.firstWhere((w) => w.name == gun.weapon);
      final audio = ref.read(soloudPlayProvider);
      if (_warmed.add(gun.weapon)) unawaited(audio.warmCombat(weapon));
      final previous = _shots[key];
      _shots[key] = gun.shots;
      final member = session.members
          .where((m) => m.identity.toHexString == key)
          .firstOrNull;
      final audible =
          member != null &&
          session.me != null &&
          math.sqrt(
                math.pow(member.x - session.me!.x, 2) +
                    math.pow(member.y - session.me!.y, 2),
              ) <
              850;
      final dashing = (member?.dashRemaining ?? 0) > 0;
      final wasDashing = _wasDashing[key];
      _wasDashing[key] = dashing;
      if (dashing && wasDashing == false && audible) {
        unawaited(audio.play('dash_burst.wav'));
      }
      final predictedCue =
          key == session.identity && session.projectilePredictionAvailable
          ? session.projectilePresentation.takeCue()
          : false;
      final shotCue = key == session.identity
          ? session.projectilePredictionAvailable
                ? predictedCue ||
                      (previous != null &&
                          gun.shots > previous &&
                          !session.projectilePresentation.wasPredicted(gun))
                : localFireFeedback.update(
                    now: seconds,
                    held: session.firing,
                    enabled: session.controlsEnabled,
                    shots: gun.shots,
                    ammo: gun.ammo,
                    reloading: gun.reloading,
                    cooldown: gun.cooldown,
                  )
          : previous != null && gun.shots > previous;
      if (shotCue) {
        shotTimes[key] = seconds;
        if (audible) {
          unawaited(audio.play('shot_${gun.weapon}_${gun.shots % 3}.wav'));
        }
      }
      final total = _damageTotals[key];
      _damageTotals[key] = gun.damageTotal;
      final damage = _damage[key];
      _damage[key] = gun.damageSerial;
      if (damage != null && gun.damageSerial > damage) {
        hurtTimes[key] = seconds;
        if (key == session.identity) {
          lostHp = total == null ? gun.lastDamage : gun.damageTotal - total;
          damageAt = seconds;
          if (LocalPreferences.shared.haptics) {
            unawaited(HapticFeedback.lightImpact());
          }
          unawaited(
            audio.play(gun.health <= 0 ? 'gameov.wav' : 'hurt_player.wav'),
          );
        }
      }
      final wasReloading = _wasReloading[key] ?? false;
      _wasReloading[key] = gun.reloading;
      if (audible &&
          wasReloading &&
          !gun.reloading &&
          gun.weapon == 'shotgun' &&
          gun.ammo == gun.capacity &&
          gun.data['reloadTactical'] != true) {
        unawaited(audio.play('reload_shotgun_pump.wav'));
      }
      final reload = _reloads[key];
      _reloads[key] = gun.reloadSerial;
      final elapsed = gun.reloadDuration - gun.reloadRemaining;
      final burstTactical =
          gun.weapon != 'shotgun' && gun.data['reloadTactical'] == true;
      final phase = burstTactical
          ? (elapsed >= gun.reloadDuration * .82 ? 1 : 0)
          : gun.weapon == 'shotgun'
          ? (elapsed / (.6 * (gun.data['reloadTactical'] == true ? .7 : 1)))
                .floor()
          : elapsed >= gun.reloadDuration * .82
          ? 2
          : elapsed >= gun.reloadDuration * .42
          ? 1
          : 0;
      final previousPhase = _reloadPhase[key];
      _reloadPhase[key] = phase;
      if (audible && gun.reloading && reload != null) {
        if (gun.reloadSerial > reload) {
          unawaited(
            audio.play(
              gun.weapon == 'shotgun'
                  ? 'reload_shotgun_shell.wav'
                  : 'reload_${gun.weapon}_0.wav',
            ),
          );
        } else if (previousPhase != null &&
            phase > previousPhase &&
            !(gun.weapon != 'shotgun' &&
                gun.data['reloadTactical'] == true &&
                phase == 2) &&
            (gun.weapon != 'shotgun' || phase < gun.capacity - gun.ammo)) {
          unawaited(
            audio.play(
              gun.weapon == 'shotgun'
                  ? 'reload_shotgun_shell.wav'
                  : 'reload_${gun.weapon}_$phase.wav',
            ),
          );
        }
      }
    }
  }

  void clear() {
    if (DesktopMenuCursor.combatPointer.value == this) {
      DesktopMenuCursor.combatPointer.value = null;
    }
    _desktopKeys.clear();
    _controllerHeld.clear();
    _controllerArmed = false;
    _mouse = null;
    _mouseFire = _mouseGrenade = _desktopGrenade = false;
    _desktopGrenadeTarget = null;
    grenadeAim.cancel();
    pointers.clear();
    origins.clear();
    knobs.clear();
    keys.clear();
    session.neutral();
  }

  @override
  void dispose() {
    DesktopController.handlers.remove(_controllerHandler);
    upgradeArt.clear();
    statusArt.clear();
    if (artReady) {
      for (final c in CharacterType.values.where((c) => c.availableOnline)) {
        RegunArt.shared.releaseSurvivor(c.name);
      }
    }
    ticker.dispose();
    leases.dispose();
    walkers.dispose();
    lodestars.dispose();
    clear();
    unawaited(audio.playMusic('menu'));
    super.dispose();
  }

  void keyboard() {
    session.moveX =
        (keys.contains(LogicalKeyboardKey.keyD) ||
                keys.contains(LogicalKeyboardKey.arrowRight)
            ? 1
            : 0) -
        (keys.contains(LogicalKeyboardKey.keyA) ||
                    keys.contains(LogicalKeyboardKey.arrowLeft)
                ? 1
                : 0)
            .toDouble();
    session.moveY =
        (keys.contains(LogicalKeyboardKey.keyS) ||
                keys.contains(LogicalKeyboardKey.arrowDown)
            ? 1
            : 0) -
        (keys.contains(LogicalKeyboardKey.keyW) ||
                    keys.contains(LogicalKeyboardKey.arrowUp)
                ? 1
                : 0)
            .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final arena = CustomPaint(
      painter: _ArenaPainter(
        session: session,
        bossPresentation: bossPresentation,
        positions: displayed,
        seconds: seconds,
        artReady: artReady,
        districtMap: districtMap,
        shotTimes: shotTimes,
        hurtTimes: hurtTimes,
        grenadeAim: grenadeAim,
        desktopGrenadeTarget:
            _desktopGrenade &&
                session.grenadeAimingAvailable &&
                (session.gun?.grenadeCharges ?? 0) > 0
            ? _desktopGrenadeTarget
            : null,
        touchInsets: MediaQuery.paddingOf(context),
        restingAim: restingAim,
        mummyWalks: mummyWalks,
        scorpionGaits: scorpionGaits,
        walkers: walkers,
        lodestars: lodestars,
        guardFeedback: guardFeedback,
        mechanicFeedback: mechanicFeedback,
        desktop: _desktop,
        onProjection: _desktop ? _projection : null,
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xff161B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_desktop) IgnorePointer(child: arena),
          _safeAreaOverlay(arena),
        ],
      ),
    );
  }

  Widget _safeAreaOverlay(Widget arena) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final controls = LocalPreferences.shared.controls;
          final geometry = controls.geometry(size);
          final centers = {'move': geometry.movement, 'aim': geometry.aim};
          final stickSize = controls.displaySize(size),
              buttonSize = controls.displayButtonSize(size);
          final radius = stickSize / 2;
          void update(PointerEvent event) {
            final id = pointers[event.pointer];
            if (id == null ||
                id == 'dash' ||
                id == 'reload' ||
                id == 'grenade') {
              return;
            }
            var raw = (event.localPosition - origins[id]!) / (radius * 58 / 90);
            if (raw.distance > 1) raw /= raw.distance;
            var delta = raw.distance < controls.deadZone
                ? Offset.zero
                : raw * controls.sensitivity;
            if (delta.distance > 1) delta /= delta.distance;
            knobs[id] = raw;
            if (id == 'move') {
              session.moveX = delta.dx;
              session.moveY = delta.dy;
            } else if (delta != Offset.zero) {
              session.firing = session.match != null;
              session.aimX = delta.dx / delta.distance;
              session.aimY = delta.dy / delta.distance;
            } else {
              session.firing = false;
            }
          }

          void release(PointerEvent event) {
            final id = pointers.remove(event.pointer);
            if (id == 'move') {
              session.moveX = 0;
              session.moveY = 0;
            }
            if (id == 'aim') session.firing = false;
            if (id != null) {
              knobs.remove(id);
              origins.remove(id);
            }
          }

          return Focus(
            autofocus: true,
            onFocusChange: (focused) {
              if (!focused) clear();
            },
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                clear();
                setState(() => session.menuOpen = !session.menuOpen);
                return KeyEventResult.handled;
              }
              if (desktopInputAvailable) return _desktopKey(event);
              if (session.menuOpen) return KeyEventResult.handled;
              if (event is KeyDownEvent) {
                keys.add(event.logicalKey);
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  session.dash();
                }
              } else if (event is KeyUpEvent) {
                keys.remove(event.logicalKey);
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.keyR) {
                session.reload();
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.keyG) {
                session.throwGrenade();
              }
              if (event.logicalKey == LogicalKeyboardKey.keyF) {
                session.firing = event is! KeyUpEvent;
              }
              keyboard();
              return KeyEventResult.handled;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    onHover: !desktopInputAvailable
                        ? null
                        : (event) {
                            if (_controllerActive && event.delta.distance < 2) {
                              return;
                            }
                            _mouseKeyboard();
                            _mouse = event.localPosition;
                            _aimMouse();
                          },
                    onExit: !desktopInputAvailable
                        ? null
                        : (_) {
                            if (!_controllerActive && _desktop) clear();
                          },
                    cursor:
                        _desktop &&
                            !_controllerActive &&
                            session.controlsEnabled &&
                            _worldFrame.contains(_mouse ?? const Offset(-1, -1))
                        ? SystemMouseCursors.none
                        : MouseCursor.defer,
                    child: Listener(
                      onPointerDown: (event) {
                        if (!session.controlsEnabled) return;
                        if (desktopInputAvailable &&
                            event.kind == PointerDeviceKind.mouse) {
                          _mouseKeyboard();
                          if (!_worldFrame.contains(event.localPosition)) {
                            return;
                          }
                          _mouse = event.localPosition;
                          _aimMouse();
                          _mouseFire = event.buttons & _bindings.mouseFire != 0;
                          _mouseGrenade =
                              event.buttons & _bindings.mouseGrenade != 0;
                          session.firing = session.match != null && _mouseFire;
                          _setGrenade(
                            _mouseGrenade ||
                                _bindings.held(
                                  DesktopAction.grenade,
                                  _desktopKeys,
                                ),
                          );
                          return;
                        }
                        if (_desktop && event.kind == PointerDeviceKind.touch) {
                          clear();
                          _controllerActive = false;
                          setState(() => _desktop = false);
                        }
                        final p = event.localPosition;
                        if ((p - geometry.dash).distance < buttonSize / 2) {
                          pointers[event.pointer] = 'dash';
                          session.dash();
                          return;
                        }
                        if (session.match != null &&
                            (p - geometry.reload).distance < buttonSize / 2) {
                          pointers[event.pointer] = 'reload';
                          session.reload();
                          return;
                        }
                        if (session.match != null &&
                            (p - geometry.grenade).distance < buttonSize / 2) {
                          pointers[event.pointer] = 'grenade';
                          return;
                        }
                        for (final id in ['move', 'aim']) {
                          if (pointers.containsValue(id)) continue;
                          final matchesSide =
                              (p.dx < size.width / 2) ==
                              (centers[id]!.dx < size.width / 2);
                          if ((p - centers[id]!).distance <= radius ||
                              (controls.floating &&
                                  matchesSide &&
                                  p.dy > size.height * .35)) {
                            pointers[event.pointer] = id;
                            origins[id] = controls.floating ? p : centers[id]!;
                            update(event);
                            break;
                          }
                        }
                      },
                      onPointerMove: (event) {
                        if (_desktop && event.kind == PointerDeviceKind.mouse) {
                          _mouse = event.localPosition;
                          _aimMouse();
                        } else {
                          update(event);
                        }
                      },
                      onPointerUp: (event) {
                        if (_desktop && event.kind == PointerDeviceKind.mouse) {
                          _mouse = event.localPosition;
                          _aimMouse();
                          _mouseFire = _mouseGrenade = false;
                          session.firing =
                              session.match != null &&
                              _desktopKeys.contains(
                                _bindings.key(DesktopAction.fire),
                              );
                          if (!_worldFrame.contains(event.localPosition)) {
                            _desktopGrenade = false;
                            _desktopGrenadeTarget = null;
                          } else {
                            _setGrenade(
                              _bindings.held(
                                DesktopAction.grenade,
                                _desktopKeys,
                              ),
                            );
                          }
                        } else {
                          release(event);
                        }
                      },
                      onPointerCancel: (event) {
                        if (_desktop && event.kind == PointerDeviceKind.mouse) {
                          clear();
                        } else {
                          release(event);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: _desktop ? arena : const SizedBox.expand(),
                    ),
                  ),
                ),
                if (_desktop &&
                    !_controllerActive &&
                    session.controlsEnabled &&
                    _mouse != null &&
                    _worldFrame.contains(_mouse!))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: DesktopCrosshair(
                          _mouse!,
                          _bindings.crosshairScale,
                          _bindings.highContrast,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 144,
                  top: 8,
                  child: OnlineRoster(session: session),
                ),
                Positioned(
                  right: 12,
                  top: 8,
                  child: SizedBox(
                    width: 116,
                    child: ClickButton(
                      text: 'Menu',
                      height: 44,
                      fontSize: 11,
                      onTap: session.connected && !session.busy
                          ? () {
                              clear();
                              setState(() => session.menuOpen = true);
                            }
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top:
                      14 +
                      ((session.members.length / 3).ceil() *
                          32 *
                          MediaQuery.textScalerOf(context).scale(12) /
                          12),
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Text(
                      !session.compatible
                          ? session.error
                          : session.connected
                          ? session.match == null
                                ? 'MOVEMENT TEST | No combat | WASD / sticks | Space / Dash'
                                : '${session.room?.mode == 'versus' ? 'Round ${session.match!.round} | ${session.match!.wins[0]} - ${session.match!.wins[1]} | ${session.match!.overtime ? 'OVERTIME ${(105 - session.match!.seconds).ceil()}' : '${(90 - session.match!.seconds).ceil()}s'}' : 'Co-op'} | Aim to fire | R reload'
                          : '${session.status} | Movement paused',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        color: Color(0xffE5DDD1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (!_desktop)
                  for (final id in ['move', 'aim'])
                    Positioned(
                      left: (origins[id] ?? centers[id]!).dx - radius,
                      top: (origins[id] ?? centers[id]!).dy - radius,
                      child: IgnorePointer(
                        child: SizedBox(
                          width: radius * 2,
                          height: radius * 2,
                          child: CustomPaint(
                            painter: OnlineStickSkin(
                              delta: knobs[id] ?? Offset.zero,
                              opacity: controls.opacity,
                            ),
                          ),
                        ),
                      ),
                    ),
                if (!_desktop)
                  Positioned(
                    left: geometry.dash.dx - buttonSize / 2,
                    top: geometry.dash.dy - buttonSize / 2,
                    child: Semantics(
                      label: 'Dash',
                      button: true,
                      enabled: session.controlsEnabled,
                      onTap: session.controlsEnabled ? session.dash : null,
                      child: IgnorePointer(
                        child: SizedBox.square(
                          dimension: buttonSize,
                          child: CustomPaint(
                            painter: OnlineActionSkin(
                              glyph: PixelGlyph.dash,
                              label: 'DASH',
                              opacity: controls.opacity,
                              active:
                                  session.predictedDashRemaining > 0 ||
                                  pointers.containsValue('dash'),
                              capacity:
                                  session
                                      .movementPrediction
                                      .body
                                      ?.dashCapacity ??
                                  1,
                              charges:
                                  session
                                      .movementPrediction
                                      .body
                                      ?.dashCharges ??
                                  1,
                              chargeProgress:
                                  1 -
                                  (session
                                              .movementPrediction
                                              .body
                                              ?.rechargeRemaining ??
                                          0) /
                                      session.predictedDashDuration,
                              cooldown:
                                  session.predictedDashCooldown /
                                  session.predictedDashDuration,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final victory
                    in session.scene
                        .where(
                          (e) =>
                              e.kind == 'effect' &&
                              (e.data['material'] as String? ?? '').startsWith(
                                'bossVictory:',
                              ),
                        )
                        .take(1))
                  Positioned(
                    top: 58,
                    left: 24,
                    right: 24,
                    child: BossVictoryBanner(
                      verb:
                          bossDefeatVerbs[(victory.key.hashCode & 0x7fffffff) %
                              bossDefeatVerbs.length],
                      kind: BossKind.values.firstWhere(
                        (k) =>
                            'bossVictory:${k.name}' == victory.data['material'],
                      ),
                    ),
                  ),
                if (session.match != null) ...[
                  if (!_desktop)
                    Positioned(
                      left: geometry.reload.dx - buttonSize / 2,
                      top: geometry.reload.dy - buttonSize / 2,
                      child: Semantics(
                        label: 'Reload',
                        button: true,
                        enabled: session.controlsEnabled,
                        onTap: session.controlsEnabled ? session.reload : null,
                        child: SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: OnlineActionSkin(
                                glyph: PixelGlyph.reload,
                                label: 'RELOAD',
                                opacity: controls.opacity,
                                active:
                                    session.gun?.reloading == true ||
                                    pointers.containsValue('reload'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_desktop)
                    Positioned(
                      left: geometry.grenade.dx - buttonSize / 2,
                      top: geometry.grenade.dy - buttonSize / 2,
                      child: Semantics(
                        label: 'Hold and drag to aim grenade; release to throw',
                        button: true,
                        enabled:
                            session.controlsEnabled &&
                            session.grenadesAvailable &&
                            (session.gun?.grenadeCharges ?? 0) > 0,
                        child: GrenadeAimButton(
                          input: grenadeAim,
                          onChanged: () => mounted ? setState(() {}) : null,
                          size: buttonSize,
                          charges: session.grenadesAvailable
                              ? session.gun?.grenadeCharges ?? 0
                              : 0,
                          capacity: session.gun?.grenadeCapacity ?? 2,
                          progress: session.gun?.grenadeProgress ?? 0,
                          remaining: session.gun?.grenadeRemaining ?? 0,
                          opacity: controls.opacity,
                          onThrow:
                              session.controlsEnabled &&
                                  session.grenadeAimingAvailable &&
                                  (session.gun?.grenadeCooldown ?? 0) <= 0
                              ? (direction, power) => session.throwGrenade(
                                  aim: direction,
                                  power: power,
                                )
                              : null,
                        ),
                      ),
                    ),
                  OnlineObjectives(session: session),
                  OnlineCombatHud(
                    session: session,
                    controller: _controllerActive,
                  ),
                ],
                if (seconds - damageAt < .9)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xffA54F42).withValues(
                                alpha: (1 - (seconds - damageAt) / .9) * .35,
                              ),
                            ],
                            stops: const [.65, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (seconds - damageAt < .9)
                  Positioned(
                    top: 110,
                    left: 16,
                    child: IgnorePointer(
                      child: Text(
                        '-${lostHp.toStringAsFixed(1)} HP',
                        style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          color: Color(0xffEEA68D),
                        ),
                      ),
                    ),
                  ),
                if (session.menuOpen)
                  Positioned.fill(
                    child: OnlineMatchMenu(
                      session: session,
                      resume: () {
                        clear();
                        setState(() => session.menuOpen = false);
                      },
                    ),
                  ),
                if (!session.connected &&
                    !session.menuOpen &&
                    !session.connecting &&
                    !session.retryScheduled)
                  Center(
                    child: SizedBox(
                      width: 240,
                      child: ClickButton(
                        text: session.guestRejected
                            ? 'Back to menu'
                            : 'Retry connection',
                        onTap: () => session.guestRejected
                            ? Navigator.of(context).pop()
                            : unawaited(session.connect()),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.bossPresentation,
    required this.session,
    required this.positions,
    required this.seconds,
    required this.artReady,
    required this.districtMap,
    required this.shotTimes,
    required this.hurtTimes,
    required this.grenadeAim,
    required this.desktopGrenadeTarget,
    required this.touchInsets,
    required this.restingAim,
    required this.mummyWalks,
    required this.scorpionGaits,
    required this.walkers,
    required this.lodestars,
    required this.guardFeedback,
    required this.mechanicFeedback,
    this.desktop = false,
    this.onProjection,
  });
  final OnlineSession session;
  final OnlineBossPresentation bossPresentation;
  final GrenadeAim grenadeAim;
  final ({Offset direction, double power})? desktopGrenadeTarget;
  final EdgeInsets touchInsets;
  final Map<String, Offset> restingAim;
  final Map<String, MummyWalk> mummyWalks;
  final Map<String, TravelGait> scorpionGaits;
  final OnlineWalkers walkers;
  final OnlineLodestars lodestars;
  final Map<String, GuardFeedback> guardFeedback;
  final Map<String, MechanicFeedback> mechanicFeedback;
  final bool desktop;
  final void Function(Rect, Offset, double)? onProjection;
  final Map<String, Offset> positions;
  final double seconds;
  final bool artReady;
  final MapComponent? districtMap;
  final Map<String, double> shotTimes, hurtTimes;
  @override
  void paint(Canvas canvas, Size size) {
    final mine = session.me;
    final reducedMotion = LocalPreferences.shared.reducedMotion;
    final enemyPositions = <String, Offset>{};
    Offset enemyPosition(OnlineEntity enemy) => enemyPositions.putIfAbsent(
      enemy.key,
      () => session.enemyPosition(enemy, reducedMotion: reducedMotion),
    );
    final presentedRounds = session.presentedProjectiles();
    final teammate = session.members
        .where(
          (m) =>
              m.team == mine?.team &&
              (session.fighters[m.identity.toHexString]?.health ?? 0) > 0,
        )
        .firstOrNull;
    final anchor = (session.gun?.health ?? 1) > 0
        ? session.identity
        : teammate?.identity.toHexString ?? session.identity;
    final center = positions[anchor] ?? Offset(mine?.x ?? 0, mine?.y ?? 0);
    final frame = desktop
        ? const Size(700 * 16 / 9, 700)
        : GameLayout.world(size);
    final world = frame / bossPresentation.zoom;
    final fit = desktop ? math.min : math.max;
    final scale = fit(size.width / world.width, size.height / world.height);
    // Crop the phone view to fill the display without widening sightlines.
    final worldSize = desktop ? world : size / scale;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.clipRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: worldSize.width,
        height: worldSize.height,
      ),
    );
    final geometry = session.gameplayGeometry;
    Rect rectOf(List<num> r) => Rect.fromLTRB(
      r[0].toDouble(),
      r[1].toDouble(),
      r[2].toDouble(),
      r[3].toDouble(),
    );
    final bounds = rectOf(geometry['bounds'] as List<num>);
    double cameraAxis(double value, double lo, double hi, double half) =>
        hi - lo <= half * 2
        ? (lo + hi) / 2
        : value.clamp(lo + half, hi - half).toDouble();
    final camera = bossPresentation.camera(
      center,
      reducedMotion: LocalPreferences.shared.reducedMotion,
    );
    final centerOfView = Offset(
      cameraAxis(camera.dx, bounds.left, bounds.right, worldSize.width / 2),
      cameraAxis(camera.dy, bounds.top, bounds.bottom, worldSize.height / 2),
    );
    onProjection?.call(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: worldSize.width * scale,
        height: worldSize.height * scale,
      ),
      centerOfView,
      scale,
    );
    canvas.translate(-centerOfView.dx, -centerOfView.dy);

    canvas.drawRect(bounds, Paint()..color = const Color(0xff252B25));
    if (artReady) {
      final image = RegunArt.shared.image(switch (session.room?.mapId) {
        'foundry' => 'arenas/foundry_floor',
        'floodworks' => 'arenas/floodworks_floor',
        'relayGraveyard' => 'arenas/relayGraveyard_floor',
        _ => 'arenas/breach_floor',
      });
      final transform = Matrix4.diagonal3Values(
        768 / image.width,
        768 / image.height,
        1,
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.ImageShader(
            image,
            ui.TileMode.repeated,
            ui.TileMode.repeated,
            transform.storage,
          )
          ..filterQuality = FilterQuality.none
          ..colorFilter = switch (session.room?.mapId) {
            'foundry' ||
            'floodworks' ||
            'relayGraveyard' => MapComponent.floorGrade,
            _ => MapComponent.breachGrade,
          },
      );
    }
    if (artReady && districtMap != null && session.room?.mode == 'coop') {
      final id = session.room?.mapId;
      final arena = ArenaType.values.where((a) => a.name == id).firstOrNull;
      if (arena != null) {
        drawArenaDistricts(
          canvas,
          districtMap!,
          arena,
          Rect.fromCenter(
            center: centerOfView,
            width: worldSize.width,
            height: worldSize.height,
          ),
          legacy: !session.survivalArenasAvailable,
          flowTime: LocalPreferences.shared.reducedMotion ? 0 : seconds % 31,
        );
      }
    }
    canvas.drawRect(
      bounds.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xff8E7959),
    );
    for (final raw in geometry['obstacles'] as List) {
      final rect = rectOf(raw as List<num>);
      final id = session.room?.mapId;
      final arena = ArenaType.values.where((a) => a.name == id).firstOrNull;
      final map = districtMap;
      final sprite =
          artReady &&
              map != null &&
              arena != null &&
              session.survivalArenasAvailable
          ? arenaSolidSprite(map, arena, rect)
          : null;
      if (sprite != null) {
        paintArenaSolid(canvas, rect, sprite);
        continue;
      }
      if (artReady &&
          arena == ArenaType.floodworks &&
          session.survivalArenasAvailable) {
        paintFloodDivider(canvas, rect);
        continue;
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: rect.bottomCenter + const Offset(8, -10),
          width: rect.width + 20,
          height: rect.height * .65,
        ),
        Paint()..color = const Color(0x750A1114),
      );
      if (artReady) {
        WallArt.paint(
          canvas,
          rect,
          iron:
              geometry['material'] == 'iron' ||
              session.room?.mapId == 'foundry',
          actors: positions.values,
        );
      }
    }
    if (artReady) {
      final bossKinds = {
        for (final e in session.scene.where(
          (e) => e.kind == 'enemy' && e.data['boss'] == true,
        ))
          e.key: BossKind.values
              .where((b) => b.name == e.data['kind'])
              .firstOrNull,
      };
      for (final e in session.scene.where((e) => e.kind != 'enemy')) {
        OnlineWorldArt.floor(
          canvas,
          e,
          bossKind: bossKinds[e.data['owner']],
          foundry: session.room?.mapId == 'foundry',
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
      }
    }
    if (artReady) {
      for (final enemy in session.scene.where((e) => e.kind == 'enemy')) {
        if (enemy.data['kind'] == 'lodestar') {
          lodestars.floor(
            canvas,
            enemy.key,
            session.room?.mapId == 'foundry'
                ? ArenaType.foundry
                : ArenaType.breach,
            LocalPreferences.shared.reducedMotion,
          );
          continue;
        }
        if (enemy.data['kind'] == 'walker') {
          walkers.floor(
            canvas,
            enemy.key,
            session.room?.mapId == 'foundry'
                ? ArenaType.foundry
                : ArenaType.breach,
            LocalPreferences.shared.reducedMotion,
          );
          continue;
        }
        OnlineWorldArt.enemyFloor(
          canvas,
          enemy,
          foundry: session.room?.mapId == 'foundry',
          presentedPosition: enemyPosition(enemy),
          hideSpawn: bossPresentation.actors.any((a) => a.key == enemy.key),
        );
        if (enemy.data['boss'] == true && enemy.number('health') <= 0) {
          OnlineWorldArt.bossDeparture(
            canvas,
            enemy,
            foundry: session.room?.mapId == 'foundry',
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
        }
      }
    }
    for (final actor in bossPresentation.actors) {
      final kind = BossKind.values
          .where((k) => k.name == actor.data['kind'])
          .firstOrNull;
      if (kind == null) continue;
      BossPortalArt.paint(
        canvas,
        Offset(actor.x, actor.y + actor.number('size') * .35),
        kind,
        bossPresentation.seal,
        bossPresentation.fade,
        time: bossPresentation.elapsed,
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
    }
    final grenadeTarget = desktop
        ? desktopGrenadeTarget
        : grenadeAim.active && !grenadeAim.cancelled
        ? (
            direction: grenadeAim.direction ?? session.quickGrenadeDirection,
            power: grenadeAim.power(
              LocalPreferences.shared.controls.displayButtonSize(
                    Size(
                      size.width - touchInsets.horizontal,
                      size.height - touchInsets.vertical,
                    ),
                  ) *
                  .85,
            ),
          )
        : null;
    if (grenadeTarget != null && session.controlsEnabled && mine != null) {
      final direction = grenadeTarget.direction;
      final start = positions[session.identity] ?? Offset(mine.x, mine.y),
          d = direction.distance < .001
              ? const Offset(1, 0)
              : direction / direction.distance;
      final obstacles = (geometry['obstacles'] as List)
          .map((r) => rectOf((r as List).cast<num>()))
          .toList();
      bool blocked(Offset a, Offset b) =>
          !bounds.deflate(8).contains(b) ||
          obstacles.any(
            (r) => ArenaGeometry.crosses(
              Vector2(a.dx, a.dy),
              Vector2(b.dx, b.dy),
              r.inflate(8),
            ),
          );
      var origin = start + d * GrenadeSpec.releaseOffset;
      if (blocked(start, origin)) origin = start;
      final flight = GrenadeFlight(
        origin,
        d * GrenadeSpec.speed * grenadeTarget.power,
      );
      final targets = <(Offset, double)>[
        for (final e in session.scene.where(
          (e) =>
              e.kind == 'enemy' &&
              e.number('health') > 0 &&
              e.number('spawning') <= 0,
        ))
          (Offset(e.x, e.y), e.number('radius', 30) + 8),
        for (final e in session.scene.where(
          (e) =>
              e.kind == 'enemy' &&
              e.number('health') > 0 &&
              e.number('spawning') <= 0,
        ))
          for (final p
              in (e.data['weakPoints'] as List? ?? []).whereType<Map>())
            if ((p['health'] as num? ?? 0) > 0)
              (
                Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
                34,
              ),
        if (session.room?.mode == 'versus')
          for (final m in session.members.where(
            (m) =>
                m.team != mine.team &&
                (session.fighters[m.identity.toHexString]?.health ?? 0) > 0,
          ))
            (Offset(m.x, m.y), 38),
      ];
      paintGrenadeTrajectory(
        canvas,
        grenadePreview(
          flight,
          blocked: blocked,
          contactDetonation: !session.groundOrdnanceAvailable,
          contact: (a, b) =>
              targets.any((t) => grenadeSegmentContact(a, b, t.$1, t.$2)),
        ),
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
    }
    if (artReady) {
      for (final dead in session.scene.where(
        (e) =>
            e.kind == 'enemy' &&
            e.data['boss'] != true &&
            e.number('health') <= 0,
      )) {
        OnlineWorldArt.enemy(
          canvas,
          dead,
          foundry: session.room?.mapId == 'foundry',
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
      }
    }
    for (final member in session.members) {
      final point =
          positions[member.identity.toHexString] ?? Offset(member.x, member.y);
      canvas.drawOval(
        Rect.fromCenter(
          center: point + const Offset(0, 22),
          width: 65,
          height: 22,
        ),
        Paint()..color = const Color(0x77000000),
      );
      final p = point,
          key = member.identity.toHexString,
          gun = session.fighters[member.identity.toHexString];
      final dashing = key == session.identity
          ? session.predictedDashRemaining > 0
          : member.dashRemaining > 0;
      if (artReady && dashing && (gun?.health ?? 1) > 0) {
        final direction = key == session.identity
            ? session.movementPrediction.body?.dashDirection ??
                  Offset(member.dashX, member.dashY)
            : Offset(member.dashX, member.dashY);
        final reduced = LocalPreferences.shared.reducedMotion;
        for (var i = 0; i < (reduced ? 1 : 3); i++) {
          AttackVfx.dashDust(
            canvas,
            p + const Offset(0, 28) - direction * (i * 22),
            direction,
            progress: .15 + i * .26,
            reducedMotion: reduced,
            ambient: BossArt.ambient(
              session.room?.mapId == 'foundry'
                  ? ArenaType.foundry
                  : ArenaType.breach,
            ),
          );
        }
      }
    }
    for (final grenade in presentedRounds.where(
      (r) => r.data['kind'] == 'grenade',
    )) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(grenade.x, grenade.y),
          width: 24,
          height: 9,
        ),
        Paint()..color = const Color(0x700c1012),
      );
    }
    final enemies =
        session.scene
            .where(
              (e) =>
                  e.kind == 'enemy' &&
                      (e.number('health') > 0 ||
                          e.data['kind'] == 'walker' ||
                          e.data['kind'] == 'lodestar') ||
                  e.kind == 'supply' && e.data['phase'] != 'warning' ||
                  e.kind == 'support',
            )
            .toList()
          ..sort((a, b) => enemyPosition(a).dy.compareTo(enemyPosition(b).dy));
    var enemyIndex = 0;
    void drawEnemy() {
      final enemy = enemies[enemyIndex++];
      if (enemy.kind == 'support') {
        OnlineWorldArt.supportBody(
          canvas,
          enemy,
          foundry: session.room?.mapId == 'foundry',
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
        return;
      }
      if (enemy.kind == 'supply') {
        OnlineWorldArt.supplyBody(
          canvas,
          enemy,
          foundry: session.room?.mapId == 'foundry',
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
        return;
      }
      final beams =
          session.scene
              .where(
                (h) =>
                    h.kind == 'hazard' &&
                    h.data['material'] == 'laser' &&
                    h.number('muzzleProtocol') >= 2 &&
                    h.data['owner'] == enemy.key &&
                    h.number('age') <
                        h.number('delay') +
                            h.number('warning') +
                            h.number('duration'),
              )
              .toList()
            ..sort(
              (a, b) => (a.number('delay') - a.number('age')).compareTo(
                b.number('delay') - b.number('age'),
              ),
            );
      final aim = beams.isEmpty
          ? null
          : OnlineWorldArt.point((beams.first.data['points'] as List).last);
      final revealing =
          bossPresentation.holding &&
          bossPresentation.actors.any((a) => a.key == enemy.key);
      if (revealing) {
        canvas.saveLayer(
          null,
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, bossPresentation.opacity),
        );
      }
      if (enemy.data['kind'] == 'lodestar') {
        lodestars.body(
          canvas,
          enemy.key,
          LocalPreferences.shared.reducedMotion,
        );
        if (revealing) canvas.restore();
        return;
      }
      if (enemy.data['kind'] == 'walker') {
        walkers.body(canvas, enemy.key, LocalPreferences.shared.reducedMotion);
        if (revealing) canvas.restore();
        return;
      }
      OnlineWorldArt.enemy(
        canvas,
        enemy,
        presentedPosition: enemyPosition(enemy),
        mummyWalk: mummyWalks[enemy.key],
        scorpionGait: scorpionGaits[enemy.key],
        laserAim: aim,
        laserOrigin: beams.isEmpty
            ? null
            : OnlineWorldArt.point((beams.first.data['points'] as List).first),
        foundry: session.room?.mapId == 'foundry',
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
      if (revealing) canvas.restore();
    }

    if (artReady) {
      WallArt.perimeter(
        canvas,
        bounds,
        iron:
            geometry['material'] == 'iron' || session.room?.mapId == 'foundry',
      );
    }
    final sorted = session.members.toList()..sort((a, b) => a.y.compareTo(b.y));
    for (final member in sorted) {
      while (artReady &&
          enemyIndex < enemies.length &&
          enemyPosition(enemies[enemyIndex]).dy < member.y) {
        drawEnemy();
      }
      final p =
          positions[member.identity.toHexString] ?? Offset(member.x, member.y);
      final key = member.identity.toHexString, gun = session.fighters[key];
      final hurt = seconds - (hurtTimes[key] ?? -10) < .48;
      final shotAge = seconds - (shotTimes[key] ?? -10);
      final color = member.team == 0
          ? const Color(0xffA9C990)
          : const Color(0xffD7A3B7);
      canvas.drawCircle(
        p,
        34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
      if (artReady) {
        final moving =
            (key == session.identity
                ? session.moveX != 0 || session.moveY != 0
                : member.moveX != 0 || member.moveY != 0) &&
            (gun?.health ?? 1) > 0;
        final survivor = gun?.survivor ?? 'rook';
        final dead = gun != null && gun.health <= 0;
        final frame = moving ? (seconds * 12).floor() % 8 : 0;
        final facingAim = key == session.identity
            ? Offset(session.aimX, session.aimY)
            : Offset(member.aimX, member.aimY);
        final facing = facingAim.dx.abs() > facingAim.dy.abs()
            ? (facingAim.dx < 0 ? 2 : 0)
            : (facingAim.dy > 0 ? 1 : 3);
        final guard = gun?.progress['guard'] == true && !dead;
        final wardBody = Rect.fromLTRB(
          p.dx - 27,
          p.dy - 42,
          p.dx + 27,
          p.dy + 38,
        );
        final absorbedAge = guardFeedback[key]?.breakAge ?? -1;
        final rechargeAge = guardFeedback[key]?.reformAge ?? -1;
        CombatStatusPainter.ward(
          canvas,
          wardBody,
          ready: guard,
          front: false,
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
        final releaseAge = session.upgradeReceipts.releaseAge(key);
        final released =
            session.match?.phase == 'active' &&
            releaseAge >= 0 &&
            releaseAge < .24;
        final reward =
            session.upgradeReceipts.active[key] ??
            session.upgradeReceipts.releasing[key];
        final rewardFamily = reward?.family ?? 'heavyLoad';
        final held =
            !dead && reward != null && session.match?.phase == 'confirmation';
        final holdDuration = reward?.beforeRank == 0 ? 1.1 : .8;
        final beat = (1 - (session.match?.phaseSeconds ?? 0) / holdDuration)
            .clamp(0.0, 1.0);
        final survivorSprite =
            (held || released) &&
                survivor == 'rook' &&
                RegunArt.shared.contains(UpgradeArtLease.atlasFor(rewardFamily))
            ? RegunArt.shared.sprite(
                UpgradeArtLease.atlasFor(rewardFamily),
                facing * UpgradeArtLease.columns +
                    (LocalPreferences.shared.reducedMotion
                        ? 7
                        : released
                        ? upgradeReleaseFrame(rewardFamily, releaseAge)
                        : upgradeInfusionFrame(beat, rewardFamily)),
              )
            : held || released
            ? (!LocalPreferences.shared.reducedMotion &&
                      (released ? releaseAge < .12 : beat >= .18)
                  ? RegunArt.shared.survivorActionFrame(survivor, facing, 1)
                  : RegunArt.shared.survivorIdleFrame(survivor, facing, 0))
            : moving && !dead
            ? RegunArt.shared.survivorRunFrame(survivor, facing, frame)
            : RegunArt.shared.sprite(
                dead
                    ? 'characters/${survivor}_actions'
                    : 'characters/$survivor',
                dead ? facing * 4 + 3 : facing * 8,
              );
        if (held) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          paintUpgradeInfusion(
            canvas,
            reward.family,
            beat,
            reducedMotion: LocalPreferences.shared.reducedMotion,
            foreground: false,
          );
          canvas.restore();
        }
        final absorption =
            !LocalPreferences.shared.reducedMotion && (held || released)
            ? released
                  ? (1 - releaseAge / .16).clamp(0.0, 1.0)
                  : ((beat - .16) / .78).clamp(0.0, 1.0)
            : 0.0;
        survivorSprite.render(
          canvas,
          position: Vector2(p.dx, p.dy),
          size: Vector2.all(100),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..colorFilter = hurt
                ? const ColorFilter.mode(Color(0xffDD826C), BlendMode.modulate)
                : absorption > 0
                ? ColorFilter.mode(
                    upgradeInfusionColor(reward!.family)
                        .withValues(alpha: absorption * .62),
                    BlendMode.srcATop,
                  )
                : null,
        );
        if (held) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          paintUpgradeInfusion(
            canvas,
            reward.family,
            beat,
            reducedMotion: LocalPreferences.shared.reducedMotion,
            foreground: true,
          );
          canvas.restore();
          canvas.save();
          canvas.translate(p.dx, p.dy);
          if (key == session.identity) {
            final text = TextPainter(
              text: TextSpan(
                text: upgradeReceiptDelta(reward),
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  color: Color(0xffd1c2a2),
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout(maxWidth: 550);
            canvas.drawRect(
              Rect.fromLTWH(-text.width / 2 - 8, -94, text.width + 16, 32),
              Paint()..color = const Color(0xee202721),
            );
            text.paint(canvas, Offset(-text.width / 2, -90));
          }
          canvas.restore();
        }
        if (released && reward != null) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          paintUpgradeRelease(
            canvas,
            reward.family,
            releaseAge,
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
          canvas.restore();
        }
        CombatStatusPainter.ward(
          canvas,
          wardBody,
          ready: guard,
          front: true,
          reducedMotion: LocalPreferences.shared.reducedMotion,
          breakAge: !dead ? absorbedAge : -1,
          reformAge: !dead ? rechargeAge : -1,
        );
        if (!dead) {
          MechanicVfx.healing(
            canvas,
            wardBody,
            mechanicFeedback[key]?.healAge ?? -1,
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
        }
        final useLabel = session.upgradeReceipts.useLabels[key];
        if (key == session.identity && useLabel != null && !dead) {
          final text = TextPainter(
            text: TextSpan(
              text: useLabel,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 22,
                color: Color(0xffd1c2a2),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 500);
          canvas.drawRect(
            Rect.fromLTWH(
              p.dx - text.width / 2 - 8,
              p.dy - 94,
              text.width + 16,
              34,
            ),
            Paint()..color = const Color(0xee202721),
          );
          text.paint(canvas, Offset(p.dx - text.width / 2, p.dy - 90));
        }
        if (gun != null && !dead) {
          final weapon = WeaponType.values.firstWhere(
            (w) => w.name == gun.weapon,
          );
          canvas.save();
          final aiming = restingAim[key] ?? Offset(member.aimX, member.aimY);
          final heading =
              shotAge < weaponFlashDuration && key != session.identity
              ? Offset(math.cos(gun.shotAngle), math.sin(gun.shotAngle))
              : aiming.distanceSquared > 0
              ? aiming / aiming.distance
              : const Offset(1, 0);
          final hand =
              p + WeaponArtSpec.handMount + heading * WeaponArtSpec.handReach;
          canvas.translate(hand.dx, hand.dy);
          canvas.rotate(math.atan2(heading.dy, heading.dx));
          if (heading.dx < 0) canvas.scale(1, -1);
          paintWeapon(
            canvas,
            weapon,
            reload: gun.reloading ? gun.reloadProgress : -1,
            reloadShells: gun.capacity - gun.ammo,
            tactical: gun.data['reloadTactical'] == true,
            recoil: (1 - shotAge / WeaponFeel.of(weapon).recovery).clamp(0, 1),
            flash: (1 - shotAge / weaponFlashDuration).clamp(0, 1),
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
          MechanicVfx.weapon(
            canvas,
            ready: _onlineReadyFlags(gun),
            spent: mechanicFeedback[key]?.spent ?? 0,
            spentAge: mechanicFeedback[key]?.spentAge ?? 1,
            reducedMotion: LocalPreferences.shared.reducedMotion,
            muzzle: WeaponFeel.of(weapon).muzzle,
          );

          canvas.restore();
        }
      }
      if (gun != null) {
        canvas.drawRect(
          Rect.fromLTWH(p.dx - 32, p.dy - 48, 64, 5),
          Paint()..color = const Color(0xff302332),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            p.dx - 32,
            p.dy - 48,
            64 * (gun.health / gun.maxHealth).clamp(0, 1),
            5,
          ),
          Paint()..color = color,
        );
      }
      final text = TextPainter(
        text: TextSpan(
          text: member.name,
          style: TextStyle(
            fontFamily: FontFam.orbitron,
            color: color,
            fontSize: 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p + Offset(-text.width / 2, -65));
    }
    while (artReady && enemyIndex < enemies.length) {
      drawEnemy();
    }
    for (final round in presentedRounds) {
      if (round.data['kind'] == 'grenade') {
        final flight = round.data['flight'] as Map? ?? {};
        final height = LocalPreferences.shared.reducedMotion
            ? 0.0
            : (flight['height'] as num? ?? 0).toDouble();
        paintGrenade(
          canvas,
          Offset(round.x, round.y - height),
          28,
          angle: LocalPreferences.shared.reducedMotion
              ? 0
              : (flight['spin'] as num? ?? 0).toDouble(),
        );
        continue;
      }
      final weapon = WeaponType.values.firstWhere(
            (w) => w.name == round.weapon,
          ),
          feel = WeaponFeel.of(weapon),
          draw = WeaponFeel.round(weapon);
      canvas.save();
      canvas.translate(round.x, round.y);
      canvas.rotate(math.atan2(round.dy, round.dx));
      if (round.data['hostile'] == true) {
        if (round.speed <= 400) {
          Enemy3Projectile.paintDart(canvas);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(11, 0)
              ..lineTo(0, 11)
              ..lineTo(-11, 0)
              ..lineTo(0, -11)
              ..close(),
            Paint()..color = const Color(0xffBD7397),
          );
          canvas.drawRect(
            const Rect.fromLTWH(-4, -4, 8, 8),
            Paint()..color = const Color(0xffFFF0CD),
          );
        }
      } else if (round.data['supportBallistic'] == true) {
        SupportArt.roundAt(canvas, Offset.zero, const Offset(1, 0));
      } else if (weapon == WeaponType.arcCaster) {
        AttackVfx.lightning(
          canvas,
          const Offset(-22, 0),
          const Offset(5, 0),
          1,
          heavy: true,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(
            -draw.length,
            -draw.thickness / 2,
            draw.length,
            draw.thickness,
          ),
          Paint()
            ..color = feel.color
            ..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            -draw.length * .4,
            -draw.thickness * .22,
            draw.length * .6,
            draw.thickness * .44,
          ),
          Paint()
            ..color = const Color(0xffFFF1CF)
            ..isAntiAlias = false,
        );
      }
      canvas.restore();
    }

    if (bossPresentation.holding && bossPresentation.actors.isNotEmpty) {
      FreezeFocus.paint(
        canvas,
        canvas.getLocalClipBounds(),
        bossPresentation.focus,
        bossPresentation.actors.length > 1 ? 650 : 340,
        FreezeFocus.envelope(
          bossPresentation.elapsed,
          bossPresentation.duration,
        ),
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
    }
    lodestars.ordnance(
      canvas,
      session.room?.mapId == 'foundry' ? ArenaType.foundry : ArenaType.breach,
      LocalPreferences.shared.reducedMotion,
    );
    walkers.ordnance(
      canvas,
      session.room?.mapId == 'foundry' ? ArenaType.foundry : ArenaType.breach,
      LocalPreferences.shared.reducedMotion,
    );
    if (session.match?.phase == 'confirmation') {
      final reward = session.upgradeReceipts.active[session.identity];
      if (reward != null) {
        final duration = reward.beforeRank == 0 ? 1.1 : .8;
        final elapsed = (duration - (session.match?.phaseSeconds ?? duration))
            .clamp(0.0, duration);
        FreezeFocus.paint(
          canvas,
          canvas.getLocalClipBounds(),
          positions[session.identity] ?? center,
          230,
          FreezeFocus.envelope(elapsed, duration),
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}

// Only mechanics implemented by the admitted server arsenal. Measured Shot has
// no hosted implementation and must never acquire a client-predicted ready cue.
int _onlineReadyFlags(OnlineGun gun) =>
    gun.health <= 0 || gun.reloading || gun.ammo <= 0
    ? 0
    : (gun.ammo == 1 && gun.rank('lastShell') > 0 ? 1 : 0) |
          (gun.progress['breachCharged'] == true && gun.rank('breachLoader') > 0
              ? 2
              : 0);
