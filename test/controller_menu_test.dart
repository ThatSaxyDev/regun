import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/desktop/controller_device.dart';
import 'package:regun/desktop/controller_menu.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/home_menu.dart';

class _MenuAudio extends SoloudPlay {
  final cues = <String>[];
  @override
  Future<void> play(String asset) async => cues.add(asset);
}

class _Pads {
  List<ControllerDevice>? devices = [];

  ControllerDevice pad([int? button, String id = 'xbox']) => ControllerDevice(
    id,
    id == 'xbox' ? 'Xbox Wireless Controller' : 'DualSense',
    List<double>.generate(20, (i) => i == (button ?? 20) + 4 ? 1 : 0),
  );

  Future<void> frame(
    WidgetTester tester, [
    int? button,
    Duration elapsed = const Duration(milliseconds: 17),
  ]) async {
    devices = [pad(button)];
    await tester.pump(elapsed);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, int button) async {
    await frame(tester, button);
    await frame(tester);
  }

  Widget app(Widget home, _MenuAudio audio) => ProviderScope(
    overrides: [soloudPlayProvider.overrideWithValue(audio)],
    child: MaterialApp(
      builder: (_, child) =>
          DesktopController(readDevices: () async => devices, child: child!),
      home: home,
    ),
  );
}

bool _focused(Finder finder, WidgetTester tester) {
  final focus = FocusManager.instance.primaryFocus?.context;
  var result = false;
  tester.element(finder).visitAncestorElements((ancestor) {
    result = identical(ancestor, focus);
    return !result;
  });
  return result;
}

