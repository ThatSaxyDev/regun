import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/utils/soloud_play.dart';

/// Runs on a native device: tests the real decoder/mixer, not mocked play calls.
/// Mixer output cannot prove speaker routing or subjective listening quality.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled music and every weapon produce native mixed audio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Checking game audio'))),
      ),
    );
    await tester.runAsync(() async {
      final reportFile = File(
        '${(await getApplicationDocumentsDirectory()).path}/regun-audio-smoke.json',
      );
      final report = <String, Object?>{
        'status': 'started',
        'rms': <String, double>{},
      };
      Future<void> saveReport() =>
          reportFile.writeAsString(jsonEncode(report), flush: true);
      await saveReport();
      final engine = SoLoud.instance;
      try {
        await engine.init();
        engine.setVisualizationEnabled(false);
        engine.setGlobalVolume(1);
        engine.setMaxActiveVoiceCount(32);
        final audio = SoloudPlay()..configure(music: .6, sfx: .8);

        Future<double> measure(Future<void> Function() play) async {
          var sum = 0.0, count = 0;
          final sub = engine
              .startMixerOutputStream(format: MixerOutputFormat.pcmS16le)
              .listen((chunk) {
                final data = ByteData.sublistView(chunk);
                for (
                  var offset = 0;
                  offset + 1 < data.lengthInBytes;
                  offset += 2
                ) {
                  final sample = data.getInt16(offset, Endian.little) / 32768;
                  sum += sample * sample;
                  count++;
                }
              });
          try {
            await play();
            await Future<void>.delayed(const Duration(milliseconds: 650));
          } finally {
            engine.stopMixerOutputStream();
            await sub.cancel();
            engine.stopAll();
          }
          expect(
            count,
            greaterThan(1000),
            reason: 'Native audio callback stopped',
          );
          return sqrt(sum / count);
        }

        try {
          final music = await measure(() => audio.playMusic('menu'));
          (report['rms'] as Map<String, double>)['menu'] = music;
          await saveReport();
          expect(music, greaterThan(.001), reason: 'Menu music is silent');
          for (final weapon in WeaponType.values) {
            await audio.warmCombat(weapon);
            final level = await measure(() async {
              await audio.play('shot_${weapon.name}_0.wav');
              await Future<void>.delayed(const Duration(milliseconds: 120));
              await audio.play('impact_${weapon.name}.wav');
            });
            expect(
              level,
              greaterThan(.005),
              reason: '${weapon.name} is silent',
            );
            (report['rms'] as Map<String, double>)[weapon.name] = level;
            await saveReport();
            debugPrint('NATIVE_AUDIO ${weapon.name} rms=$level');
          }
          audio.configure(music: 0, sfx: 0);
          final muted = await measure(() => audio.play('shot_shotgun_0.wav'));
          expect(muted, lessThan(.0001), reason: 'SFX mute is ignored');
          (report['rms'] as Map<String, double>)['muted'] = muted;
          report['status'] = 'passed';
          await saveReport();
          debugPrint('NATIVE_AUDIO menu rms=$music; mute rms=$muted');
        } finally {
          engine.deinit();
        }
      } catch (error) {
        report['status'] = 'failed';
        report['error'] = error.toString();
        await saveReport();
        rethrow;
      }
    });
    expect(tester.takeException(), isNull);
  });
}
