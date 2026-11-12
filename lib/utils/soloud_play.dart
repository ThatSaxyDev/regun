import 'dart:ui' show Offset;

import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';

class SoloudPlay {
  final SoLoud _soloud = SoLoud.instance;
  final _sources = <String, Future<AudioSource>>{};
  final _reportedFailures = <String>{};
  final _lastPlayed = <String, int>{};
  final _clock = Stopwatch()..start();
  SoundHandle? _musicHandle;
  SoundHandle? _movementVoice, _crowdVoice, _warningVoice;
  int _lastWarning = -1000;
  final _weaponLoops = <String, SoundHandle>{};
  final _loopRequests = <String, int>{};
  String? _music;
  int _musicRequest = 0;
  double _musicVolume = 0.6, _sfxVolume = 0.8;

  void configure({required double music, required double sfx}) {
    _musicVolume = music.clamp(0, 1);
    _sfxVolume = sfx.clamp(0, 1);
    try {
      if (_soloud.isInitialized && _musicHandle != null) {
        _soloud.setVolume(_musicHandle!, _musicVolume * 0.25);
      }
    } on Object {
      _musicHandle = null;
    }
  }

  Future<AudioSource> _source(String asset) => _sources.putIfAbsent(
    asset,
    () => _soloud.loadAsset('assets/audio/$asset'),
  );

  Future<void> warmControllerMenu() async {
    if (!_soloud.isInitialized) return;
    for (final asset in ['menu_move.wav', 'menu_back.wav', 'click.mp3']) {
      try {
        await _source(asset);
      } on Object {
        _sources.remove(asset);
      }
    }
  }

  Future<void> warmCombat(WeaponType weapon) async {
    try {
      if (!_soloud.isInitialized) return;
      final names = [
        for (var i = 0; i < 3; i++) 'shot_${weapon.name}_$i.wav',
        'impact_${weapon.name}.wav',
        if (weapon == WeaponType.houndrack || weapon == WeaponType.stormOrb)
          'flight_${weapon.name}.wav',
        if (weapon == WeaponType.stormOrb) ...[
          'zap_stormOrb.wav',
          'pass_stormOrb.wav',
        ],
        if (weapon == WeaponType.twinVerdict) ...[
          'prime_twinVerdict.wav',
          'verdict_twinVerdict.wav',
        ],
        if (weapon == WeaponType.anchorEngine) ...[
          'plant_anchorEngine.wav',
          'crush_anchorEngine.wav',
        ],
        if (weapon == WeaponType.faultlineDriver) 'section_faultlineDriver.wav',
        if (weapon == WeaponType.mourningBell) 'echo_mourningBell.wav',
        if (weapon == WeaponType.ringCaster) 'return_ringCaster.wav',
        if (weapon == WeaponType.beltRepeater) 'spin_beltRepeater.wav',
        if (weapon.isContinuous || weapon == WeaponType.beltRepeater)
          'sustain_${weapon.name}.wav',
        'sentry_fire.wav',
        'sentry_burst.wav',
        'sentry_reload.wav',
        'sentry_incoming.wav',
        'aura_start.wav',
        'aura_end.wav',
        'hurt_player.wav',
        'coinSound2.wav',
        'blast.wav',
        'upgrade_pulse.wav',
        'grenade_throw.wav',
        'dash_burst.wav',
        'dash_land.wav',
        'enemy_scuttle.wav',
        'enemy_skitter_warn.wav',
        for (final kind in ['press', 'sluice', 'relay'])
          'machine_${kind}_charge.wav',
        'machine_press_hit.wav',
        'machine_sluice_flow.wav',
        'machine_relay_pulse.wav',
        for (final surface in ['stone', 'metal', 'wet'])
          for (var i = 0; i < 3; i++) 'step_${surface}_$i.wav',
        'enemy3projectile.wav',
        'impact_guard.wav',
        'impact_boss.wav',
        'impact_poison.wav',
        if (weapon == WeaponType.shotgun) ...[
          'reload_shotgun_shell.wav',
          'reload_shotgun_pump.wav',
        ] else
          for (var i = 0; i < 3; i++) 'reload_${weapon.name}_$i.wav',
      ];
      await Future.wait(
        names.map((name) async {
          try {
            await _source(name);
          } catch (_) {
            _sources.remove(name);
          }
        }),
      );
    } catch (_) {
      // Audio is optional when native initialization is unavailable.
    }
  }

