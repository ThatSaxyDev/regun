import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/ui/damage_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('solo hit tint is transparent in the center, subtle at edges and softer in Reduced Motion', () async {
    Future<List<int>> rgba(bool reduced, double strength) async {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xff202020), BlendMode.src);
      DamageFeedback.paintScreenTint(
        canvas,
        const Size(300, 150),
        strength,
        reducedMotion: reduced,
      );
      final picture = recorder.endRecording(),
          image = await picture.toImage(300, 150);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List().toList();
    }

    final full = await rgba(false, 1),
        reduced = await rgba(true, 1),
        faded = await rgba(false, 0);
    const center = (75 * 300 + 150) * 4;
    expect(full.sublist(center, center + 4), [32, 32, 32, 255]);
    expect(full[0], greaterThan(32));
    expect(full[0], lessThan(65));
    expect(reduced[0], lessThan(full[0]));
    expect(faded[0], 32);
  });
}
