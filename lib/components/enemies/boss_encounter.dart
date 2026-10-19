import 'package:regun/data/enemies.dart';

abstract interface class BossEncounter {
  BossKind get kind;
  bool get enraged;
}
