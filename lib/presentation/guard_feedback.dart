/// Cosmetic transitions follow accepted simulation serials, never bool diffs.
class GuardFeedback {
  int? _generation;
  int _absorbed = 0, _recharged = 0;
  double breakAge = -1, reformAge = -1;
  void sync(int generation, int absorbed, int recharged, double dt) {
    if (_generation != generation) {
      _generation = generation;
      _absorbed = absorbed;
      _recharged = recharged;
      breakAge = reformAge = -1;
      return;
    }
    if (breakAge >= 0) breakAge += dt;
    if (reformAge >= 0) reformAge += dt;
    if (absorbed > _absorbed) {
      breakAge = 0;
      reformAge = -1;
    }
    if (recharged > _recharged) {
      reformAge = 0;
      breakAge = -1;
    }
    _absorbed = absorbed;
    _recharged = recharged;
  }
}
