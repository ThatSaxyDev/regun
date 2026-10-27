/// Accepted selection counts for one run. Never inferred from final rank maps.
class RunStatistics {
  RunStatistics({
    this.complete = true,
    Map<String, int>? picks,
    Map<String, int>? support,
  }) : picks = {...?picks},
       support = {...?support};
  final bool complete;
  final Map<String, int> picks, support;
  void picked(String id) => picks[id] = (picks[id] ?? 0) + 1;
  void supported(String id) => support[id] = (support[id] ?? 0) + 1;
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'complete': complete,
    'picks': {...picks},
    'support': {...support},
  };
  static RunStatistics read(dynamic raw) {
    if (raw == null) return RunStatistics(complete: false);
    if (raw is! Map || raw['schema'] != 1 || raw['complete'] is! bool) {
      throw const FormatException('Invalid run statistics');
    }
    Map<String, int> counts(String key) {
      final map = raw[key];
      if (map is! Map || map.length > 100) {
        throw const FormatException('Invalid item counts');
      }
      return {for (final e in map.entries) _id(e.key): _count(e.value)};
    }

    return RunStatistics(
      complete: raw['complete'],
      picks: counts('picks'),
      support: counts('support'),
    );
  }

  static String _id(dynamic id) {
    if (id is! String || !RegExp(r'^[A-Za-z][A-Za-z0-9_:]{0,95}$').hasMatch(id)) {
      throw const FormatException('Invalid item identity');
    }
    return id;
  }

  static int _count(dynamic count) {
    if (count is! int || count < 1 || count > 10000) {
      throw const FormatException('Invalid item count');
    }
    return count;
  }
}
