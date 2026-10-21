import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spacetimedb/spacetimedb.dart';

import 'online_session.dart';

/// Per-endpoint guest identity in native Keychain/Keystore-backed storage.
/// Never copy bearer credentials into preferences, diagnostics or save files.
class SecureOnlineTokens implements AuthTokenStore {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const key =
      'regun.online.${OnlineSession.host}.${OnlineSession.database}';
  @override
  Future<String?> loadToken() => storage.read(key: key);
  @override
  Future<void> saveToken(String token) => storage.write(key: key, value: token);
  @override
  Future<void> clearToken() => storage.delete(key: key);
}
