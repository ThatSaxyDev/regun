import 'package:regun/data/enemies.dart';

abstract interface class BossEncounter {
  BossKind get kind;
  double get maximumHealth;
  bool get enraged;
}
