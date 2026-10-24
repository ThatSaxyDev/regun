import 'package:regun/data/enemies.dart';

/// Observed normal-run wins only; old aggregate totals cannot be split by boss.
class BossHistory {
  static final ids = BossKind.values.map((b) => b.name).toSet();
  static bool valid(dynamic raw) =>
      raw is Map &&
      raw.length <= ids.length &&
      raw.entries.every(
        (e) =>
            ids.contains(e.key) &&
            e.value is int &&
            e.value >= 0 &&
            e.value <= 1000000000,
      );
  static Map<String, int> read(dynamic raw) => raw is! Map
      ? {}
      : {
          for (final e in raw.entries)
            if (ids.contains(e.key) && e.value is int && e.value >= 0)
              e.key as String: (e.value as int).clamp(0, 1000000000),
        };
}
