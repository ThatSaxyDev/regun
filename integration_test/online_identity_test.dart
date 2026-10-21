import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/multiplayer/secure_online_tokens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native secure guest identity survives a new store instance without touching live identity',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Checking secure identity storage…')),
        ),
      );
      await tester.runAsync(() async {
        const key = 'regun.integration.identity.storage';
        const first = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );
        const second = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );
        final value = 'test-${DateTime.now().microsecondsSinceEpoch}';
        await first.write(key: key, value: value);
        expect(await second.read(key: key), value);
        await second.delete(key: key);
        expect(await first.read(key: key), isNull);
        expect(SecureOnlineTokens.key, contains('regun.online.'));
        await File(
          '${(await getApplicationDocumentsDirectory()).path}/regun-online-identity.json',
        ).writeAsString(
          jsonEncode({
            'status': 'passed',
            'platform': Platform.operatingSystem,
            'checks': [
              'native-secure-write-read-delete',
              'endpoint-specific-key',
            ],
            'at': DateTime.now().toUtc().toIso8601String(),
          }),
          flush: true,
        );
      });
    },
  );
}
