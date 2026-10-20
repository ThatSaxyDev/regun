import 'package:regun/components/enemies/pattern_boss.dart';
import 'package:regun/data/enemies.dart';

class DemonBossComponent extends PatternBoss {
  DemonBossComponent({super.position, super.maximumHealth = 230})
      : super(BossKind.demon);
}
