import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/services/run_store.dart';

void main() {
  late Directory directory;
  late RunStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('regun-checkpoint-test-');
    store = RunStore(directory: directory);
  });
  tearDown(() async => directory.delete(recursive: true));
  Map<String, dynamic> snapshot(int marker) => {
    'schema': 1,
    'state': {'marker': marker},
    'player': [0, 0],
    'enemies': [],
    'drops': [],
  };

  test(
    'writes and clear serialize; a settled run cannot reappear from backup',
    () async {
      final first = store.write(snapshot(1));
      final second = store.write(snapshot(2));
      final clear = store.clear();
      await Future.wait([first, second, clear]);
      expect(await store.read(), isNull);
      await store.write(snapshot(3));
      expect((await store.read())!['state']['marker'], 3);
    },
  );

  test(
    'critical recovery replaces the backup before a purchase or resume',
    () async {
      await store.write(snapshot(1));
      expect(await store.writeRecovery(snapshot(2)), isTrue);
      await File('${directory.path}/regun-run-v1.json').writeAsString('broken');
      expect((await store.read())!['state']['marker'], 2);
    },
  );

  test('background save cannot interleave the two critical copies', () async {
    await store.write(snapshot(1));
    final critical = store.writeRecovery(snapshot(2));
    final background = store.write(snapshot(3));
    expect(await critical, isTrue);
    expect(await background, isTrue);
    expect((await store.read())!['state']['marker'], 3);
    await File('${directory.path}/regun-run-v1.json').writeAsString('broken');
    expect((await store.read())!['state']['marker'], 2);
  });

  test('corrupt primary recovers the last completed backup', () async {
    await store.write(snapshot(1));
    await store.write(snapshot(2));
    await File('${directory.path}/regun-run-v1.json').writeAsString('broken');
    expect((await store.read())!['state']['marker'], 1);
  });
  test('settling an older run preserves a newer run checkpoint', () async {
    await store.write({...snapshot(1), 'id': 'old'});
    await store.write({...snapshot(2), 'id': 'new'});
    await store.clear(expectedRunId: 'old');
    expect((await store.read())!['id'], 'new');
  });

  test('semantically invalid primary uses the valid backup', () async {
    await store.write(snapshot(1));
    await store.write(snapshot(2));
    final recovered = await store.read(
      validate: (data) => data['state']['marker'] == 1,
    );
    expect(recovered!['state']['marker'], 1);
  });
}
