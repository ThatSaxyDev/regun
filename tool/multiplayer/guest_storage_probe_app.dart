// Temporary native diagnostic entry point installed in-place. Reads Keychain;
// connects using isolated copies and never replaces or clears the saved guest.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/multiplayer/generated/client.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/multiplayer/secure_online_tokens.dart';
import 'package:regun/multiplayer/guest_token_info.dart';
import 'package:spacetimedb/spacetimedb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Checking saved online guest…'))),
    ),
  );
  final report = <String, Object?>{};
  try {
    final store = SecureOnlineTokens();
    final saved = await store.loadToken();
    final archived = await SecureOnlineTokens.storage.read(
      key: '${SecureOnlineTokens.key}.rejected',
    );
    report['saved'] = GuestTokenInfo(saved).safeReport(DateTime.now());
    report['archived'] = GuestTokenInfo(archived).safeReport(DateTime.now());
    Future<Map<String, Object?>> check(String? token) async {
      if (token == null) return {'skipped': true};
      final copy = InMemoryTokenStore();
      await copy.saveToken(token);
      SpacetimeDbClient? client;
      try {
        client = await SpacetimeDbClient.connect(
          host: OnlineSession.host,
          database: OnlineSession.database,
          ssl: true,
          authStorage: copy,
          config: const ConnectionConfig(
            autoReconnect: false,
            connectTimeout: Duration(seconds: 10),
          ),
          initialSubscriptions: ['SELECT * FROM my_room'],
          subscriptionTimeout: const Duration(seconds: 10),
        );
        return {
          'accepted': true,
          'returnedSameToken': await copy.loadToken() == token,
        };
      } catch (e) {
        return {'accepted': false, 'failureType': '${e.runtimeType}'};
      } finally {
        await client?.dispose();
      }
    }

    report['savedConnection'] = await check(saved);
    report['archivedConnection'] = await check(archived);
    final fresh = InMemoryTokenStore();
    SpacetimeDbClient? c;
    try {
      c = await SpacetimeDbClient.connect(
        host: OnlineSession.host,
        database: OnlineSession.database,
        ssl: true,
        authStorage: fresh,
        config: const ConnectionConfig(
          autoReconnect: false,
          connectTimeout: Duration(seconds: 10),
        ),
        initialSubscriptions: ['SELECT * FROM my_room'],
      );
      final token = await fresh.loadToken();
      report['fresh'] = GuestTokenInfo(token).safeReport(DateTime.now());
      report['sameIssuerAsFresh'] =
          GuestTokenInfo(saved).issuer == GuestTokenInfo(token).issuer;
      report['freshConnected'] = true;
    } catch (e) {
      report['freshConnected'] = false;
      report['freshFailureType'] = '${e.runtimeType}';
    } finally {
      await c?.dispose();
    }
    report['savedUnchanged'] = await store.loadToken() == saved;
  } catch (e) {
    report['failureType'] = '${e.runtimeType}';
  }
  final folder = await getApplicationDocumentsDirectory();
  await File('${folder.path}/regun-guest-probe.json')
      .writeAsString(jsonEncode(report), flush: true);
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Guest check complete.'))),
    ),
  );
}
