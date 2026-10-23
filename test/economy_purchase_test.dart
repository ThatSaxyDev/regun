import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:regun/services/local_preferences.dart';

import 'wallet_account_test.dart' show Secrets, owner;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final remoteReset in [false, true]) {
    test(
      'quoted purchase cancellation preserves wallet; concurrent reset=$remoteReset',
      () async {
        SharedPreferences.setMockInitialValues({});
        final dir = await Directory.systemTemp.createTemp(
          'regun-economy-quote',
        );
        addTearDown(() => dir.delete(recursive: true));
        final store = AccountLocalStore(directory: dir);
        final profile = PlayerProfile(scrap: 300).toJson();
        var purchases = 0, cancelled = false;
        String? operation;
        Map<String, dynamic> status() => {
          'accountId': owner,
          'username': 'rook',
          'requiresRename': false,
          'catalog': {
            'version': 'scrap-cosmetics-r2',
            'prices': {'copper': 125},
            'available': {'copper': true},
          },
          'cloud': {
            'revision': '1',
            'epoch': cancelled && remoteReset ? '1' : '0',
            'payload': profile,
          },
        };
        final api = AccountApi(
          endpoint: Uri.parse('https://account.test'),
          client: () => MockClient((r) async {
            if (r.url.path == '/purchase') {
              purchases++;
              final body = jsonDecode(r.body) as Map;
              expect(body['catalog'], 'scrap-cosmetics-r2');
              operation = body['operation'] as String;
              throw const SocketException('offline before response');
            }
            if (r.url.path == '/purchase-cancel') {
              expect(jsonDecode(r.body)['operation'], operation);
              cancelled = true;
              return http.Response(
                jsonEncode({
                  ...status(),
                  'purchaseOperation': operation,
                  'purchaseReceipt': null,
                  'purchaseCancelled': true,
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
        final prefs = LocalPreferences();
        await prefs.activateProfile(owner);
        final controller = AccountController(
          api: api,
          secrets: Secrets(),
          store: store,
          preferences: prefs,
        );
        await controller.initialize();
        expect(
          await prefs.buyCosmetic(
            'copper',
            price: 100,
            catalog: 'scrap-cosmetics-1',
          ),
          CosmeticPurchase.unavailable,
        );
        expect(purchases, 0);
        expect(controller.issue, contains('Shop changed'));
        expect(
          await prefs.buyCosmetic(
            'copper',
            price: 125,
            catalog: 'scrap-cosmetics-r2',
          ),
          CosmeticPurchase.onlineRequired,
        );
        expect(purchases, 1);
        expect(controller.pendingPurchaseItem, 'copper');
        await controller.cancelPendingPurchase();
        expect(cancelled, isTrue);
        expect(controller.pendingPurchaseItem, remoteReset ? 'copper' : isNull);
        expect(controller.conflict, remoteReset);
        expect(prefs.profile.scrap, 300);
        expect(prefs.profile.owned.contains('copper'), isFalse);
        expect((await store.read(owner))!.containsKey('purchase'), remoteReset);
        controller.dispose();
      },
    );
  }
}
