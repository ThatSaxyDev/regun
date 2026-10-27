import 'package:flutter/foundation.dart' show ValueNotifier;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:regun/services/account/account_controller.dart';

/// Device-reported operational stats, not rewards or competitive authority.
/// All calls are detached from gameplay and keep a bounded durable latest outbox.
abstract interface class RegistrySecrets {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureRegistrySecrets implements RegistrySecrets {
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: 'regun.stats.devices.v1');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'regun.stats.devices.v1', value: value);
}

class PlayerRegistry {
  PlayerRegistry({
    http.Client Function()? client,
    Uri? endpoint,
    RegistrySecrets? secrets,
  }) : _secrets = secrets ?? SecureRegistrySecrets(),
       client = client ?? http.Client.new,
       endpoint =
           endpoint ??
           Uri.tryParse(
             const String.fromEnvironment(
               'REGUN_IDENTITY_URL',
               defaultValue: 'https://regunserver.kiishi.space',
             ),
           );
  static final shared = PlayerRegistry();
  final RegistrySecrets _secrets;
  static const _outboxKey = 'regun.stats.outbox.v1';
  final http.Client Function() client;
  final Uri? endpoint;
  Future<void>? _preparing, _upload;
  Future<void> _queue = Future.value();
  SharedPreferences? _prefs;
  Map<String, dynamic> _devices = {}, _outbox = {};
  DateTime? _lastAttempt;
  bool _credentialsReady = false;
  final guestName = ValueNotifier<String>('Guest');
  String get temporaryName {
    final id = (_devices['guest'] as Map?)?['id'] as String?;
    return id == null
        ? 'Guest'
        : 'Guest-${id.replaceAll('-', '').substring(0, 8)}';
  }