  Future<void> warmSupply() async {
    if (!_soloud.isInitialized) return;
    for (final name in [
      'land',
      'incoming',
      'break',
      'claim',
      for (var i = 0; i < 8; i++) 'charge_$i',
    ]) {
      try {
        await _source('supply_$name.wav');
      } catch (_) {
        _sources.remove('supply_$name.wav');
      }
    }
  }

  Future<void> warmWalker() async {
    try {
      if (!_soloud.isInitialized) return;
      for (final name in [
        'sentry_fire.wav',
        'shot_revolver_0.wav',
        'walker_rocket_launch.wav',
        'reload_carbine_1.wav',
        'supply_incoming.wav',
        'supply_land.wav',
        'blast.wav',
        'supply_break.wav',
        'supply_claim.wav',
      ]) {
        await _source(name);
      }
    } catch (_) {
      // Native audio remains optional, as with other encounter prewarming.
    }
  }

  Future<void> warmBoss(BossKind kind) async {
    try {
      if (!kind.expansion || !_soloud.isInitialized) return;
      await Future.wait(
        ['warn', 'hit', 'break'].map((cue) async {
          final name = 'boss_${kind.name}_$cue.wav';
          try {
            await _source(name);
          } catch (_) {
            _sources.remove(name);
          }
        }),
      );
    } catch (_) {
      // Native audio may be unavailable in tests or after interruption.
    }
  }

  SoundHandle? _railVoice;
  Offset? _railOffset;
  bool _railLoading = false;

