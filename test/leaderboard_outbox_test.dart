import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/account/account_session.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/leaderboards.dart';
import 'package:regun/services/player_registry.dart';
import 'package:regun/services/local_preferences.dart';

const owner = '11111111-1111-4111-8111-111111111111';

class ReportRegistry extends PlayerRegistry {
  int reports = 0;
  String? owner;
  @override
  Future<void> record(
    String owner,
    Map<String, dynamic> profile, {
    bool force = false,
    bool active = true,
  }) async {
    reports++;
    this.owner = owner;
  }

  @override
  Future<void> refresh({bool force = false}) async {}
}

class TestBoards extends Leaderboards {
  TestBoards(AccountController account, ReportRegistry registry)
    : super(account: account, registry: registry);
  bool fail = false;
  int sent = 0;
  Completer<void>? held;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    if (path.endsWith('/config')) return {'submissions': true};
    sent++;
    if (held != null) await held!.future;
    if (fail) throw StateError('lost response');
    return {'runId': body!['runId'], 'status': 'accepted'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalPreferences prefs;
  late AccountController account;
  late TestBoards service;
  late ReportRegistry registry;
  late String id;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = LocalPreferences();
    await prefs.load();
    prefs.profileOwner = owner;
    account = AccountController(preferences: prefs)
      ..session = const AccountSession(
        accountId: owner,
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: 9999999999,
      )
      ..account = {'username': 'RookFan'};
    registry = ReportRegistry();
    service = TestBoards(account, registry);
    final summary = jsonDecode(
      File('test/fixtures/run-record-v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    id = summary['runId'];
    prefs.profile.runRecords[id] = {
      'owner': owner,
      'status': 'local',
      'summary': summary,
    };
    prefs.profile.settledRuns.add(id);
  });
  tearDown(() => account.dispose());
  test('stats post automatically without participation; guest ownership is preserved', () async {
    await service.flush();
    expect(registry.reports, 1);
    expect(registry.owner, owner);
    expect(service.sent, 1);
    prefs.profile.runRecords[id]!['owner'] = 'guest';
    prefs.profile.runRecords[id]!['status'] = 'local';
    await service.flush();
    expect(service.sent, 1);
    prefs.profileOwner = 'guest';
    await service.flush();
    expect(registry.owner, 'guest');
    expect(service.sent, 1);
  });
  test(
    'lost response retains the same journal and identity for retry',
    () async {
      service.fail = true;
      await service.flush();
      expect(prefs.profile.runRecords[id]!['status'], 'local');
      expect(service.sent, 1);
      service.fail = false;
      await service.flush();
      expect(service.sent, 2);
      expect(prefs.profile.runRecords[id]!['status'], 'accepted');
      await service.flush();
      expect(service.sent, 2);
    },
  );
  test('switching account during upload cannot apply an old receipt', () async {
    service.held = Completer<void>();
    final pending = service.flush();
    await Future<void>.delayed(Duration.zero);
    expect(service.sent, 1);
    final original = prefs.profile.runRecords[id]!;
    prefs.profileOwner = '22222222-2222-4222-8222-222222222222';
    service.held!.complete();
    await pending;
    expect(original['status'], 'local');
    expect(prefs.profile.runRecords, isEmpty);
  });
  test(
    'summary cannot upload before its settlement shares a durable profile',
    () async {
      prefs.profile.settledRuns.clear();
      await service.flush();
      expect(service.sent, 0);
    },
  );
}
