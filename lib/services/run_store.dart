import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/services/local_preferences.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Versioned single-run checkpoint. Writes and clears are serialized so an old
/// background write cannot resurrect a run after its results have settled.
class RunStore {
  static final shared = RunStore();
  static final expedition = RunStore(expeditionSlot: true);
  RunStore({this._directory, this.expeditionSlot = false});
  final bool expeditionSlot;
  String get _slot => expeditionSlot ? 'expedition' : 'run';
  Directory? _directory;
  Future<void> _pending = Future.value();

  bool _validOwner(String owner) =>
      owner == 'guest' || RegExp(r'^[a-f0-9-]{36}$').hasMatch(owner);
  String _webKey(String owner) => 'regun.web.$_slot.v1.$owner';

  Future<File?> _file(String owner) async {
    if (!_validOwner(owner)) {
      return null;
    }
    try {
      _directory ??= await getApplicationSupportDirectory();
      await _directory!.create(recursive: true);
      final suffix = owner == 'guest' ? '' : '-$owner';
      return File('${_directory!.path}/regun-$_slot-v1$suffix.json');
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
    if (kIsWeb) {
      if (!_validOwner(owner)) return null;
      try {
        final prefs = await SharedPreferences.getInstance();
        final map = jsonDecode(prefs.getString(_webKey(owner)) ?? 'null');
        return _snapshot(map, validate);
      } catch (_) {
        return null;
      }
    }
    final file = await _file(owner);
    if (file == null) return null;
    for (final candidate in [file, File('${file.path}.bak')]) {
      try {
        if (!await candidate.exists()) continue;
        final map = jsonDecode(await candidate.readAsString());
        if (map is Map && map['settled'] == true) return null;
        final snapshot = _snapshot(map, validate);
        if (snapshot != null) return snapshot;
      } on FormatException {
        // Try the previous completed checkpoint.
      } on FileSystemException {
        // A failed read must not prevent starting a fresh run.
      }
    }
    return null;
  }

  Map<String, dynamic>? _snapshot(
    Object? map,
    bool Function(Map<String, dynamic>)? validate,
  ) {
    if (map is! Map ||
        map['settled'] == true ||
        (map.containsKey('expedition') != expeditionSlot) ||
        ![1, 2].contains(map['schema']) ||
        map['state'] is! Map ||
        map['player'] is! List ||
        map['enemies'] is! List ||
        map['drops'] is! List) {
      return null;
    }
    final snapshot = Map<String, dynamic>.from(map);
    return validate == null || validate(snapshot) ? snapshot : null;
  }

  Future<bool> _saveWeb(String owner, String payload) async {
    if (!_validOwner(owner)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_webKey(owner), payload);
    } catch (_) {
      return false;
    }
  }

  Future<bool> write(Map<String, dynamic> snapshot) {
    final owner = LocalPreferences.shared.profileOwner;
    // Encode before queueing: callers can no longer mutate this snapshot.
    final payload = jsonEncode(snapshot);
    var saved = false;
    final operation = _pending.then((_) async {
      if (kIsWeb) {
        saved = await _saveWeb(owner, payload);
        return;
      }
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
      if (kIsWeb) {
        saved = await _saveWeb(owner, payload);
        return;
      }
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
      if (kIsWeb) {
        if (!_validOwner(owner)) return;
        try {
          final prefs = await SharedPreferences.getInstance();
          if (expectedRunId != null) {
            try {
              final map = jsonDecode(prefs.getString(_webKey(owner)) ?? 'null');
              if (map is Map &&
                  map['id'] != null &&
                  map['id'] != expectedRunId) {
                return;
              }
            } on FormatException {
              // A corrupt record can still be cleared.
            }
          }
          await prefs.remove(_webKey(owner));
        } catch (_) {
          // Storage may be disabled or full.
        }
        return;
      }
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
