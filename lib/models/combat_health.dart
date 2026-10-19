/// Authoritative health with a single lethal transition. Presentation never
/// decides whether damage or a reward happened.
class CombatHealth {
  CombatHealth(this.maximum) : current = maximum {
    assert(maximum > 0);
  }

  final double maximum;
  double current;
  bool get isDead => current <= 0;
  double get fraction => current / maximum;

  DamageResult damage(double amount) {
    if (isDead || !amount.isFinite || amount <= 0) {
      return DamageResult.ignored;
    }
    current = (current - amount).clamp(0, maximum);
    return isDead ? DamageResult.killed : DamageResult.hit;
  }
}

enum DamageResult { ignored, hit, killed }

abstract interface class Damageable {
  CombatHealth get combatHealth;
  bool takeDamage(double amount);
}
