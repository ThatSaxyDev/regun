// ignore_for_file: avoid_print
import 'package:regun/multiplayer/generated/client.dart';
import 'package:spacetimedb/spacetimedb.dart';

/// Anonymous connection/subscriptions only. No rooms or gameplay reducers.
Future<void> main() async {
  SpacetimeDbClient? client;
  try {
    client = await SpacetimeDbClient.connect(
      host: 'regunserver.kiishi.space',
      database: 'regun',
      ssl: true,
      authStorage: InMemoryTokenStore(),
      config: const ConnectionConfig(
        autoReconnect: false,
        connectTimeout: Duration(seconds: 10),
      ),
      subscriptionTimeout: const Duration(seconds: 10),
      initialSubscriptions: [
        'SELECT * FROM my_room',
        'SELECT * FROM room_members',
        'SELECT * FROM my_probe',
        'SELECT * FROM my_motion',
        'SELECT * FROM room_combat',
        'SELECT * FROM room_fighters',
        'SELECT * FROM room_projectiles',
        'SELECT * FROM room_scene',
        'SELECT * FROM my_online_account',
        'SELECT * FROM my_online_results',
      ],
    );
    print('PASS: public TLS WebSocket and scoped subscriptions connected');
  } catch (error) {
    // No credential is supplied by this probe; report the error for diagnosis.
    print('FAIL: ${error.runtimeType}');
  } finally {
    await client?.dispose();
  }
}
