import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/online_lodestar.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rows = <dynamic>[
    ...jsonDecode(
      File('test/fixtures/lodestar-hosted-v1.json').readAsStringSync(),
    ) as List,
    ...jsonDecode(
      File('test/fixtures/lodestar-hosted-v2.json').readAsStringSync(),
    ) as List,
  ];
  OnlineEntity entity(Map raw) => OnlineEntity('boss', 'enemy', {
    'kind': 'lodestar',
    'boss': true,
    'lodestar': raw,
  });
  test('online Lodestar paints server anatomy and ordnance without advancing client combat', () async {
    final cache = OnlineLodestars(() {});
    for (final raw in rows) {
      cache.sync([entity(raw as Map)], scope: 'room:match');
      final f = cache.frames['boss'];
      expect(f, isNotNull);
      expect(f!.phase.name, raw['phase']);
      expect(
        f.rig.poses.map((p) => [p.position.dx, p.position.dy, p.yaw]).toList(),
        raw['rig']['poses'],
      );
      expect(f.shots.length, (raw['shots'] as List).length);
      for (var n = 0; n < 60; n++) {
        cache.sync([entity(raw)], scope: 'room:match');
      }
      expect(cache.frames['boss']!.elapsed, raw['elapsed']);
    }
    for (var n = 0; n < 150 && !cache.ready; n++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cache.ready, isTrue);
    expect(
      cache.decodedBytes + RegunArt.shared.decodedBytes,
      lessThanOrEqualTo(32 * 1024 * 1024),
    );
    final rec = PictureRecorder(), c = Canvas(rec)..translate(750, 350);
    final head = cache.frames['boss']!.rig.poses.first.position;
    c.translate(-head.dx, -head.dy);
    cache.floor(c, 'boss', ArenaType.breach, false);
    cache.body(c, 'boss', false);
    cache.ordnance(c, ArenaType.breach, false);
    final pic = rec.endRecording(),
        im = await pic.toImage(1500, 700),
        bytes = await im.toByteData(format: ImageByteFormat.rawRgba);
    var visible = 0;
    for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) > 50) visible++;
    }
    expect(visible, greaterThan(3000));
    im.dispose();
    pic.dispose();
    cache.sync([], scope: 'room:match');
    expect(cache.frames, isEmpty);
    expect(cache.decodedBytes, 0);
    cache.dispose();
  });
  test(
    'pending online Lodestar load cannot resurrect disposed route',
    () async {
      var changes = 0;
      final cache = OnlineLodestars(() => changes++);
      cache.sync([entity(rows.first as Map)], scope: 'a');
      cache.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(cache.decodedBytes, 0);
      expect(cache.frames, isEmpty);
      expect(changes, 0);
    },
  );
}
