// flutter run -t tool/upgrade_feel_review.dart --dart-define=REGUN_UPGRADE_FEEL_REVIEW=true
// Separate review entry point; shipping entry point retains the baseline flow.
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/main.dart' show GameApp;
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/widgets/click_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.setLandscape();
  await Flame.device.fullScreen();
  await LocalPreferences.shared.load();
  try {
    await SoLoud.instance.init();
  } catch (_) {
    /* Muted review stays usable. */
  }
  runApp(const ProviderScope(child: GameApp(reviewHome: UpgradeFeelReview())));
}

class UpgradeFeelReview extends StatelessWidget {
  const UpgradeFeelReview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161b18),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'UPGRADE FEEL · PLAYER REVIEW',
              style: TextStyle(
                color: Color(0xffd1c2a2),
                fontFamily: 'Orbitron',
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pause → Upgrade feel review. Try each family, then use it.\n'
              'Settings control Reduced Motion, sound and Haptics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xffb4bcaa),
                fontFamily: 'Orbitron',
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final arena in ArenaType.values)
                  for (final mode in UpgradeFeelMode.values)
                    ClickButton(
                      text:
                          '${arena.name} / ${['Original', '750ms', '1100ms'][mode.index]}',
                      width: 250,
                      height: 64,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BaseView(
                            loadout: Loadout(
                              training: true,
                              arena: arena,
                              weapon: WeaponType.carbine,
                            ),
                            upgradeFeelMode: mode,
                            upgradeFeelReview: true,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
