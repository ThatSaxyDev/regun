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

  Future<File?> _file() async {
    try {
      _directory ??= await getApplicationSupportDirectory();
      await _directory!.create(recursive: true);
      return File('${_directory!.path}/regun-run-v1.json');
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
    await _pending;
    final file = await _file();
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
    // Encode before queueing: callers can no longer mutate this snapshot.
    final payload = jsonEncode(snapshot);
    var saved = false;
    final operation = _pending.then((_) async {
      final file = await _file();
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

  Future<void> clear({String? expectedRunId}) {
    final operation = _pending.then((_) async {
      final file = await _file();
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
