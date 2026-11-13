import 'dart:convert';

import 'package:regun/services/local_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local campaign records. A single write commits the terminal run ID
/// with the records, independently of wallet and Arena profile settlement.
class ExpeditionProgress {
  static final shared = ExpeditionProgress();
  Future<void> _pending = Future.value();

  String _key(String owner) => 'expedition.progress.v1.$owner';

  Future<Map<String, dynamic>> read(String owner) async {
    try {
      final storage = await SharedPreferences.getInstance();
      final raw = jsonDecode(storage.getString(_key(owner)) ?? '{}');
      return Map<String, dynamic>.from(raw as Map);
    } on Object {
      return {};
    }
  }

  Future<bool> record(
    String owner,
    String runId, {
    required bool victory,
    required int threat,
    required int seconds,
    required int region,
    required Iterable<String> boons,
    required Iterable<String> capstones,
  }) {
    var saved = false;
    final task = _pending.then((_) async {
      if (owner != LocalPreferences.shared.profileOwner) return;
      try {
        final storage = await SharedPreferences.getInstance();
        final record = await read(owner);
        if (record['lastRun'] == runId) {
          saved = true;
          return;
        }
        final best = record['bestSeconds'] as int? ?? 0;
        final depth = record['deepestRegion'] as int? ?? 0;
        final highest = record['highestThreat'] as int? ?? -1;
        saved = await storage.setString(
          _key(owner),
          jsonEncode({
            'lastRun': runId,
            'clears': (record['clears'] as int? ?? 0) + (victory ? 1 : 0),
            'highestThreat': victory && threat > highest ? threat : highest,
            'bestSeconds': victory && (best == 0 || seconds < best)
                ? seconds
                : best,
            'deepestRegion': region > depth ? region : depth,
            'boons': <String>{
              ...(record['boons'] as List? ?? []).whereType<String>(),
              ...boons,
            }.toList(),
            'capstones': <String>{
              ...(record['capstones'] as List? ?? []).whereType<String>(),
              ...capstones,
            }.toList(),
          }),
        );
      } on Object {
        // Keep the terminal checkpoint so settlement can be retried.
      }
    });
    _pending = task;
    return task.then((_) => saved);
  }

  Future<void> clear(String owner) {
    final task = _pending.then((_) async {
      try {
        final storage = await SharedPreferences.getInstance();
        await storage.remove(_key(owner));
      } on Object {
        // Match checkpoint deletion when the platform store is unavailable.
      }
    });
    _pending = task;
    return task;
  }
}
