import 'package:regun/components/weapons/bullet_component.dart';

class ShrapnelComponent extends BulletComponent {
  ShrapnelComponent(
      {super.position,
      required super.direction,
      super.bulletRadius = 4,
      super.maxTravelDistance = 200,
      super.speed = 650,
      super.startPosition,
      super.angle})
      : super(primary: false, damage: 0.65);
}
