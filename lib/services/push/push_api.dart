import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:regun/services/app_updates.dart' show releaseChannel;

/// Notification registration and preferences. Same origin, TLS and bounds as
/// [AccountApi]; every call is detached from gameplay and may fail silently.
class PushApi {
  PushApi({Uri? endpoint, http.Client Function()? client})
    : endpoint = endpoint ?? _configuredEndpoint(),
      _client = client ?? http.Client.new;

  final Uri? endpoint;
  final http.Client Function() _client;

  static Uri? _configuredEndpoint() {
    const value = String.fromEnvironment('REGUN_IDENTITY_URL');
    return value.isEmpty ? null : Uri.parse(value);
  }

  bool get configured => endpoint != null;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final base = endpoint;
    if (base == null) return const {'ok': false};
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(base.host))) {
      return const {'ok': false};
    }
    final client = _client();
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final uri = base.resolve(path);
      final response =
          await (method == 'GET'
                  ? client.get(uri, headers: headers)
                  : method == 'DELETE'
                  ? client.delete(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    )
                  : client.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
              .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.length > 300000) {
        return const {'ok': false};
      }
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
      return const {'ok': false};
    } catch (_) {
      return const {'ok': false};
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> register({
    required String subscriptionId,
    required String platform,
    required String appVersion,
    required String locale,
    required String timezone,
    required String permission,
    required bool optedIn,
    String? token,
    String? deviceId,
    String? deviceSecret,
  }) => request(
    '/notifications/subscription',
    token: token,
    body: {
      'subscriptionId': subscriptionId,
      'platform': platform,
      'appVersion': appVersion,
      'releaseChannel': releaseChannel,
      'locale': locale,
      'timezone': timezone,
      'permission': permission,
      'optedIn': optedIn,
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceSecret != null) 'deviceSecret': deviceSecret,
    },
  );

  Future<Map<String, dynamic>> unregister({
    required String subscriptionId,
    String? token,
    String? deviceId,
    String? deviceSecret,
  }) => request(
    '/notifications/subscription',
    method: 'DELETE',
    token: token,
    body: {
      'subscriptionId': subscriptionId,
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceSecret != null) 'deviceSecret': deviceSecret,
    },
  );

  Future<Map<String, dynamic>> preferences({
    String? token,
    String? deviceId,
    String? deviceSecret,
  }) => token != null
      ? request('/notifications/preferences', method: 'GET', token: token)
      : request(
          '/notifications/preferences/read',
          body: {'deviceId': deviceId, 'deviceSecret': deviceSecret},
        );

  Future<Map<String, dynamic>> setPreferences({
    required Map<String, bool> values,
    String? token,
    String? deviceId,
    String? deviceSecret,
  }) => request(
    '/notifications/preferences',
    token: token,
    body: {
      ...values,
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceSecret != null) 'deviceSecret': deviceSecret,
    },
  );
}
