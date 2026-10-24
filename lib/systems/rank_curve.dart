import 'dart:math' as math;

/// Per-family IV/VIII milestones redistribute five late steps, preserving VIII.
class RankCurve {
  static double late(int rank, String id, Map<String, num> values) {
    if (rank <= 3) return 0;
    if (values['ranks.meta.policy'] != 1) return (rank - 3).toDouble();
    final iv = (values['ranks.$id.iv'] ?? 1).toDouble();
    final viii = (values['ranks.$id.viii'] ?? 1).toDouble();
    return iv +
        math.min(3, math.max(0, rank - 4)) * (5 - iv - viii) / 3 +
        (rank >= 8 ? viii : 0);
  }

  static double total(
    int rank,
    String id,
    double early,
    double tail,
    Map<String, num> values,
  ) => math.min(3, rank) * early + late(rank, id, values) * tail;
}
