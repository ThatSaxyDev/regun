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
  test('HTML 403 preserves status, pending key and truthful failure; Sync only checks the receipt', () async {
    final dir = await Directory.systemTemp.createTemp('regun-purchase-403');
    addTearDown(() => dir.delete(recursive: true));
    final store = AccountLocalStore(directory: dir), secrets = Secrets();
    final profile = PlayerProfile(scrap: 300).toJson();
    var blocked = true, committed = false;
    var purchases = 0, checks = 0;
    String? operation;
    Map<String, dynamic> status() => {
      'accountId': owner,
      'username': 'rook',
      'requiresRename': false,
      'catalog': {'version': 'scrap-cosmetics-1', 'prices': shopCosmetics},
      'cloud': {
        'revision': committed ? '2' : '1',
        'epoch': '0',
        'payload': committed
            ? {
                ...profile,
                'scrap': 200,
                'owned': ['standard', 'copper'],
              }
            : profile,
      },
    };
    final api = AccountApi(
      endpoint: Uri.parse('https://account.example'),
      client: () => MockClient((request) async {
        if (request.url.path == '/purchase') {
          purchases++;
          final body = jsonDecode(request.body) as Map;
          operation ??= body['operation'] as String;
          expect(body['operation'], operation);
          if (blocked) {
            return http.Response(
              '<html>403 Forbidden</html>',
              403,
              headers: {'content-type': 'text/html'},
            );
          }
          committed = true;
          throw const SocketException('lost acknowledgement');
        }
        if (request.url.path == '/purchase-status') {
          checks++;
          expect(jsonDecode(request.body), {'operation': operation});
          return http.Response(
            jsonEncode({
              ...status(),
              'purchaseOperation': operation,
              'purchaseReceipt': committed
                  ? {
                      'item': 'copper',
                      'catalog': 'scrap-cosmetics-1',
                      'epoch': '0',
                    }
                  : null,
            }),
            200,
          );
        }
        return http.Response(jsonEncode(status()), 200);
      }),
    );
    await store.write(owner, {
      'profile': profile,
      'revision': '1',
      'epoch': '0',
      'pending': false,
      'operation': 'initial',
    });
    final preferences = LocalPreferences();
    await preferences.activateProfile(owner);
    final controller = AccountController(
      api: api,
      secrets: secrets,
      store: store,
      preferences: preferences,
    );
    await controller.initialize();
    expect(
      await preferences.buyCosmetic('copper'),
      CosmeticPurchase.onlineRequired,
    );
    expect(controller.issue, contains('403'));
    expect(controller.saveLabel, 'Purchase blocked · retry in Collection');
    expect(preferences.profile.scrap, 300);
    expect(preferences.profile.owned.contains('copper'), isFalse);
    expect((await store.read(owner))!['purchase']['operation'], operation);
    await controller.sync();
    expect(checks, 1);
    expect(purchases, 1);
    expect(
      controller.saveLabel,
      'Purchase not completed · retry in Collection',
    );
    blocked = false;
    expect(
      await preferences.buyCosmetic('copper'),
      CosmeticPurchase.onlineRequired,
    );
    expect(purchases, 2);
    expect(preferences.profile.scrap, 300);
    await controller.sync();
    expect(purchases, 2);
    expect(checks, 2); // Receipt lookup does not resubmit buying.
    expect(preferences.profile.scrap, 200);
    expect(preferences.profile.owned.contains('copper'), isTrue);
    expect((await store.read(owner))!['purchase'], isNull);
    expect(controller.saveLabel, 'Saved to cloud');
    controller.dispose();
  });

  test(
    'non-JSON HTTP errors retain status while malformed success is uncertain',
    () async {
      for (final code in [401, 403, 404, 502]) {
        final api = AccountApi(
          endpoint: Uri.parse('https://account.example'),
          client: () =>
              MockClient((_) async => http.Response('upstream HTML', code)),
        );
        await expectLater(
          api.request('/purchase', body: {}),
          throwsA(isA<AccountError>().having((e) => e.status, 'status', code)),
        );
      }
      final api = AccountApi(
        endpoint: Uri.parse('https://account.example'),
        client: () =>
            MockClient((_) async => http.Response('not valid JSON', 200)),
      );
      await expectLater(
        api.request('/purchase', body: {}),
        throwsA(isA<AccountError>().having((e) => e.status, 'status', 0)),
      );
    },
  );

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