  void syncFoundryRail(Offset? offset) {
    _railOffset = offset;
    final distance = offset?.distance ?? double.infinity;
    final handle = _railVoice;
    if (!_soloud.isInitialized || _sfxVolume == 0 || distance >= 850) {
      _railVoice = null;
      if (handle != null &&
          _soloud.isInitialized &&
          _soloud.getIsValidVoiceHandle(handle)) {
        _soloud.stop(handle);
      }
      return;
    }
    if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      if (!_railLoading &&
          !_reportedFailures.contains('foundry_rail_roll.wav')) {
        _startFoundryRail();
      }
      return;
    }
    _soloud.setVolume(handle, _railGain(distance));
    _soloud.setPan(handle, _railPan(offset!, distance));
  }

  double _railGain(double distance) {
    final proximity = (1 - distance / 850).clamp(0.0, 1.0);
    return .37 * _sfxVolume * proximity * proximity;
  }

  double _railPan(Offset offset, double distance) =>
      (offset.dx / (distance + 125) * .8).clamp(-.7, .7);

  Future<void> _startFoundryRail() async {
    _railLoading = true;
    const asset = 'foundry_rail_roll.wav';
    try {
      final source = await _source(asset);
      final offset = _railOffset;
      if (offset == null ||
          offset.distance >= 850 ||
          !_soloud.isInitialized ||
          _sfxVolume == 0) {
        return;
      }
      final distance = offset.distance;
      _railVoice = _soloud.play(
        source,
        looping: true,
        volume: _railGain(distance),
        pan: _railPan(offset, distance),
      );
    } catch (error) {
      if (_reportedFailures.add(asset)) {
        Logger('audio').warning('Could not play $asset', error);
      }
    } finally {
      _railLoading = false;
    }
  }

  final _machineVoices = <SoundHandle>[];
  int _machineEpoch = 0;

  void stopMachines() {
    _machineEpoch++;
    if (_soloud.isInitialized) {
      for (final voice in _machineVoices) {
        if (_soloud.getIsValidVoiceHandle(voice)) _soloud.stop(voice);
      }
    }
    _machineVoices.clear();
  }

  Future<void> playMachine(String asset, Offset offset) async {
    final distance = offset.distance;
    if (distance >= 940 || !_soloud.isInitialized || _sfxVolume == 0) return;
    final epoch = _machineEpoch;
    try {
      final source = await _source(asset);
      if (epoch != _machineEpoch || !_soloud.isInitialized || _sfxVolume == 0) {
        return;
      }
      _machineVoices.removeWhere(
        (handle) => !_soloud.getIsValidVoiceHandle(handle),
      );
      final proximity = 1 - distance / 940;
      final gain = asset == 'machine_press_hit.wav' ? .64 : .43;
      _machineVoices.add(
        _soloud.play(
          source,
          volume: _sfxVolume * gain * proximity,
          pan: (offset.dx / (distance + 150) * .75).clamp(-.65, .65),
        ),
      );
    } catch (error) {
      _sources.remove(asset);
      if (_reportedFailures.add(asset)) {
        Logger('audio').warning('Could not play $asset', error);
      }
    }
  }

  Future<void> playEnemyMovement(String asset, Offset offset, double range) {
    final distance = offset.distance;
    if (distance >= range) return Future<void>.value();
    return playMovement(
      asset,
      proximity: 1 - distance / range,
      pan: (offset.dx / (distance + 95) * .85).clamp(-.75, .75),
    );
  }

  Future<void> playMovement(
    String asset, {
    double proximity = 1,
    double pan = 0,
  }) async {
    if (!_soloud.isInitialized || _sfxVolume == 0 || proximity <= 0) return;
    final warning = asset == 'enemy_skitter_warn.wav';
    final crowd = asset == 'enemy_scuttle.wav';
    if (warning) _lastWarning = _clock.elapsedMilliseconds;
    try {
      final source = await _source(asset);
      if (!_soloud.isInitialized || _sfxVolume == 0) return;
      if (crowd && _clock.elapsedMilliseconds - _lastWarning < 500) return;
      final previous = warning
          ? _warningVoice
          : crowd
          ? _crowdVoice
          : _movementVoice;
      if (previous != null && _soloud.getIsValidVoiceHandle(previous)) {
        if (asset != 'dash_land.wav') return;
        _soloud.setVolume(previous, 0);
      }
      if (warning) {
        final ambient = _crowdVoice;
        if (ambient != null && _soloud.getIsValidVoiceHandle(ambient)) {
          _soloud.setVolume(ambient, 0);
        }
      }
      final gain = warning
          ? .48
          : crowd
          ? .20
          : asset == 'dash_land.wav'
          ? .32
          : .25;
      final handle = _soloud.play(
        source,
        volume: _sfxVolume * gain * proximity,
        pan: pan,
      );
      if (warning) {
        _warningVoice = handle;
      } else if (crowd) {
        _crowdVoice = handle;
      } else {
        _movementVoice = handle;
      }
    } catch (error) {
      _sources.remove(asset);
      if (_reportedFailures.add(asset)) {
        Logger('RegunAudio').warning('Could not play $asset', error);
      }
    }
  }

  Future<void> play(String assetPath) async {
    try {
      if (!_soloud.isInitialized || _sfxVolume == 0) return;
      final now = _clock.elapsedMilliseconds;
      final limit = assetPath.startsWith('flight_')
          ? (assetPath == 'flight_houndrack.wav' ? 220 : 320)
          : assetPath == 'zap_stormOrb.wav' || assetPath == 'pass_stormOrb.wav'
          ? 120
          : assetPath.startsWith('section_')
          ? 90
          : assetPath == 'dash_burst.wav'
          ? 85
          : assetPath == 'upgrade_pulse.wav'
          ? 120
          : assetPath == 'menu_move.wav' || assetPath == 'menu_back.wav'
          ? 85
          : assetPath == 'blast.wav'
          ? 120
          : assetPath.startsWith('sentry_')
          ? 85
          : assetPath.startsWith('aura_')
          ? 120
          : assetPath == 'enemy3projectile.wav'
          ? 100
          : assetPath.startsWith('impact_')
          ? 65
          : assetPath.startsWith('coin')
          ? 150
          : assetPath == 'hit.wav'
          ? 45
          : 20;
      if (now - (_lastPlayed[assetPath] ?? -1000) < limit) return;
      _lastPlayed[assetPath] = now;
      final source = await _source(assetPath);
      if (_soloud.isInitialized) {
        final gain = assetPath.startsWith('flight_')
            ? (assetPath == 'flight_houndrack.wav' ? .12 : .15)
            : assetPath == 'zap_stormOrb.wav'
            ? .28
            : assetPath == 'pass_stormOrb.wav'
            ? .34
            : assetPath.startsWith('shot_houndrack')
            ? .62
            : assetPath.startsWith('shot_stormOrb')
            ? .6
            : assetPath.startsWith('prime_')
            ? .22
            : assetPath.startsWith('verdict_')
            ? .50
            : assetPath.startsWith('plant_')
            ? .45
            : assetPath.startsWith('crush_')
            ? .55
            : assetPath.startsWith('section_') || assetPath.startsWith('echo_')
            ? .38
            : assetPath == 'level.wav'
            ? .6
            : assetPath == 'dash_burst.wav'
            ? .48
            : assetPath == 'upgrade_pulse.wav'
            ? .35
            : assetPath == 'menu_move.wav'
            ? .32
            : assetPath == 'menu_back.wav'
            ? .38
            : assetPath == 'blast.wav'
            ? .65
            : assetPath == 'grenade_throw.wav' ||
                  assetPath == 'walker_rocket_launch.wav'
            ? .3
            : assetPath == 'supply_land.wav'
            ? .8
            : assetPath.startsWith('supply_charge_')
            ? .16
            : assetPath.startsWith('supply_')
            ? .4
            : assetPath.startsWith('sentry_')
            ? .28
            : assetPath.startsWith('aura_')
            ? .24
            : assetPath == 'enemy3projectile.wav'
            ? .30
            : assetPath.startsWith('shot_')
            ? .72
            : assetPath == 'impact_houndrack.wav'
            ? .42
            : assetPath == 'impact_arcCaster.wav'
            ? .45
            : assetPath.startsWith('impact_boss')
            ? .6
            : assetPath.startsWith('impact_')
            ? .25
            : assetPath.startsWith('reload_')
            ? .32
            : assetPath.startsWith('coin')
            ? .20
            : assetPath == 'hit.wav'
            ? .2
            : .5;
        _soloud.play(source, volume: _sfxVolume * gain);
      }
    } catch (error) {
      _sources.remove(assetPath);
      if (_reportedFailures.add(assetPath)) {
        Logger('audio').warning('Could not play $assetPath: $error');
      }
    }
  }

  Future<void> startWeaponLoop(String owner, String asset) async {
    final request = (_loopRequests[owner] ?? 0) + 1;
    _loopRequests[owner] = request;
    try {
      if (!_soloud.isInitialized || _sfxVolume == 0) return;
      final source = await _source(asset);
      if (_loopRequests[owner] != request || !_soloud.isInitialized) return;
      final old = _weaponLoops.remove(owner);
      if (old != null) await _soloud.stop(old);
      if (_loopRequests[owner] != request) return;
      _weaponLoops[owner] = _soloud.play(
        source,
        volume: _sfxVolume * .15,
        looping: true,
      );
    } catch (_) {
      _sources.remove(asset);
    }
  }

  void stopWeaponLoop(String owner) {
    _loopRequests[owner] = (_loopRequests[owner] ?? 0) + 1;
    final handle = _weaponLoops.remove(owner);
    if (handle != null && _soloud.isInitialized) {
      _soloud.stop(handle);
    }
  }

  Future<void> playMusic(String theme) async {
    final asset = switch (theme) {
      'menu' => 'music_menu.mp3',
      'floodworks' => 'music_breach.wav',
      'relayGraveyard' => 'music_foundry.wav',
      _ => 'music_$theme.wav',
    };
    if (_music == asset && _musicHandle != null) return;
    _music = asset;
    final request = ++_musicRequest;
    try {
      if (!_soloud.isInitialized) return;
      final source = await _source(asset);
      if (request != _musicRequest || !_soloud.isInitialized) return;
      final old = _musicHandle;
      _musicHandle = _soloud.play(
        source,
        volume: _musicVolume * 0.25,
        looping: true,
      );
      if (old != null) await _soloud.stop(old);
    } catch (error) {
      if (_reportedFailures.add(asset)) {
        Logger('audio').warning('Music unavailable: $error');
      }
    }
  }

  void pauseMusic(bool paused) {
    try {
      if (_soloud.isInitialized && _musicHandle != null) {
        _soloud.setPause(_musicHandle!, paused);
      }
    } on Object {
      _musicHandle = null;
    }
  }
}

final soloudPlayProvider = Provider<SoloudPlay>((ref) => SoloudPlay());
