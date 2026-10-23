/// Practice population only. No damage, health, rewards or normal-run tuning.
enum TrainingPressure {
  light('Light', 8, 12, .38, 1),
  normal('Normal', 22, 30, .16, 2),
  horde('Horde', 38, 54, .10, 3);

  const TrainingPressure(
    this.label,
    this.nearbyTarget,
    this.arenaLimit,
    this.interval,
    this.batch,
  );
  final String label;
  final int nearbyTarget, arenaLimit, batch;
  final double interval;
}

class TrainingPressureClock {
  double _elapsed = 0;
  void reset() => _elapsed = 0;
  int advance(double dt, TrainingPressure pressure) {
    if (!dt.isFinite || dt <= 0) return 0;
    _elapsed += dt;
    if (_elapsed < pressure.interval) return 0;
    _elapsed = 0; // No burst backlog after pause or a long frame.
    return pressure.batch;
  }
}