void main() {
  testWidgets(
    'connection notices and input reset distinguish suspension and loss',
    (tester) async {
      final pads = _Pads()..devices = [];
      final audio = _MenuAudio();
      var taps = 0;
      final interruptions = <bool>[];
      bool observe(ControllerFrame? frame, {bool disconnected = false}) {
        if (frame == null) interruptions.add(disconnected);
        return false;
      }

      DesktopController.handlers.add(observe);
      addTearDown(() => DesktopController.handlers.remove(observe));
      await tester.pumpWidget(
        pads.app(
          Scaffold(
            body: ClickButton(
              text: 'Action',
              autofocus: true,
              onTap: () => taps++,
            ),
          ),
          audio,
        ),
      );
      await pads.frame(tester, 0);
      expect(
        find.text('Controller connected · Xbox Wireless Controller'),
        findsOneWidget,
      );
      expect(taps, 0);
      await pads.frame(tester);
      await pads.press(tester, 0);
      expect(taps, 1);
      expect(audio.cues, ['click.mp3']);

      pads.devices = null;
      await tester.pump(const Duration(milliseconds: 20));
      expect(interruptions, [false]);
      await pads.frame(tester, 0);
      expect(taps, 1);
      await pads.frame(tester);
      pads.devices = [pads.pad(null, 'dual'), pads.pad()];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Controller connected · DualSense'), findsOneWidget);
      expect(interruptions, [false]);
      pads.devices = [pads.pad(0, 'dual'), pads.pad()];
      await tester.pump(const Duration(milliseconds: 20));
      expect(taps, 1, reason: 'The first pad keeps ownership');

      pads.devices = [pads.pad(0, 'dual')];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(interruptions, [false, true]);
      expect(
        find.text('Controller disconnected · Xbox Wireless Controller'),
        findsOneWidget,
      );
      expect(taps, 1, reason: 'The replacement must first go neutral');
      pads.devices = [pads.pad(null, 'dual')];
      await tester.pump(const Duration(milliseconds: 20));
      pads.devices = [pads.pad(0, 'dual')];
      await tester.pump(const Duration(milliseconds: 20));
      expect(taps, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'menu steps, held repeat, slider and Back use one cue per action',
    (tester) async {
      final pads = _Pads()..devices = [_Pads().pad()];
      final audio = _MenuAudio();
      var opens = 0, returns = 0;
      var volume = .5;
      await tester.pumpWidget(
        pads.app(
          Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ClickButton(text: 'First', autofocus: true, onTap: () {}),
                  const ClickButton(text: 'Disabled'),
                  ClickButton(text: 'Second', onTap: () {}),
                  ClickButton(
                    text: 'Open',
                    onTap: () {
                      opens++;
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Settings panel'),
                          content: StatefulBuilder(
                            builder: (context, change) => ControllerMenuScope(
                              onBack: () {
                                returns++;
                                Navigator.of(context).pop();
                              },
                              child: ControlSlider(
                                label: 'Sound',
                                value: volume,
                                minimum: 0,
                                maximum: 1,
                                onChanged: (value) =>
                                    change(() => volume = value),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) => ControllerMenuMode.of(context)
                        ? const Text('Controller mode active')
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          audio,
        ),
      );
      await pads.frame(tester);
      expect(_focused(find.text('FIRST'), tester), isTrue);
      await pads.frame(tester, 13);
      expect(_focused(find.text('SECOND'), tester), isTrue);
      await pads.frame(tester, 13, const Duration(milliseconds: 150));
      expect(_focused(find.text('SECOND'), tester), isTrue);
      await pads.frame(tester, 13, const Duration(milliseconds: 190));
      expect(_focused(find.text('OPEN'), tester), isTrue);
      await pads.frame(tester, 13, const Duration(milliseconds: 130));
      expect(_focused(find.text('OPEN'), tester), isTrue);
      expect(audio.cues, ['menu_move.wav', 'menu_move.wav']);
      expect(find.text('Controller mode active'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await pads.frame(tester, 13, const Duration(milliseconds: 130));
      expect(find.text('Controller mode active'), findsNothing);

      await pads.press(tester, 0);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(opens, 1);
      expect(find.text('Settings panel'), findsOneWidget);
      await pads.press(tester, 15);
      expect(volume, closeTo(.55, .001));
      expect(audio.cues.last, 'menu_move.wav');
      await pads.press(tester, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(returns, 1);
      expect(find.text('Settings panel'), findsNothing);
      expect(_focused(find.text('OPEN'), tester), isTrue);
      expect(audio.cues, [
        'menu_move.wav',
        'menu_move.wav',
        'click.mp3',
        'menu_move.wav',
        'menu_back.wav',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'home to loadout tabs and a separate arena preview with controller',
    (tester) async {
      final pads = _Pads()..devices = [_Pads().pad()];
      final audio = _MenuAudio();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        pads.app(
          Scaffold(
            body: Builder(
              builder: (context) => HomeMenu(
                ready: true,
                reducedMotion: true,
                onPlay: () {},
                onOnline: () {},
                onTraining: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoadoutView(training: true),
                  ),
                ),
                onCollection: () {},
                onSettings: () {},
              ),
            ),
          ),
          audio,
        ),
      );
      await pads.frame(tester);
      expect(_focused(find.text('PLAY'), tester), isTrue);
      final settingsPosition = tester.getTopLeft(
        find.byKey(const Key('home-settings')),
      );
      await pads.press(tester, 13);
      expect(find.textContaining('D-pad'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('home-settings'))),
        settingsPosition,
      );
      await pads.press(tester, 13);
      expect(_focused(find.text('TRAINING'), tester), isTrue);
      await pads.press(tester, 0);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(LoadoutView), findsOneWidget);
      expect(_focused(find.text('SURVIVOR'), tester), isTrue);
      await pads.press(tester, 15);
      await pads.press(tester, 0);
      expect(find.text('Armory'), findsOneWidget);
      await pads.press(tester, 15);
      await pads.press(tester, 0);
      expect(find.text('Arena routes'), findsOneWidget);
      await pads.press(tester, 13);
      expect(find.text('ARENA PREVIEW'), findsOneWidget);
      final before = tester
          .widget<Text>(find.byKey(const Key('loadout-summary')))
          .data;
      expect(before, contains('Breach'));
      await pads.press(tester, 0);
      final after = tester
          .widget<Text>(find.byKey(const Key('loadout-summary')))
          .data;
      expect(after, isNot(before));
      await pads.press(tester, 1);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LoadoutView), findsNothing);
      expect(_focused(find.text('TRAINING'), tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    // Exercise the full atlas-backed catalog in the native widget harness.
    skip: kIsWeb,
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
