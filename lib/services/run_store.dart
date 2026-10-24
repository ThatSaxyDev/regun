import 'package:regun/services/local_preferences.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Versioned single-run checkpoint. Writes and clears are serialized so an old
/// background write cannot resurrect a run after its results have settled.
class RunStore {
  static final shared = RunStore();
  RunStore({this._directory});
  Directory? _directory;
  Future<void> _pending = Future.value();

  Future<File?> _file(String owner) async {
    if (owner != 'guest' && !RegExp(r'^[a-f0-9-]{36}$').hasMatch(owner)) {
      return null;
    }
    try {
      _directory ??= await getApplicationSupportDirectory();
      await _directory!.create(recursive: true);
      final suffix = owner == 'guest' ? '' : '-$owner';
      return File('${_directory!.path}/regun-run-v1$suffix.json');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> read({
    bool Function(Map<String, dynamic>)? validate,
  }) async {
    final owner = LocalPreferences.shared.profileOwner;
    await _pending;
    final file = await _file(owner);
    if (file == null) return null;
    for (final candidate in [file, File('${file.path}.bak')]) {
      try {
        if (!await candidate.exists()) continue;
        final map = jsonDecode(await candidate.readAsString());
        if (map is Map && map['settled'] == true) return null;
        if (map is Map &&
            [1, 2].contains(map['schema']) &&
            map['state'] is Map &&
            map['player'] is List &&
            map['enemies'] is List &&
            map['drops'] is List) {
          final snapshot = Map<String, dynamic>.from(map);
          if (validate == null || validate(snapshot)) return snapshot;
        }
      } on FormatException {
        // Try the previous completed checkpoint.
      } on FileSystemException {
        // A failed read must not prevent starting a fresh run.
      }
    }
    return null;
  }

  Future<bool> write(Map<String, dynamic> snapshot) {
    final owner = LocalPreferences.shared.profileOwner;
    // Encode before queueing: callers can no longer mutate this snapshot.
    final payload = jsonEncode(snapshot);
    var saved = false;
    final operation = _pending.then((_) async {
      final file = await _file(owner);
      if (file == null) return;
      try {
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(payload, flush: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await temporary.rename(file.path);
        saved = true;
      } on FileSystemException {
        // The existing completed file/backup remains recoverable.
      }
    });
    _pending = operation;
    return operation.then((_) => saved);
  }

  /// Critical recovery transitions replace both completed copies before spend
  /// or combat resume. An older live backup must not reset a paid allowance.
  Future<bool> writeRecovery(Map<String, dynamic> snapshot) {
    final owner = LocalPreferences.shared.profileOwner;
    final payload = jsonEncode(snapshot);
    var saved = false;
    // One queue operation owns both copies; a background save or owner switch
    // cannot interleave between them and restore a pre-purchase backup.
    final operation = _pending.then((_) async {
      final file = await _file(owner);
      if (file == null) return;
      try {
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(payload, flush: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await temporary.rename(file.path);
        final backupTemporary = File('${file.path}.bak.tmp');
        await backupTemporary.writeAsString(payload, flush: true);
        await backupTemporary.rename('${file.path}.bak');
        saved = true;
      } on FileSystemException {
        // Never debit or resume until both durable copies are confirmed.
      }
    });
    _pending = operation;
    return operation.then((_) => saved);
  }

  Future<void> clear({String? expectedRunId}) => _clear(
    LocalPreferences.shared.profileOwner,
    expectedRunId: expectedRunId,
  );
  Future<void> clearOwner(String owner) => _clear(owner);
  Future<void> _clear(String owner, {String? expectedRunId}) {
    final operation = _pending.then((_) async {
      final file = await _file(owner);
      if (file == null) return;
      try {
        if (expectedRunId != null && await file.exists()) {
          try {
            final current = jsonDecode(await file.readAsString());
            if (current is Map &&
                current['id'] != null &&
                current['id'] != expectedRunId) {
              return;
            }
          } on FormatException {
            /* Replace a corrupt checkpoint with a tombstone. */
          }
        }

        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          '{"schema":1,"settled":true}',
          flush: true,
        );
        await temporary.rename(file.path);
        final backup = File('${file.path}.bak');
        if (await backup.exists()) await backup.delete();
      } on FileSystemException {
        // Reportable by the future run lifecycle integration; never crash play.
      }
    });
    _pending = operation;
    return operation;
  }
}
