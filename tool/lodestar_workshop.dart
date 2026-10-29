// Development-only: flutter run -t tool/lodestar_workshop.dart
// No network/auth/update services, run state or production menu registration.
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/lodestar_workshop_view.dart';
import 'package:regun/widgets/click_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.setLandscape();
  await Flame.device.fullScreen();
  await LocalPreferences.shared.load();
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: false),
        home: const _Launcher(),
      ),
    ),
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff161B18),
    body: Center(
      child: ClickButton(
        text: 'Lodestar construction',
        width: 320,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LodestarWorkshopView()),
        ),
      ),
    ),
  );
}
