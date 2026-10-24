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
        'hurt_player.wav',
        'blast.wav',
        'upgrade_pulse.wav',
        'grenade_throw.wav',
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
          : assetPath == 'upgrade_pulse.wav'
          ? 120
          : assetPath == 'blast.wav'
          ? 120
          : assetPath == 'enemy3projectile.wav'
          ? 100
          : assetPath.startsWith('impact_')
          ? 65
          : assetPath == 'hit.wav' || assetPath.startsWith('coin')
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
            : assetPath == 'upgrade_pulse.wav'
            ? .35
            : assetPath == 'blast.wav'
            ? .65
            : assetPath == 'grenade_throw.wav'
            ? .3
            : assetPath == 'supply_land.wav'
            ? .8
            : assetPath.startsWith('supply_charge_')
            ? .16
            : assetPath.startsWith('supply_')
            ? .4
            : assetPath == 'enemy3projectile.wav'
            ? .30
            : assetPath.startsWith('shot_')
            ? .72
            : assetPath == 'impact_arcCaster.wav'
            ? .45
            : assetPath.startsWith('impact_boss')
            ? .6
            : assetPath.startsWith('impact_')
            ? .25
            : assetPath.startsWith('reload_')
            ? .32
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
    final asset = theme == 'menu' ? 'music_menu.mp3' : 'music_$theme.wav';
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
