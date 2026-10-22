import 'dart:convert';

/// Unverified claims are diagnostics only, never authentication decisions.
/// Never serialize token contents, identity, signature or raw issuer/subject.
class GuestTokenInfo {
  GuestTokenInfo(String? token) {
    if (token == null) return;
    present = true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return;
      final value = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (value is! Map) return;
      parsed = true;
      issuedAt = value['iat'] is num ? (value['iat'] as num).toInt() : null;
      expiresAt = value['exp'] is num ? (value['exp'] as num).toInt() : null;
      issuer = value['iss'] as String?;
    } catch (_) {
      /* Malformed credentials stay private. */
    }
  }
  bool present = false, parsed = false;
  int? issuedAt, expiresAt;
  String? issuer;
  Map<String, Object?> safeReport(DateTime now) => {
    'present': present,
    'jwtParsed': parsed,
    'issuedAt': issuedAt,
    'hasExpiry': expiresAt != null,
    if (expiresAt != null)
      'expired': expiresAt! <= now.millisecondsSinceEpoch ~/ 1000,
  };
}
