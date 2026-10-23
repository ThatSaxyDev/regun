import 'dart:convert';

import 'package:http/http.dart' as http;

class AccountError implements Exception {
  const AccountError(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// Requests are made only for account/online actions. Local play never awaits this.
class AccountApi {
  AccountApi({Uri? endpoint, http.Client Function()? client})
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
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final base = endpoint;
    if (base == null) {
      throw const AccountError(
        'Cloud saves are not available yet. Your progress stays on this device.',
      );
    }
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(base.host))) {
      throw const AccountError(
        'Account service unavailable. You can still play offline.',
      );
    }
    final client = _client();
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response =
          await (body == null
                  ? client.get(base.resolve(path), headers: headers)
                  : client.post(
                      base.resolve(path),
                      headers: headers,
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 12));
      // Proxies can reject a request with HTML or an empty body. Preserve
      // their HTTP status instead of turning a definite response into a timeout.
      Map<String, dynamic>? data;
      if (response.bodyBytes.length <= 300000) {
        try {
          final value = jsonDecode(response.body);
          if (value is Map<String, dynamic>) data = value;
        } on FormatException {
          /* Non-JSON ingress response. */
        }
      }
      if (response.statusCode != 200) {
        final message = data?['message'];
        throw AccountError(
          message is String && message.length <= 300
              ? message
              : response.statusCode == 401
              ? 'Sign in again.'
              : response.statusCode == 403
              ? 'Request blocked by the server (403). Retry when the service is restored.'
              : 'Account service returned ${response.statusCode}. Try again.',
          status: response.statusCode,
        );
      }
      if (data == null) throw const FormatException();
      return data;
    } on AccountError {
      rethrow;
    } catch (_) {
      throw const AccountError(
        'Account service unavailable. You can still play offline.',
      );
    } finally {
      client.close();
    }
  }
}
