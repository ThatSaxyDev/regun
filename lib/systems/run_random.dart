import 'dart:math';

/// Small serializable generator for encounter/offer reproducibility.
class RunRandom implements Random {
  RunRandom(int seed) : state = seed & 0x7fffffff;
  int state;
  int _next() => state = (state * 1103515245 + 12345) & 0x7fffffff;
  @override
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max);
    return (_next() / 0x80000000 * max).floor();
  }

  @override
  double nextDouble() => _next() / 0x80000000;
  @override
  bool nextBool() => nextDouble() < 0.5;
}
