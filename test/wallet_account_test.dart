import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regun/models/account/account_session.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owner = '11111111-1111-4111-8111-111111111111';

class Secrets implements AccountSecrets {
  String? value = jsonEncode(
    const AccountSession(
      accountId: owner,
      accessToken: 'jwt',
      refreshToken: 'refresh',
      expiresAt: 4102444800,
    ).toJson(),
  );
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    value = v;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('online purchase persists ownership; restart and offline mode retain it; lost responses reuse receipt', () async {
    final dir = await Directory.systemTemp.createTemp('regun-wallet');
    addTearDown(() => dir.delete(recursive: true));
    final store = AccountLocalStore(directory: dir);
    final secrets = Secrets();
    var serverProfile = PlayerProfile(
      scrap: 300,
      owned: {'standard', 'ivory'},
    ).toJson();
    var revision = 1;
    var offline = true, loseAcknowledgement = false;
    final operations = <String>[];
    final receipts = <String>{};
    var calls = 0;
    Map<String, dynamic> status() => {
      'accountId': owner,
      'username': 'rook',
      'requiresRename': false,
      'catalog': {'version': 'scrap-cosmetics-1', 'prices': shopCosmetics},
      'cloud': {
        'revision': '$revision',
        'epoch': '0',
        'payload': serverProfile,
      },
    };
    final api = AccountApi(
      endpoint: Uri.parse('https://account.example'),
      client: () => MockClient((request) async {
        calls++;
        if (offline) throw const SocketException('offline');
        expect(request.headers['Authorization'], 'Bearer jwt');
        if (request.url.path == '/purchase') {
          final body = jsonDecode(request.body) as Map;
          expect(body.keys.toSet(), {
            'item',
            'catalog',
            'revision',
            'epoch',
            'operation',
          });
          operations.add(body['operation'] as String);
          if (receipts.add(body['operation'] as String)) {
            final profile = PlayerProfile.fromJson(serverProfile);
            profile.scrap -= shopCosmetics[body['item']]!;
            profile.owned.add(body['item'] as String);
            serverProfile = profile.toJson();
            revision++;
          }
          if (loseAcknowledgement) {
            loseAcknowledgement = false;
            throw const SocketException('response lost after commit');
          }
        }
        return http.Response(jsonEncode(status()), 200);
      }),
    );
    await store.write(owner, {
      'owner': owner,
      'profile': serverProfile,
      'revision': '1',
      'epoch': '0',
      'pending': false,
      'operation': 'initial',
    });
    Future<(AccountController, LocalPreferences)> boot() async {
      final preferences = LocalPreferences();
      await preferences.activateProfile(owner);
      final controller = AccountController(
        api: api,
        secrets: secrets,
        store: store,
        preferences: preferences,
      );
      await controller.initialize();
      return (controller, preferences);
    }

    var (controller, preferences) = await boot();
    expect(preferences.profile.owned.contains('ivory'), isTrue);
    expect(
      await preferences.buyCosmetic('copper'),
      CosmeticPurchase.onlineRequired,
    );
    expect(preferences.profile.scrap, 300);
    expect(preferences.profile.owned.contains('copper'), isFalse);
    offline = false;
    loseAcknowledgement = true;
    expect(
      await preferences.buyCosmetic('copper'),
      CosmeticPurchase.onlineRequired,
    );
    expect(
      serverProfile['scrap'],
      200,
    ); // Server committed; client must reconcile.
    expect(preferences.profile.scrap, 300);
    expect(preferences.profile.owned.contains('copper'), isFalse);
    controller.dispose();
    (controller, preferences) = await boot();
    expect(await preferences.buyCosmetic('copper'), CosmeticPurchase.saved);
    expect(operations.length, 2);
    expect(operations[0], operations[1]);
    expect(preferences.profile.scrap, 200);
    expect(preferences.profile.owned, containsAll(['ivory', 'copper']));
    controller.dispose();
    offline = true;
    final callsBeforeBoot = calls;
    (controller, preferences) = await boot();
    expect(
      calls,
      callsBeforeBoot,
    ); // Cached ownership needs no startup request.
    expect(preferences.profile.owned, containsAll(['ivory', 'copper']));
    preferences.profile.cosmetic = 'ivory';
    expect(await preferences.saveProfile(), isTrue);
    expect(preferences.profile.cosmetic, 'ivory');
    expect(
      await preferences.buyCosmetic('moss'),
      CosmeticPurchase.onlineRequired,
    );
    expect(preferences.profile.scrap, 200);
    expect(preferences.profile.owned.contains('moss'), isFalse);
    controller.dispose();
  });
}
