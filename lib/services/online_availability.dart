import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:regun/config/release_features.dart';

final onlineAvailabilityProvider = Provider<OnlineAvailability>((ref) {
  final policy = OnlineAvailability();
  ref.onDispose(policy.dispose);
  return policy;
});

enum OnlineAvailabilityState { checking, enabled, disabled, unavailable }

/// Public server policy, never a persisted build-time feature flag. Unknown or
/// failed responses close new entry; no request blocks solo navigation.
class OnlineAvailability extends ChangeNotifier {
  OnlineAvailability({http.Client Function()? client, Uri? endpoint})
    : _client = client ?? http.Client.new,
      endpoint = endpoint ?? Uri.parse(ReleaseFeatures.remoteConfigUrl);
  final http.Client Function() _client;
  final Uri endpoint;
  OnlineAvailabilityState state = OnlineAvailabilityState.checking;
  bool get enabled => state == OnlineAvailabilityState.enabled;
  Future<bool>? _request;
  bool _disposed = false;

  Future<bool> refresh() {
    if (_disposed) return Future.value(false);
    return _request ??= _fetch().whenComplete(() => _request = null);
  }

  Future<bool> _fetch() async {
    final client = _client();
    var next = OnlineAvailabilityState.unavailable;
    try {
      if (endpoint.scheme != 'https' &&
          !(endpoint.scheme == 'http' &&
              ['127.0.0.1', 'localhost'].contains(endpoint.host))) {
        throw StateError('Invalid feature endpoint');
      }
      final response = await client
          .get(endpoint, headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 || response.bodyBytes.length > 4096) {
        throw StateError('Feature policy unavailable');
      }
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['schemaVersion'] != 1 ||
          data['onlinePlay'] is! bool) {
        throw const FormatException('Invalid feature policy');
      }
      next = data['onlinePlay'] == true
          ? OnlineAvailabilityState.enabled
          : OnlineAvailabilityState.disabled;
    } catch (_) {
      // Do not retain a stale enabled value through an outage or malformed policy.
    } finally {
      client.close();
    }
    if (_disposed) return false;
    state = next;
    notifyListeners();
    return enabled;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
