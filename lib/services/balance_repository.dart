import 'package:flutter/foundation.dart' show compute;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/live_balance.dart';

/// Best-effort delivery. Callers read [current] synchronously; never await refresh
/// to start, resume or continue a game. Running games retain their own snapshot.
class BalanceRepository {
  BalanceRepository({http.Client Function()? client, Uri? endpoint})
    : client = client ?? http.Client.new,
      endpoint =
          endpoint ??
          Uri.tryParse(
            const String.fromEnvironment(
              'REGUN_BALANCE_URL',
              defaultValue: String.fromEnvironment(
                'REGUN_IDENTITY_URL',
                defaultValue: 'https://regunserver.kiishi.space',
              ),
            ),
          );
  static final shared = BalanceRepository();
  final http.Client Function() client;
  final Uri? endpoint;
  LiveBalance current = LiveBalance.bundled;
  Future<void>? _pending;
  DateTime? _lastAttempt;
  static const key = 'regun.balance.production.v1';
  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final cached = await compute(decodeBalance, raw);
        if (cached.revision >= current.revision) current = cached;
      }
    } catch (_) {
      /* New runs retain bundled defaults; checkpoints are self-contained. */
    }
    await refresh();
  }

  Future<void> refresh({bool force = false}) {
    if (_pending != null) return _pending!;
    if (!force &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(minutes: 2)) {
      return Future.value();
    }
    return _pending = _fetch().whenComplete(() => _pending = null);
  }

  Future<void> _fetch() async {
    final base = endpoint;
    if (base == null ||
        base.userInfo.isNotEmpty ||
        !(base.scheme == 'https' ||
            (base.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(base.host)))) {
      return;
    }
    _lastAttempt = DateTime.now();
    final transport = client();
    try {
      final request = http.Request(
        'GET',
        base.resolve('/balance/v1/current?channel=production'),
      )..headers['If-None-Match'] = '"${current.revision}-${current.hash}"';
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return;
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 4),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 131072) {
          throw const FormatException('Oversized balance');
        }
      }
      final next = await compute(decodeBalance, utf8.decode(bytes));
      if (next.revision < current.revision) return;
      final prefs = await SharedPreferences.getInstance();
      if (await prefs.setString(key, jsonEncode(next.toJson()))) current = next;
    } catch (_) {
      /* No service failure can affect offline input, start or rewards. */
    } finally {
      transport.close();
    }
  }
}

LiveBalance decodeBalance(String source) =>
    LiveBalance.fromJson(jsonDecode(source));
