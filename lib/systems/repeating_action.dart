import 'package:flame/components.dart';

/// Repeats an action without manufacturing a component for every timer tick.
class RepeatingAction extends TimerComponent {
  RepeatingAction({required super.period, required super.onTick})
    : super(repeat: true);
}
