import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
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
  String? value;
  bool failNext = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    if (failNext) {
      failNext = false;
      throw const FileSystemException('disk');
    }
    value = v;
  }
}

Future<void> eventually(bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

class Fixture {
  final preferences = LocalPreferences(), secrets = Secrets();
  late Directory dir;
  late AccountLocalStore store;
  late AccountController account;
  Map<String, dynamic>? remote;
  int revision = 0, calls = 0;
  bool offline = false;
  Future<http.Response?> Function(http.Request)? intercept;
  final saves = <Map<String, dynamic>>[];
  final committed = <String>{};
  Map<String, dynamic> status() => {
    'accountId': owner,
    'username': 'rook',
    'requiresRename': false,
    'cloud': remote == null
        ? null
        : {'revision': '$revision', 'epoch': '0', 'payload': remote},
  };
  Future<void> boot({bool expired = false}) async {
    dir = await Directory.systemTemp.createTemp('regun-sync-recovery');
    addTearDown(() async {
      await account.sync();
      account.dispose();
      await store.read(
        owner,
      ); // Drain queued disk writes before deleting the fixture.
      await dir.delete(recursive: true);
    });
    await preferences.activateProfile(
      owner,
      initial: PlayerProfile(scrap: 120),
    );
    store = AccountLocalStore(directory: dir);
    await store.write(owner, {
      'profile': preferences.profile.toJson(),
      'pending': true,
      'operation': 'original-save',
      'revision': '0',
      'epoch': '0',
    });
    secrets.value = jsonEncode({
      ...AccountSession(
        accountId: owner,
        accessToken: 'old-jwt',
        refreshToken: 'old-refresh',
        expiresAt: expired ? 0 : 4102444800,
      ).toJson(),
      'account': {'username': 'rook', 'accountId': owner},
    });
    await restart();
  }

  Future<void> restart() async {
    account = AccountController(
      preferences: preferences,
      secrets: secrets,
      store: store,
      retryDelays: const [Duration(milliseconds: 30)],
      api: AccountApi(
        endpoint: Uri.parse('https://account.test'),
        client: () => MockClient((request) async {
          calls++;
          final response = await intercept?.call(request);
          if (response != null) return response;
          if (offline) {
            return http.Response('{"message":"Temporary outage"}', 503);
          }
          if (request.url.path == '/save') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            saves.add(body);
            if (committed.add(body['operation'] as String)) {
              expect(body['revision'], '$revision');
              remote = Map<String, dynamic>.from(body['payload'] as Map);
              revision++;
            }
          }
          return http.Response(jsonEncode(status()), 200);
        }),
      ),
    );
    await account.initialize();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'temporary outage retries without Sync now, background pauses retry',
    () async {
      final f = Fixture();
      await f.boot();
      f.offline = true;
      await f.account.sync();
      expect(f.account.pending, isTrue);
      f.account.didChangeAppLifecycleState(AppLifecycleState.paused);
      final calls = f.calls;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(f.calls, calls);
      f.offline = false;
      f.account.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await eventually(() => !f.account.pending);
      expect(f.account.issue, isEmpty);
      expect(f.revision, 1);
    },
  );
  test('foreground retry automatically finishes a transient failure', () async {
    final f = Fixture();
    await f.boot();
    f.offline = true;
    await f.account.sync();
    f.offline = false;
    await eventually(() => !f.account.pending);
    expect(f.revision, 1);
    expect(f.account.conflict, isFalse);
  });
  test('lost save ACK plus newer local play replays old operation then uploads newest', () async {
    final f = Fixture();
    await f.boot();
    var lose = true;
    f.intercept = (r) async {
      if (r.url.path == '/save' && lose) {
        lose = false;
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        f.saves.add(b);
        f.committed.add(b['operation'] as String);
        f.remote = Map<String, dynamic>.from(b['payload'] as Map);
        f.revision++;
        f.preferences.profile.totalKills = 42;
        await f.preferences.saveProfile();
        throw const SocketException('lost response');
      }
      return null;
    };
    await f.account.sync();
    await eventually(() => !f.account.pending);
    expect(f.saves, hasLength(3));
    expect(f.saves[0]['operation'], f.saves[1]['operation']);
    expect(f.saves[2]['operation'], isNot(f.saves[0]['operation']));
    expect(f.remote!['totalKills'], 42);
    expect(f.account.conflict, isFalse);
    expect((await f.store.read(owner))!['upload'], isNull);
  });
  test('refresh ACK loss survives restart and retries the same persisted operation', () async {
    final f = Fixture();
    await f.boot(expired: true);
    final requests = <Map>[];
    f.intercept = (r) async {
      if (r.url.path != '/refresh') return null;
      requests.add(jsonDecode(r.body) as Map);
      if (requests.length == 1) {
        throw const SocketException('lost rotation reply');
      }
      return http.Response(
        jsonEncode(
          const AccountSession(
            accountId: owner,
            accessToken: 'new-jwt',
            refreshToken: 'new-refresh',
            expiresAt: 4102444800,
          ).toJson(),
        ),
        200,
      );
    };
    await f.account.sync();
    expect(
      jsonDecode(f.secrets.value!)['refreshOperation'],
      requests.single['operation'],
    );
    f.account.dispose();
    await f.restart();
    await f.account.sync();
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(f.account.session!.refreshToken, 'new-refresh');
    expect(f.account.pending, isFalse);
    expect(f.account.needsSignIn, isFalse);
  });
  test(
    'secure save failure after rotation retains original retry identity',
    () async {
      final f = Fixture();
      await f.boot(expired: true);
      var attempts = 0;
      final operations = <String>[];
      f.intercept = (r) async {
        if (r.url.path != '/refresh') return null;
        operations.add(jsonDecode(r.body)['operation'] as String);
        if (attempts++ == 0) f.secrets.failNext = true;
        return http.Response(
          jsonEncode(
            const AccountSession(
              accountId: owner,
              accessToken: 'new-jwt',
              refreshToken: 'new-refresh',
              expiresAt: 4102444800,
            ).toJson(),
          ),
          200,
        );
      };
      await f.account.sync();
      expect(f.account.verified, isTrue);
      expect(f.account.session!.refreshToken, 'old-refresh');
      await eventually(() => !f.account.pending);
      expect(operations.toSet(), hasLength(1));
      expect(f.account.session!.refreshToken, 'new-refresh');
    },
  );
  test('revoked session requires reverify, preserves local ownership and stops automatic retries', () async {
    final f = Fixture();
    await f.boot(expired: true);
    f.intercept = (r) async =>
        http.Response('{"message":"Sign in again"}', 401);
    await f.account.sync();
    expect(f.account.needsSignIn, isTrue);
    expect(f.preferences.profileOwner, owner);
    expect(f.preferences.profile.scrap, 120);
    final before = f.calls;
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(f.calls, before);
  });
  test(
    'rejected cached access token renews once without signing out',
    () async {
      final f = Fixture();
      await f.boot();
      var renewals = 0;
      f.intercept = (r) async {
        if (r.url.path == '/account' &&
            r.headers['Authorization'] == 'Bearer old-jwt') {
          return http.Response('{"message":"Sign in again"}', 401);
        }
        if (r.url.path == '/refresh') {
          renewals++;
          return http.Response(
            jsonEncode(
              const AccountSession(
                accountId: owner,
                accessToken: 'new-jwt',
                refreshToken: 'new-refresh',
                expiresAt: 4102444800,
              ).toJson(),
            ),
            200,
          );
        }
        return null;
      };
      await f.account.sync();
      expect(renewals, 1);
      expect(f.account.pending, isFalse);
      expect(f.account.needsSignIn, isFalse);
    },
  );
  test('real other-device progress still requires a choice instead of silent overwrite', () async {
    final f = Fixture();
    await f.boot();
    f.remote = PlayerProfile(totalKills: 999).toJson();
    f.revision = 3;
    await f.account.sync();
    expect(f.account.conflict, isTrue);
    expect(f.saves, isEmpty);
    expect(f.preferences.profile.totalKills, 0);
    final before = f.calls;
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(f.calls, before);
  });
}
