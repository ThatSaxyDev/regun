import 'package:regun/components/enemies/hostile_area.dart';

class DemonBossAttackArea extends HostileArea {
  DemonBossAttackArea({required super.position})
    : super(radius: 165, warning: 0.9, damage: 2, cause: 'Demon slam');
}
