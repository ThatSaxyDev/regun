/// Per-level cost, not cumulative XP. Rising increments make later upgrades
/// substantially more expensive without an unbounded exponential multiplier.
class XPProgression {
  static int cost(int currentLevel) {
    final n = (currentLevel - 1).clamp(0, 100000);
    return 25 + 25 * n + 5 * n * (n - 1) ~/ 2;
  }
}
