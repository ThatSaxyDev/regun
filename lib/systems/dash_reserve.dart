import 'dart:math' as math;

/// Stored dashes refill sequentially on the active simulation clock.
class DashReserve {
  int capacity = 1, charges = 1;
  double remaining = 0, duration = 1.6;
  void setCapacity(int value) {
    final next = value.clamp(1, 3);
    charges = (charges + math.max(0, next - capacity)).clamp(0, next).toInt();
    capacity = next;
    if (charges == capacity) remaining = 0;
  }

  bool spend(double recharge) {
    if (charges <= 0) return false;
    charges--;
    if (remaining <= 0) remaining = duration = recharge;
    return true;
  }

  void advance(double dt, double recharge) {
    if (!dt.isFinite || dt <= 0 || charges >= capacity) return;
    remaining -= dt;
    while (remaining <= 1e-9 && charges < capacity) {
      charges++;
      duration = recharge;
      remaining = charges < capacity ? remaining + recharge : 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'capacity': capacity,
    'charges': charges,
    'remaining': remaining,
    'duration': duration,
  };
  void restore(Map<String, dynamic> map) {
    final cap = map['capacity'] ?? 1;
    final r = map['remaining'] ?? 0;
    final d = map['duration'] ?? 1.6;
    final c = map['charges'] ?? (r is num && r > 0 ? 0 : 1);
    if (cap is! int ||
        cap < 1 ||
        cap > 3 ||
        c is! int ||
        c < 0 ||
        c > cap ||
        r is! num ||
        !r.isFinite ||
        r < 0 ||
        r > 1.6 ||
        d is! num ||
        !d.isFinite ||
        d < .6 ||
        d > 1.6 ||
        (c == cap && r != 0) ||
        (c < cap && r <= 0)) {
      throw const FormatException('Invalid dash reserve');
    }
    capacity = cap;
    charges = c;
    remaining = r.toDouble();
    duration = d.toDouble();
  }
}
