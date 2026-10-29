import 'package:flame/components.dart';

/// Lightweight weapon target, excluded from enemy rewards and body occupancy.
abstract class ShootableOrdnance extends PositionComponent {
  ShootableOrdnance({required super.size}) : super(anchor: Anchor.center);
  double get hitRadius;
  bool hit(double amount);
}
