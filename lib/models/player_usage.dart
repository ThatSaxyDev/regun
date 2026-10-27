/// Career usage is updated once at settlement, independent of publishing/sign-in.
class PlayerUsage {
  final Map<String, Map<String, int>> weapons = {},
      upgrades = {},
      fusions = {},
      support = {};
  Map<String, dynamic>? bestRun;
  void record(Map<String, dynamic> run) {
    // Incomplete historical pick coverage does not erase known run facts.
    if (run['weapon'] is! String) return;
    int n(String key) => (run[key] as num?)?.toInt() ?? 0;
    final weapon = run['weapon'] as String;
    final w = weapons.putIfAbsent(
      weapon,
      () => {'runs': 0, 'seconds': 0, 'bestScore': 0},
    );
    w['runs'] = (w['runs']! + 1).clamp(0, 1000000000);
    w['seconds'] = (w['seconds']! + n('seconds')).clamp(0, 1000000000);
    if (n('score') > w['bestScore']!) w['bestScore'] = n('score');
    void add(Map<String, Map<String, int>> target, String id, int count) {
      final row = target.putIfAbsent(id, () => {'runs': 0, 'picks': 0});
      row['runs'] = (row['runs']! + 1).clamp(0, 1000000000);
      row['picks'] = (row['picks']! + count).clamp(0, 1000000000);
    }

    for (final e in (run['picks'] as Map? ?? {}).entries) {
      add(upgrades, e.key as String, e.value as int);
    }
    for (final e in (run['support'] as Map? ?? {}).entries) {
      add(support, e.key as String, e.value as int);
    }
    for (final id in run['fusions'] as List? ?? []) {
      add(fusions, id as String, 1);
    }
    if (bestRun == null || n('score') > (bestRun!['score'] as int)) {
      bestRun = Map<String, dynamic>.from(run);
    }
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'coverage': 2,
    'weapons': weapons,
    'upgrades': upgrades,
    'fusions': fusions,
    'support': support,
    if (bestRun != null) 'bestRun': bestRun,
  };
  static PlayerUsage read(dynamic raw) {
    final p = PlayerUsage();
    if (raw is! Map || raw['schema'] != 1) return p;
    for (final entry in {
      'weapons': p.weapons,
      'upgrades': p.upgrades,
      'fusions': p.fusions,
      'support': p.support,
    }.entries) {
      final values = raw[entry.key];
      if (values is! Map || values.length > 100) continue;
      for (final e in values.entries) {
        if (e.key is! String || e.value is! Map) continue;
        final row = e.value as Map;
        final keys = entry.key == 'weapons'
            ? ['runs', 'seconds', 'bestScore']
            : ['runs', 'picks'];
        if (keys.every(
          (key) => row[key] is int && row[key] >= 0 && row[key] <= 1000000000,
        )) {
          entry.value[e.key as String] = {
            for (final key in keys) key: row[key] as int,
          };
        }
      }
    }
    if (raw['bestRun'] is Map) {
      p.bestRun = Map<String, dynamic>.from(raw['bestRun'] as Map);
    }
    return p;
  }
}
