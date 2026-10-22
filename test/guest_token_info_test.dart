import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/guest_token_info.dart';

String jwt(Map<String, Object?> claims) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
void main() {
  test(
    'diagnostics distinguish absent, malformed, permanent and expired tokens',
    () {
      final now = DateTime.fromMillisecondsSinceEpoch(200000);
      expect(GuestTokenInfo(null).safeReport(now)['present'], false);
      expect(GuestTokenInfo('bad').safeReport(now)['jwtParsed'], false);
      expect(
        GuestTokenInfo(jwt({'iat': 100})).safeReport(now)['hasExpiry'],
        false,
      );
      expect(
        GuestTokenInfo(jwt({'exp': 199})).safeReport(now)['expired'],
        true,
      );
      expect(
        GuestTokenInfo(jwt({'exp': 201})).safeReport(now)['expired'],
        false,
      );
    },
  );
  test(
    'safe diagnostics never serialize issuer, identity or bearer material',
    () {
      final report = GuestTokenInfo(
        jwt({
          'iss': 'private-issuer',
          'sub': 'private-identity',
          'hex_identity': 'private-identity',
          'iat': 100,
        }),
      ).safeReport(DateTime.now());
      final encoded = jsonEncode(report);
      expect(encoded.contains('private'), false);
      expect(encoded.contains('signature'), false);
      expect(
        report.keys,
        unorderedEquals(['present', 'jwtParsed', 'issuedAt', 'hasExpiry']),
      );
    },
  );
}
