import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/animation_playback.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all survivor run loops advance without restarting on facing changes',
      () async {
    await RegunArt.shared.load();
    for (final survivor in CharacterType.values) {
      final facings = [
        for (var f = 0; f < 4; f++)
          RegunArt.shared.survivorRun(survivor.name, facing: f)
      ];
      final component = SpriteAnimationComponent(
          animation: facings.first, size: Vector2.all(100));
      final step = facings.first.frames.first.stepTime;
      component.update(step * 3.25);
      final startingPhase = component.animationTicker!.elapsed;
      expect(component.animationTicker!.currentIndex, 3);
      for (final next in [...facings.skip(1), facings.first]) {
        switchLoopFacing(component, next);
        expect(component.animationTicker!.currentIndex, 3);
        expect(component.animationTicker!.elapsed,
            closeTo(startingPhase, .000001));
      }
      component.update(step * .9);
      expect(component.animationTicker!.currentIndex, 4);
      component.update(step * 3.7);
      expect(component.animationTicker!.currentIndex, 7);
      component.update(step * .2);
      expect(component.animationTicker!.currentIndex, 0);
      component.update(step * 8);
      expect(component.animationTicker!.currentIndex, 0);
    }
  });

  test('gameplay full-body run frames have uniform pacing on a 60 Hz loop',
      () async {
    await RegunArt.shared.load();
    final component = SpriteAnimationComponent(
        animation: RegunArt.shared.survivorRun('rook'), size: Vector2.all(100));
    final dwell = <int>[];
    var previous = component.animationTicker!.currentIndex, frames = 0;
    for (var i = 0; i < 180; i++) {
      component.update(1 / 60);
      frames++;
      final current = component.animationTicker!.currentIndex;
      if (current != previous) {
        expect(current, (previous + 1) % 8);
        dwell.add(frames);
        frames = 0;
        previous = current;
      }
    }
    expect(dwell.length, 36);
    expect(dwell.every((frames) => frames == 5), isTrue,
        reason: 'No accidental long hold or skipped/restarted pose');
  });

  test('render actual complete-sprite movement video frames', () async {
    await RegunArt.shared.load();
    final dir = Directory('build/test-previews/full-body-run');
    await dir.create(recursive: true);
    final tickers = [
      for (final character in CharacterType.values)
        [
          for (var facing = 0; facing < 4; facing++)
            RegunArt.shared
                .survivorRun(character.name, facing: facing)
                .createTicker()
        ]
    ];
    for (var frame = 0; frame < 120; frame++) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xff202429), ui.BlendMode.src);
      for (final character in CharacterType.values) {
        for (var facing = 0; facing < 4; facing++) {
          canvas.save();
          canvas.translate(character.index * 200.0, facing * 180.0);
          final ticker = tickers[character.index][facing];
          ticker
              .getSprite()
              .render(canvas, position: Vector2(15, 0), size: Vector2.all(170));
          canvas.restore();
          ticker.update(1 / 60);
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 720);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${dir.path}/${frame.toString().padLeft(3, '0')}.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  }, skip: !const bool.fromEnvironment('REGUN_ANIMATION_VIDEO'));
}
