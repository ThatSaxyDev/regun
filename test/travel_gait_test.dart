import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/travel_gait.dart';

void main() {
  test(
    'ground gait advances only from accepted travel and fresh simulation age',
    () {
      final gait = TravelGait()..sample(Offset.zero, 0);
      gait.sample(const Offset(5, 0), .1);
      expect(gait.frame, 1);
      gait.sample(const Offset(90, 0), .1);
      expect(
        gait.frame,
        1,
        reason: 'Duplicate snapshots do not manufacture steps',
      );
      gait.sample(const Offset(5, 0), .2);
      expect(gait.frame, 0);
      expect(gait.moving, isFalse);
      gait.sample(const Offset(10, 0), .3);
      expect(gait.frame, 2);
      gait.sample(const Offset(500, 0), .4);
      expect(gait.moving, isFalse, reason: 'Relocation is not locomotion');
      expect(TravelGait.phaseFor('e:1:25'), TravelGait.phaseFor('e:1:25'));
    },
  );
}
