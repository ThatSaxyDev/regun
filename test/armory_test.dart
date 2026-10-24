import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/account/account_session.dart';
import 'package:regun/models/economy/armory_catalog.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/base_view.dart';
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

class IntentStore extends AccountLocalStore {
  IntentStore(Directory directory) : super(directory: directory);
  bool failIntent = true;
  @override
  Future<void> write(String owner, Map<String, dynamic> data) async {
    if (failIntent && data['purchase'] != null) {
      throw const FileSystemException('full disk');
    }
    await super.write(owner, data);
  }
}

Map<String, dynamic> catalog() => {
  ...ArmoryCatalog.bundled.toJson(),
  'enabled': true,
  'version': 'scrap-armory-r1',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Dart prices, milestones and names match the shared Armory fixture', () {
    final raw =
        jsonDecode(File('test/fixtures/armory.json').readAsStringSync()) as Map;
    expect(raw.keys.toSet(), armoryWeapons.keys.toSet());
    for (final e in armoryWeapons.entries) {
      expect(raw[e.key], {
        'title': e.value.title,
        'bosses': e.value.bosses,
        'price': e.value.price,
      });
      expect(
        WeaponType.values.byName(e.key).victoryRequirement,
        e.value.bosses,
      );
    }
  });
  test('six prices and boss milestones match the approved8000–15000 range', () {
    expect(armoryWeapons.length, 6);
    expect(armoryWeapons['beltRepeater']!.price, 10000);
    expect(armoryWeapons['mourningBell']!.price, 15000);
    expect(armoryWeapons['longwatchSniper']!.price, 8500);
    for (final bad in [7999, 15001, 8500.5, '8500']) {
      final raw = catalog();
      raw['prices'] = {...raw['prices'] as Map, 'longwatchSniper': bad};
      expect(() => ArmoryCatalog.fromJson(raw), throwsFormatException);
    }
  });
  test('new profiles earn blueprint flags without automatically owning Scrap weapons', () {
    final p = PlayerProfile(
      totalBossVictories: 100,
      challenges: {'training', 'revolver', 'arcCaster', 'burstRifle'},
    );
    for (final w in WeaponType.values) {
      expect(
        p.weaponUnlocked(w),
        !armoryWeapons.containsKey(w.name),
        reason: w.name,
      );
    }
    p.challenges.addAll(armoryWeapons.keys);
    expect(p.weaponUnlocked(WeaponType.beltRepeater), isFalse);
    p.ownedWeapons.add('beltRepeater');
    expect(p.weaponUnlocked(WeaponType.beltRepeater), isTrue);
  });
  test('old gameplay grants and old ownership caches do not migrate into purchase access', () {
    for (final version in [null, 1]) {
      final legacy = PlayerProfile(
        totalBossVictories: 100,
        challenges: {'beltRepeater', 'breachHammer'},
        ownedWeapons: armoryWeapons.keys.toSet(),
      ).toJson();
      if (version == null) {
        legacy.remove('weaponAccessVersion');
      } else {
        legacy['weaponAccessVersion'] = version;
      }
      final migrated = PlayerProfile.fromJson(legacy);
      expect(migrated.ownedWeapons, isEmpty);
      expect(migrated.legacyWeaponClaims, isEmpty);
      expect(migrated.totalBossVictories, 100);
      expect(migrated.weaponUnlocked(WeaponType.longwatchSniper), isFalse);
      expect(migrated.toJson()['weaponAccessVersion'], 2);
    }
    final paid = PlayerProfile(ownedWeapons: {'beltRepeater'});
    expect(
      PlayerProfile.fromJson(paid.toJson())
          .weaponUnlocked(WeaponType.beltRepeater),
      isTrue,
    );
  });
  test('one cloud sync replaces a v1 free-grant cache with purchase-only ownership without a conflict', () async {
    final dir = await Directory.systemTemp.createTemp('regun-access-v2');
    final prefs = LocalPreferences();
    await prefs.activateProfile(owner);
    final store = AccountLocalStore(directory: dir);
    final old = PlayerProfile(
      totalBossVictories: 52,
      challenges: armoryWeapons.keys.toSet(),
      ownedWeapons: armoryWeapons.keys.toSet(),
    ).toJson()..['weaponAccessVersion'] = 1;
    await store.write(owner, {
      'profile': old,
      'revision': '1',
      'epoch': '0',
      'pending': false,
      'operation': 'seed',
    });
    var mutations = 0;
    final account = AccountController(
      preferences: prefs,
      store: store,
      secrets: Secrets(),
      retryDelays: const [],
      api: AccountApi(
        endpoint: Uri.parse('https://account.test'),
        client: () => MockClient((r) async {
          if (r.method != 'GET') mutations++;
          return http.Response(
            jsonEncode({
              'accountId': owner,
              'username': 'rook',
              'armory': catalog(),
              'cloud': {
                'revision': '1',
                'epoch': '0',
                'payload': {
                  ...old,
                  'weaponAccessVersion': 2,
                  'ownedWeapons': ['longwatchSniper'],
                  'legacyWeaponClaims': [],
                },
              },
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(() async {
      account.dispose();
      await store.read(owner);
      await dir.delete(recursive: true);
    });
    await account.initialize();
    expect(prefs.profile.ownedWeapons, isEmpty);
    await account.sync();
    expect(account.conflict, isFalse);
    expect(mutations, 0);
    expect(prefs.profile.ownedWeapons, {'longwatchSniper'});
    expect(prefs.profile.weaponUnlocked(WeaponType.beltRepeater), isFalse);
    expect(
      PlayerProfile.fromJson((await store.read(owner))!['profile'])
          .ownedWeapons,
      {'longwatchSniper'},
    );
  });
  test('lost weapon purchase reply recovers once under the loadout lease; owned gun works offline', () async {
    final dir = await Directory.systemTemp.createTemp('regun-armory');
    final prefs = LocalPreferences();
    await prefs.activateProfile(owner);
    final secrets = Secrets(), store = AccountLocalStore(directory: dir);
    final p = PlayerProfile(scrap: 10000, totalBossVictories: 5).toJson();
    await store.write(owner, {
      'profile': p,
      'revision': '1',
      'epoch': '0',
      'pending': false,
      'operation': 'seed',
    });
    var paid = false, online = true, purchases = 0;
    String? operation;
    Map<String, dynamic> status() => {
      'accountId': owner,
      'username': 'rook',
      'requiresRename': false,
      'armory': catalog(),
      'cloud': {
        'revision': paid ? '2' : '1',
        'epoch': '0',
        'payload': {
          ...p,
          'scrap': paid ? 0 : 10000,
          'ownedWeapons': paid ? ['beltRepeater'] : [],
        },
      },
    };
    final account = AccountController(
      preferences: prefs,
      secrets: secrets,
      store: store,
      retryDelays: const [],
      api: AccountApi(
        endpoint: Uri.parse('https://account.test'),
        client: () => MockClient((r) async {
          if (!online) throw const SocketException('offline');
          if (r.url.path == '/weapon-purchase') {
            purchases++;
            operation = jsonDecode(r.body)['operation'];
            paid = true;
            throw const SocketException('lost debit response');
          }
          if (r.url.path == '/weapon-purchase-status') {
            return http.Response(
              jsonEncode({
                ...status(),
                'purchaseOperation': operation,
                'purchaseReceipt': {
                  'item': 'beltRepeater',
                  'catalog': 'scrap-armory-r1',
                  'epoch': '0',
                  'price': 10000,
                },
              }),
              200,
            );
          }
          return http.Response(jsonEncode(status()), 200);
        }),
      ),
    );
    addTearDown(() async {
      account.endLocalPlay();
      account.dispose();
      await store.read(owner);
      await dir.delete(recursive: true);
    });
    await account.initialize();
    await account.beginLocalPlay();
    await Future.wait([
      account.purchaseWeapon(
        'beltRepeater',
        displayedPrice: 10000,
        displayedCatalog: 'scrap-armory-r1',
      ),
      account.purchaseWeapon(
        'beltRepeater',
        displayedPrice: 10000,
        displayedCatalog: 'scrap-armory-r1',
      ),
    ]).timeout(const Duration(seconds: 2));
    expect(purchases, 1);
    expect(account.pendingPurchaseItem, 'beltRepeater');
    expect(prefs.profile.weaponUnlocked(WeaponType.beltRepeater), isFalse);
    await account.sync();
    expect(purchases, 1);
    expect(account.pendingPurchaseItem, isNull);
    expect(prefs.profile.scrap, 0);
    expect(prefs.profile.weaponUnlocked(WeaponType.beltRepeater), isTrue);
    online = false;
    await account.sync();
    expect(prefs.profile.weaponUnlocked(WeaponType.beltRepeater), isTrue);
    expect(
      PlayerProfile.fromJson((await store.read(owner))!['profile'])
          .weaponUnlocked(WeaponType.beltRepeater),
      isTrue,
    );
  });
  test('guest/offline and failed durable intent never spend; retry and cancel respect the Loadout lease', () async {
    final dir = await Directory.systemTemp.createTemp('regun-armory-intent');
    final prefs = LocalPreferences();
    await prefs.activateProfile(owner);
    final store = IntentStore(dir);
    final profile = PlayerProfile(scrap: 10000, totalBossVictories: 5).toJson();
    await store.write(owner, {
      'profile': profile,
      'revision': '1',
      'epoch': '0',
      'pending': false,
      'operation': 'seed',
    });
    var online = false, paid = false, calls = 0;
    String? operation;
    final cancelled = <String>{};
    Map<String, dynamic> status() => {
      'accountId': owner,
      'username': 'rook',
      'armory': catalog(),
      'cloud': {
        'revision': paid ? '2' : '1',
        'epoch': '0',
        'payload': {
          ...profile,
          'scrap': paid ? 0 : 10000,
          'ownedWeapons': paid ? ['beltRepeater'] : [],
        },
      },
    };
    final account = AccountController(
      preferences: prefs,
      secrets: Secrets(),
      store: store,
      retryDelays: const [],
      api: AccountApi(
        endpoint: Uri.parse('https://account.test'),
        client: () => MockClient((r) async {
          if (!online) throw const SocketException('offline');
          final body = r.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(r.body) as Map;
          if (r.url.path == '/weapon-purchase') {
            calls++;
            operation = body['operation'];
            paid = true;
          }
          if (r.url.path == '/weapon-purchase-cancel') {
            cancelled.add(body['operation']);
          }
          return http.Response(
            jsonEncode({
              ...status(),
              if (r.url.path.contains('weapon-purchase')) ...{
                'purchaseOperation': body['operation'],
                'purchaseCancelled': cancelled.contains(body['operation']),
                'purchaseReceipt': paid && body['operation'] == operation
                    ? {
                        'item': 'beltRepeater',
                        'price': 10000,
                        'catalog': 'scrap-armory-r1',
                        'epoch': '0',
                      }
                    : null,
              },
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(() async {
      account.endLocalPlay();
      account.dispose();
      await store.read(owner);
      await dir.delete(recursive: true);
    });
    Future<CosmeticPurchase> buy() => account.purchaseWeapon(
      'beltRepeater',
      displayedPrice: 10000,
      displayedCatalog: 'scrap-armory-r1',
    );
    expect(await buy(), CosmeticPurchase.signInRequired);
    await account.initialize();
    await account.beginLocalPlay();
    await buy();
    expect(calls, 0);
    expect(prefs.profile.scrap, 10000);
    online = true;
    await buy();
    expect(calls, 0); // Failed journal cannot send the debit.
    store.failIntent = false;
    await account.cancelPendingPurchase().timeout(const Duration(seconds: 2));
    expect(calls, 0);
    expect(account.pendingPurchaseItem, isNull);
    expect(await buy(), CosmeticPurchase.saved);
    expect(calls, 1);
    expect(prefs.profile.scrap, 0);
    expect(prefs.profile.weaponUnlocked(WeaponType.beltRepeater), isTrue);
  });
  testWidgets(
    'direct and old Continue routes cannot admit an unpurchased Repeater',
    (tester) async {
      await LocalPreferences.shared.load();
      LocalPreferences.shared.profile = PlayerProfile(
        totalBossVictories: 100,
        scrap: 10000,
      );
      for (final snapshot in [
        null,
        <String, dynamic>{},
        {'weaponAccessVersion': 1},
        {'weaponAccessVersion': 2},
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BaseView(
                key: UniqueKey(),
                loadout: const Loadout(weapon: WeaponType.beltRepeater),
                resumeSnapshot: snapshot,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('WEAPON LOCKED'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