  Future<void> initialize() => _preparing ??= _initialize();
  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = await _secrets.read().timeout(const Duration(seconds: 3));
      if (raw != null) _devices = Map<String, dynamic>.from(jsonDecode(raw));
      final pending = _prefs!.getString(_outboxKey);
      if (pending != null) {
        _outbox = Map<String, dynamic>.from(jsonDecode(pending));
      }
      if (_devices['guest'] == null) {
        final random = Random.secure();
        final secret = base64UrlEncode(
          List<int>.generate(32, (_) => random.nextInt(256)),
        ).replaceAll('=', '');
        _devices['guest'] = {
          'id': const Uuid().v4(),
          'secret': secret,
          'sequence': 0,
        };
        await _secrets
            .write(jsonEncode(_devices))
            .timeout(const Duration(seconds: 3));
      }
      _credentialsReady = true;
      guestName.value = temporaryName;
    } catch (_) {
      /* Stats identity never participates in player admission. */
    }
  }

  Future<void> record(
    String owner,
    Map<String, dynamic> profile, {
    bool force = false,
    bool active = true,
  }) {
    // Capture before queuing so profile transitions cannot reattribute metrics.
    final stats = <String, int>{
      for (final key in [
        'totalKills',
        'totalBossVictories',
        'eliteKills',
        'scorpionKills',
        'bestScore',
        'bestSeconds',
        'scrap',
      ])
        key: (profile[key] is num ? (profile[key] as num).toInt() : 0).clamp(
          0,
          1000000000,
        ),
      'recordedRuns': (profile['settledRuns'] as List?)?.length ?? 0,
    };
    int bestOf(String first, String second, String third) =>
        [first, second, third]
            .map(
              (key) => (profile[key] is num ? (profile[key] as num).toInt() : 0)
                  .clamp(0, 1000000000),
            )
            .reduce((a, b) => a > b ? a : b);
    stats['bestScore'] = bestOf(
      'bestScore',
      'assistedBestScore',
      'continuedBestScore',
    );
    stats['bestSeconds'] = bestOf(
      'bestSeconds',
      'assistedBestSeconds',
      'continuedBestSeconds',
    );
    final usage = profile['publicUsage'] is Map
        ? jsonDecode(jsonEncode(profile['publicUsage']))
        : null;
    final epoch = AccountController.shared.session?.accountId == owner
        ? AccountController.shared.progressEpoch
        : '0';
    final next = _queue.then((_) async {
      try {
        await initialize();
        if (_prefs == null || !_credentialsReady) return;
        if (_devices[owner] == null) {
          if (_devices.length >= 32) return;
          final random = Random.secure();
          final secret = base64UrlEncode(
            List<int>.generate(32, (_) => random.nextInt(256)),
          ).replaceAll('=', '');
          final updated = {
            ..._devices,
            owner: {'id': const Uuid().v4(), 'secret': secret, 'sequence': 0},
          };
          await _secrets
              .write(jsonEncode(updated))
              .timeout(const Duration(seconds: 3));
          _devices = updated;
        }
        final device = Map<String, dynamic>.from(_devices[owner]);
        device['sequence'] = ((device['sequence'] as num?)?.toInt() ?? 0) + 1;
        device['stats'] = stats;
        device['usage'] = usage;
        device['epoch'] = epoch;
        device['active'] = active;
        _devices[owner] = device;
        // Store sequence before sending; never reuse it after a relaunch.
        await _secrets
            .write(jsonEncode(_devices))
            .timeout(const Duration(seconds: 3));
        _outbox[owner] = {
          'id': device['id'],
          'sequence': device['sequence'],
          'stats': stats,
          if (usage != null) 'usage': usage,
          'epoch': epoch,
          'active': active,
        };
        await _prefs!.setString(_outboxKey, jsonEncode(_outbox));
        unawaited(refresh(force: force));
      } catch (_) {
        /* Local progress has already been saved successfully. */
      }
    });
    _queue = next.catchError((Object _) {});
    return _queue;
  }

  Future<void> linkGuest(String accountId) async {
    final operation = _queue.then((_) async {
      try {
        await initialize();
        if (!_credentialsReady || _prefs == null) return;
        final device = Map<String, dynamic>.from(_devices['guest']);
        final stats = device['stats'];
        if (stats is! Map) return;
        device['sequence'] = ((device['sequence'] as num?)?.toInt() ?? 0) + 1;
        _devices['guest'] = device;
        await _secrets.write(jsonEncode(_devices));
        _outbox['guest'] = {
          'id': device['id'],
          'sequence': device['sequence'],
          'stats': stats,
          'linkAccountId': accountId,
          if (device['usage'] is Map) 'usage': device['usage'],
          'epoch': AccountController.shared.progressEpoch,
          'active': true,
        };
        await _prefs!.setString(_outboxKey, jsonEncode(_outbox));
      } catch (_) {
        /* Sign-in and local profile adoption have already succeeded. */
      }
    });
    _queue = operation.catchError((Object _) {});
    await _queue;
    if (_upload != null) await _upload;
    await refresh(force: true);
  }

  Future<Map<String, dynamic>?> publicCredentials() async {
    await initialize();
    final device = _devices['guest'];
    if (!_credentialsReady || device is! Map) return null;
    return {'id': device['id'], 'secret': device['secret']};
  }

  Future<void> refresh({bool force = false}) {
    if (_upload != null) return _upload!;
    if (!force &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(minutes: 2)) {
      return Future.value();
    }
    return _upload = _send().whenComplete(() => _upload = null);
  }

  Future<void> _send() async {
    await initialize();
    final base = endpoint;
    if (base == null ||
        base.userInfo.isNotEmpty ||
        !(base.scheme == 'https' ||
            (base.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(base.host)))) {
      return;
    }
    _lastAttempt = DateTime.now();
    for (final entry in Map<String, dynamic>.from(_outbox).entries) {
      final device = _devices[entry.key] as Map?,
          packet = Map<String, dynamic>.from(entry.value);
      if (device == null) continue;
      String? token;
      final authOwner = packet['linkAccountId'] as String? ?? entry.key;
      if (authOwner != 'guest') {
        final account = AccountController.shared;
        if (account.session?.accountId != authOwner || !account.attached) {
          continue;
        }
        try {
          token = await account.accessToken().timeout(
            const Duration(seconds: 4),
          );
        } catch (_) {
          continue;
        }
        if (account.session?.accountId != authOwner || !account.attached) {
          continue;
        }
      }
      final transport = client();
      try {
        final response = await transport
            .post(
              base.resolve('/players/v1/report'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({...packet, 'secret': device['secret']}),
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          // A concurrently queued newer total must not be deleted by this ack.
          final ack = _queue.then((_) async {
            if ((_outbox[entry.key] as Map?)?['sequence'] ==
                packet['sequence']) {
              if (packet['linkAccountId'] != null &&
                  entry.key == 'guest' &&
                  (_devices['guest'] as Map?)?['id'] == packet['id']) {
                final random = Random.secure();
                _devices['guest'] = {
                  'id': const Uuid().v4(),
                  'secret': base64UrlEncode(
                    List<int>.generate(32, (_) => random.nextInt(256)),
                  ).replaceAll('=', ''),
                  'sequence': 0,
                };
                await _secrets.write(jsonEncode(_devices));
                guestName.value = temporaryName;
              }
              _outbox.remove(entry.key);
              await _prefs?.setString(_outboxKey, jsonEncode(_outbox));
            }
          });
          _queue = ack.catchError((Object _) {});
          await _queue;
        }
      } catch (_) {
        /* Retry the durable latest report on a future foreground/save. */
      } finally {
        transport.close();
      }
    }
  }
}
