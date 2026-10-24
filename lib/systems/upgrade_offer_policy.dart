/// Version1 is pinned for a run. Older checkpoints keep their original selector.
class UpgradeOfferPolicy {
  static const version = 1;
  static bool capacity(String id) =>
      id == 'dashCapacity' || id == 'grenadeCapacity';

  static double weight(
    String id, {
    required int rank,
    required bool special,
    required double luck,
    required bool recent,
  }) =>
      (capacity(id) ? (rank == 0 ? .35 : .20) : (rank > 0 ? 1.5 : 1)) *
      (special ? 1 + luck * .35 : 1) *
      (recent ? .35 : 1);

  static List<String> choose({
    required List<String> eligible,
    required Map<String, int> ranks,
    required Set<String> special,
    required double luck,
    required List<String> recent,
    required double Function() random,
  }) {
    final pool = List<String>.of(eligible), result = <String>[];
    while (result.length < 3 && pool.isNotEmpty) {
      final existing = pool
          .where((id) => !capacity(id) && (ranks[id] ?? 0) > 0)
          .toList();
      final candidates = result.isEmpty && existing.isNotEmpty
          ? existing
          : pool;
      double chance(String id) => weight(
        id,
        rank: ranks[id] ?? 0,
        special: special.contains(id),
        luck: luck,
        recent: recent.contains(id),
      );
      var pick =
          random() * candidates.fold<double>(0, (sum, id) => sum + chance(id));
      var selected = candidates.last;
      for (final id in candidates) {
        pick -= chance(id);
        if (pick <= 0) {
          selected = id;
          break;
        }
      }
      result.add(selected);
      pool.remove(selected);
    }
    return result;
  }
}
