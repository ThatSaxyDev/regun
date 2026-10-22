// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:regun/multiplayer/generated/client.dart';
import 'package:spacetimedb/spacetimedb.dart';

Future<void> main() async {
  final store = InMemoryTokenStore();
  SpacetimeDbClient? client;
  try {
    client = await SpacetimeDbClient.connect(
      host: 'regunserver.kiishi.space',
      database: 'regun',
      ssl: true,
      authStorage: store,
      config: const ConnectionConfig(autoReconnect: false),
      initialSubscriptions: ['SELECT * FROM my_room'],
    );
    final token = await store.loadToken();
    if (token == null) throw StateError('No saved credential');
    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    print(
      jsonEncode({
        'stored': true,
        'iat': payload['iat'],
        'exp': payload['exp'],
        'lifetimeSeconds': payload['exp'] is num && payload['iat'] is num
            ? (payload['exp'] as num) - (payload['iat'] as num)
            : null,
        'expired': payload['exp'] is num
            ? (payload['exp'] as num) <= now
            : null,
        'issuerHost': Uri.tryParse('${payload['iss']}')?.host,
      }),
    );
    final identity = client.identity;
    await client.dispose();
    client = null;
    client = await SpacetimeDbClient.connect(
      host: 'regunserver.kiishi.space',
      database: 'regun',
      ssl: true,
      authStorage: store,
      config: const ConnectionConfig(autoReconnect: false),
      initialSubscriptions: ['SELECT * FROM my_room'],
    );
    print(
      jsonEncode({
        'reconnected': true,
        'sameIdentity': client.identity == identity,
      }),
    );
  } catch (e) {
    print(jsonEncode({'errorType': '${e.runtimeType}'}));
  } finally {
    await client?.dispose();
  }
}
