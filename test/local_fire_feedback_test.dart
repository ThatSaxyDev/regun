import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/local_fire_feedback.dart';

void main() {
  bool update(
    LocalFireFeedback f,
    double now,
    bool held,
    int shots, {
    bool enabled = true,
    bool reloading = false,
    int ammo = 5,
    double cooldown = 0,
  }) => f.update(
    now: now,
    held: held,
    enabled: enabled,
    shots: shots,
    ammo: ammo,
    reloading: reloading,
    cooldown: cooldown,
  );
  test(
    'first trigger cues now and matching server confirmation never doubles it',
    () {
      final f = LocalFireFeedback();
      expect(update(f, 0, false, 0), false);
      expect(update(f, .016, true, 0), true);
      expect(update(f, .032, true, 0), false);
      expect(update(f, .25, true, 1), false);
      expect(update(f, .5, true, 2), true);
    },
  );
  test(
    'empty, reload, cooldown and disabled controls never predict firing',
    () {
      for (final block in ['empty', 'reload', 'cooldown', 'disabled']) {
        final f = LocalFireFeedback();
        expect(
          update(
            f,
            0,
            true,
            0,
            ammo: block == 'empty' ? 0 : 5,
            reloading: block == 'reload',
            enabled: block != 'disabled',
            cooldown: block == 'cooldown' ? .2 : 0,
          ),
          false,
        );
      }
    },
  );
  test(
    'pending cue bounds repeated taps, expires and resets across epochs',
    () {
      final f = LocalFireFeedback();
      expect(update(f, 0, true, 0), true);
      update(f, .05, false, 0);
      expect(update(f, .1, true, 0), false);
      update(f, 1.2, false, 0);
      expect(update(f, 1.3, true, 0), true);
      f.reset();
      expect(update(f, 2, false, 30), false);
      expect(update(f, 2.1, true, 30), true);
    },
  );
}
