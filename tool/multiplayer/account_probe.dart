// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:regun/multiplayer/generated/client.dart';
import 'package:spacetimedb/spacetimedb.dart';

class _AccountToken implements AuthTokenStore {
  _AccountToken(this.token);
  final String token;
  @override
  Future<String?> loadToken() async => token;
  @override
  Future<void> saveToken(String value) async {}
  @override
  Future<void> clearToken() async {}
}

/// Local disposable identity smoke only. Tokens are read from a private temp file,
/// never command arguments, stdout, diagnostics or packaged assets.
Future<void> main(List<String> args) async {
  SpacetimeDbClient? client;
  try {
    final data = jsonDecode(
      await File(args.single).readAsString(),
    ) as Map<String, dynamic>;
    final host = data['host'] as String;
    if (!host.startsWith('127.0.0.1:')) throw StateError('Local proof only');
    client = await SpacetimeDbClient.connect(
      host: host,
      database: data['database'] as String,
      ssl: false,
      authStorage: _AccountToken(data['token'] as String),
      config: const ConnectionConfig(autoReconnect: false),
      initialSubscriptions: [
        'SELECT * FROM my_room',
        'SELECT * FROM room_members',
      ],
    );
    final result = await client.reducers.createRoom(
      mode: 'coop',
      teamsize: 0,
      mapid: 'breach',
      name: 'spoofed_dart_name',
      protocol: 1,
    );
    if (!result.isSuccess) throw StateError('Room rejected');
    for (var i = 0; i < 50 && client.roomMembers.iter().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (client.roomMembers.iter().single.name != data['username']) {
      throw StateError('Server username mismatch');
    }
    await client.reducers.leaveRoom();
    print(
      'PASS: Flutter Dart SDK signed account admission and authoritative room username',
    );
  } catch (e) {
    print('FAIL: account probe ${e.runtimeType}');
    exitCode = 1;
  } finally {
    await client?.dispose();
  }
}
