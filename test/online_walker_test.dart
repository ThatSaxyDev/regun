import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/online_walker.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('online Walker renders authoritative mechanical snapshots without running client combat', () async {
    final rows = jsonDecode(
      File('test/fixtures/walker-hosted-v1.json').readAsStringSync(),
    ) as List;
    final cache = OnlineWalkers(() {});
    OnlineEntity entity(Map state) => OnlineEntity('boss', 'enemy', {
      'kind': 'walker',
      'boss': true,
      'walker': state,
      'x': state['rig']['position'][0],
      'y': state['rig']['position'][1],
    });
    final state = Map<String, dynamic>.from(rows[2]['state'] as Map);
    cache.sync([entity(state)], 1 / 60, active: true, scope: 'room:match');
    for (var i = 0; i < 150 && !cache.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cache.ready, isTrue);
    expect(
      cache.decodedBytes + RegunArt.shared.decodedBytes,
      lessThanOrEqualTo(32 * 1024 * 1024),
    );
    final count = cache.frames['boss']!.shots,
        clock = cache.frames['boss']!.clock;
    for (var i = 0; i < 120; i++) {
      cache.sync([entity(state)], 1 / 60, active: true, scope: 'room:match');
    }
    expect(cache.frames['boss']!.shots, count);
    expect(cache.frames['boss']!.clock, clock);
    final rec = PictureRecorder(), c = Canvas(rec);
    c.drawColor(const Color(0xff161B18), BlendMode.src);
    c.translate(422, 195);
    c.scale(.7);
    final root = cache.frames['boss']!.rig.position;
    c.translate(-root.dx, -root.dy);
    cache.floor(c, 'boss', ArenaType.breach, false);
    cache.body(c, 'boss', false);
    cache.ordnance(c, ArenaType.breach, false);
    final pic = rec.endRecording(),
        im = await pic.toImage(844, 390),
        bytes = await im.toByteData(format: ImageByteFormat.png);
    Directory('build/walker-online').createSync(recursive: true);
    File('build/walker-online/hosted.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
    pic.dispose();
    cache.sync([], 1 / 60, active: true, scope: 'room:match');
    expect(cache.frames, isEmpty);
    expect(cache.decodedBytes, 0);
    cache.dispose();
  });
  test('pending online art load cannot resurrect a retired route', () async {
    final rows = jsonDecode(
      File('test/fixtures/walker-hosted-v1.json').readAsStringSync(),
    ) as List;
    var changes = 0;
    final cache = OnlineWalkers(() => changes++);
    cache.sync(
      [
        OnlineEntity('boss', 'enemy', {
          'kind': 'walker',
          'walker': rows[0]['state'],
        }),
      ],
      0,
      active: false,
    );
    cache.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(cache.decodedBytes, 0);
    expect(cache.frames, isEmpty);
    expect(changes, 0);
  });
}
