import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class AccountSecrets {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureAccountSecrets implements AccountSecrets {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  const SecureAccountSecrets();
  // Per-environment identity tokens must never overwrite multiplayer guest tokens.
  static const _endpoint = String.fromEnvironment('REGUN_IDENTITY_URL');
  String get _key => 'regun.account.v1.${Uri.encodeComponent(_endpoint)}';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}

/// Profile and its unsent replacement are one atomic, owner-scoped local record.
class AccountLocalStore {
  // ignore: prefer_initializing_formals
  AccountLocalStore({Directory? directory}) : _directory = directory;
  Directory? _directory;
  Future<void> _pending = Future.value();
  Future<File> _file(String owner) async {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(owner)) {
      throw const FormatException('Invalid account');
    }
    _directory ??= await getApplicationSupportDirectory();
    final folder = Directory('${_directory!.path}/accounts');
    await folder.create(recursive: true);
    return File('${folder.path}/$owner.json');
  }

  Future<Map<String, dynamic>?> read(String owner) async {
    await _pending;
    final file = await _file(owner);
    for (final candidate in [file, File('${file.path}.bak')]) {
      try {
        final data =
            jsonDecode(await candidate.readAsString()) as Map<String, dynamic>;
        if (data['schema'] == 1 &&
            data['owner'] == owner &&
            data['profile'] is Map) {
          return data;
        }
      } catch (_) {
        /* Preserve the completed backup on interrupted writes. */
      }
    }
    return null;
  }

  Future<void> remove(String owner) {
    final next = _pending.catchError((Object _) {}).then((_) async {
      final file = await _file(owner);
      for (final candidate in [
        file,
        File('${file.path}.bak'),
        File('${file.path}.tmp'),
      ]) {
        if (await candidate.exists()) await candidate.delete();
      }
    });
    _pending = next;
    return next;
  }

  Future<void> write(String owner, Map<String, dynamic> data) {
    final encoded = jsonEncode({...data, 'schema': 1, 'owner': owner});
    final next = _pending.catchError((Object _) {}).then((_) async {
      final file = await _file(owner),
          temp = File('${(await _file(owner)).path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      if (await file.exists()) await file.copy('${file.path}.bak');
      await temp.rename(file.path);
    });
    _pending = next;
    return next;
  }
}
