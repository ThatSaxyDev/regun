// SDK 1.3.0 codegen consumes the V9 schema shape. Fetch the public named route
// directly: the CLI resolves a database identity, which our gateway blocks.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:spacetimedb/src/codegen/models.dart';
import 'package:spacetimedb/src/codegen/dart_generator.dart';

Future<void> main() async {
  final response = await http.get(
    Uri.parse(
      Platform.environment['REGUN_SCHEMA_URL'] ??
          'https://regunserver.kiishi.space/v1/database/regun/schema?version=9',
    ),
  );
  if (response.statusCode != 200) throw StateError('Schema unavailable');
  final raw = jsonDecode(response.body) as Map<String, dynamic>;
  // Only row shapes required by the three public views, and callable reducers.
  raw['tables'] = (raw['tables'] as List)
      .where(
        (t) => [
          'room',
          'member',
          'fighter',
          'match_combat',
          'projectile',
          'scene',
          'online_account',
          'online_result',
          'motion_state',
        ].contains(t['name']),
      )
      .toList();
  raw['reducers'] = (raw['reducers'] as List)
      .where(
        (r) =>
            (r['lifecycle'] as Map).containsKey('none') && r['name'] != 'tick',
      )
      .toList();
  final schema = DatabaseSchema.fromJson('regun', raw);
  await DartGenerator(schema).writeToDirectory('lib/multiplayer/generated');
  final probe = File('lib/multiplayer/generated/probe_reply.dart');
  await probe.writeAsString(
    (await probe.readAsString()).replaceAll(
      'return null;',
      'return 0; // Identity-scoped singleton view.',
    ),
  );
  final scene = File('lib/multiplayer/generated/scene_view.dart');
  if (scene.existsSync()) {
    await scene.writeAsString(
      (await scene.readAsString()).replaceAll('return null;', 'return row.id;'),
    );
  }
  final client = File('lib/multiplayer/generated/client.dart');
  await client.writeAsString(
    (await client.readAsString()).replaceAll(
      '        rethrow;',
      '        await client.dispose();\n        rethrow;',
    ),
  );
  for (final file in Directory(
    'lib/multiplayer/generated',
  ).listSync().whereType<File>()) {
    await file.writeAsString(
      '// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals\n'
      '${await file.readAsString()}',
    );
  }
}
