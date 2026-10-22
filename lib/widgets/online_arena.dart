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
import 'package:regun/multiplayer/geometry.dart';
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
  final weaponHeadings = <String, WeaponHeading>{};
  final restingAim = <String, Offset>{};
  final grenadeAim = GrenadeAim();
  final localFireFeedback = LocalFireFeedback();
  final Map<int, String> pointers = {};
  final Map<String, Offset> origins = {}, knobs = {}, displayed = {};
  final Set<LogicalKeyboardKey> keys = {};
  bool artReady = false;
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
  final Map<String, bool> _wasReloading = {};
  final Map<String, double> _damageTotals = {};
  double lostHp = 0, damageAt = -10;
  final Map<String, String> _worldCues = {};
  String? _music;
  int? _offerCue;
  void _sceneCues() {
    final audio = ref.read(soloudPlayProvider);
    if (_warmed.add('supply')) unawaited(audio.warmSupply());
    for (final e in session.scene.where(
      (e) => e.kind == 'enemy' && e.data['boss'] == true,
    )) {
      final kind = BossKind.values.byName(e.data['kind'] as String);
      if (_warmed.add('boss_${kind.name}')) unawaited(audio.warmBoss(kind));
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
      if (entity.kind == 'supply') {
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
        } else if (d['kind'] == 'ranged' &&
            d['phase'] == 0 &&
            old.startsWith('1:')) {
          unawaited(audio.play('enemy3projectile.wav'));
        }
      }
    }
    _worldCues.removeWhere((key, _) => !session.scene.any((e) => e.key == key));
  }

  double seconds = 0;
  Duration last = Duration.zero;
  OnlineSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    audio = ref.read(soloudPlayProvider);
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
      final dt = ((elapsed - last).inMicroseconds / 1000000).clamp(0.0, .1);
      last = elapsed;
      session.predictionReducedMotion = LocalPreferences.shared.reducedMotion;
      seconds += dt * (session.match?.phase == 'choice' ? .1 : 1);
      if (_controlled && !session.controlsEnabled) clear();
      _controlled = session.controlsEnabled;
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

  void _combatCues() {
    final connection =
        '${session.me?.generation}:${session.room?.id}:${session.connected}';
    if (connection != _generation) {
      grenadeAim.cancel();
      _generation = connection;
      restingAim.clear();
      weaponHeadings.clear();
      _worldCues.clear();
      _offerCue = null;
      _shots.clear();
      _reloads.clear();
      _damage.clear();
      _damageTotals.clear();
      _reloadPhase.clear();
      _wasReloading.clear();
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
    grenadeAim.cancel();
    pointers.clear();
    origins.clear();
    knobs.clear();
    keys.clear();
    session.neutral();
  }

  @override
  void dispose() {
    if (artReady) {
      for (final c in CharacterType.values.where((c) => c.availableOnline)) {
        RegunArt.shared.releaseSurvivor(c.name);
      }
    }
    ticker.dispose();
    leases.dispose();
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161B18),
    body: SafeArea(
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
                  child: Listener(
                    onPointerDown: (event) {
                      if (!session.controlsEnabled) return;
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
                    onPointerMove: update,
                    onPointerUp: release,
                    onPointerCancel: release,
                    child: CustomPaint(
                      painter: _ArenaPainter(
                        session: session,
                        positions: displayed,
                        seconds: seconds,
                        artReady: artReady,
                        shotTimes: shotTimes,
                        hurtTimes: hurtTimes,
                        grenadeAim: grenadeAim,
                        restingAim: restingAim,
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
                            cooldown:
                                session.predictedDashCooldown /
                                session.predictedDashDuration,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (session.match != null) ...[
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
                  OnlineCombatHud(session: session),
                ],
                if (seconds - damageAt < .5)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xffA54F42).withValues(
                                alpha: (1 - (seconds - damageAt) / .5) * .35,
                              ),
                            ],
                            stops: const [.65, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (seconds - damageAt < .5)
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
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.session,
    required this.positions,
    required this.seconds,
    required this.artReady,
    required this.shotTimes,
    required this.hurtTimes,
    required this.grenadeAim,
    required this.restingAim,
  });
  final OnlineSession session;
  final GrenadeAim grenadeAim;
  final Map<String, Offset> restingAim;
  final Map<String, Offset> positions;
  final double seconds;
  final bool artReady;
  final Map<String, double> shotTimes, hurtTimes;
  @override
  void paint(Canvas canvas, Size size) {
    final mine = session.me;
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
    final worldSize = GameLayout.world(size);
    final scale = math.min(
      size.width / worldSize.width,
      size.height / worldSize.height,
    );
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
    final geometry =
        onlineGeometry[session.room?.mapId] ?? onlineGeometry['network_lab']!;
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
    canvas.translate(
      -cameraAxis(center.dx, bounds.left, bounds.right, worldSize.width / 2),
      -cameraAxis(center.dy, bounds.top, bounds.bottom, worldSize.height / 2),
    );

    canvas.drawRect(bounds, Paint()..color = const Color(0xff252B25));
    if (artReady) {
      final image = RegunArt.shared.image(
        session.room?.mapId == 'foundry'
            ? 'arenas/foundry_floor'
            : 'arenas/breach_floor',
      );
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
          ..colorFilter = const ColorFilter.mode(
            Color(0xff6B7770),
            BlendMode.modulate,
          ),
      );
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
      for (final e in session.scene.where((e) => e.kind != 'enemy')) {
        OnlineWorldArt.floor(
          canvas,
          e,
          foundry: session.room?.mapId == 'foundry',
          reducedMotion: LocalPreferences.shared.reducedMotion,
        );
      }
    }
    final enemies = session.scene.where((e) => e.kind == 'enemy').toList()
      ..sort((a, b) => a.y.compareTo(b.y));
    var enemyIndex = 0;
    void drawEnemy() {
      final enemy = enemies[enemyIndex++];
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
      OnlineWorldArt.enemy(
        canvas,
        enemy,
        laserAim: aim,
        laserOrigin: beams.isEmpty
            ? null
            : OnlineWorldArt.point((beams.first.data['points'] as List).first),
        foundry: session.room?.mapId == 'foundry',
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
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
          enemies[enemyIndex].y < member.y) {
        drawEnemy();
      }
      final p =
          positions[member.identity.toHexString] ?? Offset(member.x, member.y);
      final key = member.identity.toHexString, gun = session.fighters[key];
      final hurt = seconds - (hurtTimes[key] ?? -10) < .32;
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

      final shotAge = seconds - (shotTimes[key] ?? -10);
      final color = member.team == 0
          ? const Color(0xffA9C990)
          : const Color(0xffD7A3B7);
      canvas.drawOval(
        Rect.fromCenter(center: p + const Offset(0, 22), width: 65, height: 22),
        Paint()..color = const Color(0x77000000),
      );
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
        final survivorSprite = moving && !dead
            ? RegunArt.shared.survivorRunFrame(survivor, facing, frame)
            : RegunArt.shared.sprite(
                dead
                    ? 'characters/${survivor}_actions'
                    : 'characters/$survivor',
                dead ? facing * 4 + 3 : facing * 8,
              );
        survivorSprite.render(
          canvas,
          position: Vector2(p.dx, p.dy),
          size: Vector2.all(100),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..colorFilter = hurt
                ? const ColorFilter.mode(Color(0xffDD826C), BlendMode.modulate)
                : null,
        );
        if (gun != null && !dead) {
          final weapon = WeaponType.values.firstWhere(
            (w) => w.name == gun.weapon,
          );
          canvas.save();
          canvas.translate(p.dx, p.dy + 6);
          final heading = restingAim[key] ?? Offset(member.aimX, member.aimY);
          canvas.rotate(math.atan2(heading.dy, heading.dx));
          paintWeapon(
            canvas,
            weapon,
            reload: gun.reloading ? gun.reloadProgress : -1,
            reloadShells: gun.capacity - gun.ammo,
            tactical: gun.data['reloadTactical'] == true,
            recoil: (1 - shotAge / WeaponFeel.of(weapon).recovery).clamp(0, 1),
            reducedMotion: LocalPreferences.shared.reducedMotion,
          );
          if (shotAge < .045 && !LocalPreferences.shared.reducedMotion) {
            final feel = WeaponFeel.of(weapon);
            AttackVfx.chip(canvas, Offset(feel.muzzle + 8, 0), 14, feel.color);
          }
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
    for (final round in session.presentedProjectiles()) {
      if (round.data['kind'] == 'grenade') {
        final flight = round.data['flight'] as Map? ?? {};
        final height = LocalPreferences.shared.reducedMotion
            ? 0.0
            : (flight['height'] as num? ?? 0).toDouble();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(round.x, round.y),
            width: 24,
            height: 9,
          ),
          Paint()..color = const Color(0x700c1012),
        );
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

    if (grenadeAim.active &&
        !grenadeAim.cancelled &&
        session.controlsEnabled &&
        mine != null) {
      final direction = grenadeAim.direction ?? session.quickGrenadeDirection;
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
      var origin = start + d * 36;
      if (blocked(start, origin)) origin = start;
      final flight = GrenadeFlight(
        origin,
        d *
            GrenadeSpec.speed *
            grenadeAim.power(
              LocalPreferences.shared.controls.displayButtonSize(size) * .85,
            ),
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
          contact: (a, b) =>
              targets.any((t) => grenadeSegmentContact(a, b, t.$1, t.$2)),
        ),
        reducedMotion: LocalPreferences.shared.reducedMotion,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
