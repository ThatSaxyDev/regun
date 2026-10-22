import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/multiplayer/secure_online_tokens.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:spacetimedb/spacetimedb.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'stored native identity and real arena preparation connect to hosted service',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Checking online connection…')),
        ),
      );
      await tester.runAsync(() async {
        final store = SecureOnlineTokens();
        final hasStoredIdentity = await store.loadToken() != null;
        OnlineSession.prepareAssets = () => RegunArt.shared.load();
        final session = OnlineSession(tokens: store);
        try {
          await session.connect();
          final report = {
            'connected': session.connected,
            'storedIdentity': hasStoredIdentity,
            'stage': session.connectionDiagnostic,
            'status': session.status,
            'message': session.error,
          };
          await File(
            '${(await getApplicationDocumentsDirectory()).path}/regun-connection-diagnostic.json',
          ).writeAsString(jsonEncode(report), flush: true);
          // Safe categories only: credentials and raw transport exceptions stay private.
          debugPrint('REGUN_CONNECTION_DIAGNOSTIC ${jsonEncode(report)}');
          expect(
            session.connected || session.guestRejected,
            isTrue,
            reason: '${session.connectionDiagnostic}: ${session.error}',
          );
          if (session.guestRejected) expect(session.retryScheduled, isFalse);
        } finally {
          await session.close();
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  testWidgets(
    'explicit invalid-guest recovery connects natively without replacing saved identity',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Checking guest recovery…')),
        ),
      );
      await tester.runAsync(() async {
        final temporary = InMemoryTokenStore();
        await temporary.saveToken('invalid-credential-for-recovery-test');
        OnlineSession.prepareAssets = () => RegunArt.shared.load();
        final session = OnlineSession(tokens: temporary);
        try {
          await session.connect();
          expect(session.guestRejected, isTrue);
          expect(session.retryScheduled, isFalse);
          await session.recoverGuest();
          expect(
            session.connected,
            isTrue,
            reason: session.connectionDiagnostic,
          );
          expect(session.guestRejected, isFalse);
          await session.suspend();
          await session.resume();
          expect(
            session.connected,
            isTrue,
            reason: session.connectionDiagnostic,
          );
          debugPrint(
            'REGUN_CONNECTION_RECOVERY passed: new guest, subscriptions and stored-token reconnect',
          );
        } finally {
          await session.close();
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
