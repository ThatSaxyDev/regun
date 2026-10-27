import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/leaderboards.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/leaderboard_view.dart';
import 'package:regun/widgets/home_menu.dart';

class Quiet extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
}

class FakeBoards extends Leaderboards {
  @override
  Future<void> flush() async {}
  @override
  Future<void> publishProfile() async {}
  @override
  Future<Map<String, dynamic>?> myEntry() async => null;
  bool offline = false, disabled = false;
  Completer<void>? pending;
  int topScore = 1234567;
  bool noHistory = false;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    await pending?.future;
    if (offline) throw StateError('Connect to load records.');
    if (path.endsWith('/config')) {
      return {'enabled': !disabled, 'rules': 'solo1-test', 'submissions': true};
    }
    if (path.contains('/public/')) {
      return {
        'name': 'AshRunner',
        'stats': {
          'bestScore': 1234567,
          'bestSeconds': 1122,
          'runs': 38,
          'kills': 8916,
          'bosses': 42,
          'weapons': noHistory
              ? {}
              : {
                  'carbine': {
                    'seconds': 8040,
                    'runs': 21,
                    'bestScore': 1234567,
                  },
                  'shotgun': {'seconds': 3000, 'runs': 7, 'bestScore': 604200},
                  'arcCaster': {'seconds': 900, 'runs': 4, 'bestScore': 28200},
                },
          'upgrades': noHistory
              ? {}
              : {
                  'heavyLoad': {'runs': 24, 'picks': 89},
                  'ricochet': {'runs': 18, 'picks': 25},
                  'hotShot': {'runs': 12, 'picks': 21},
                },
        },
        'best': noHistory
            ? null
            : {
                'score': 1234567,
                'seconds': 1122,
                'survivor': 'rook',
                'arena': 'breach',
                'weapon': 'carbine',
                'ranks': {'heavyLoad': 6},
                'fusions': [],
              },
      };
    }
    return {
      'entries': [
        {
          'rank': 1,
          'name': 'AshRunner',
          'publicId': '22222222-2222-4222-8222-222222222222',
          'score': topScore,
          'seconds': 1122,
          'runs': 38,
          'online': true,
          'weapon': 'carbine',
          'survivor': 'rook',
        },
        {
          'rank': 2,
          'name': 'Guest-12345678',
          'publicId': '33333333-3333-4333-8333-333333333333',
          'score': 2400,
          'runs': 4,
          'online': true,
        },
        {
          'rank': 3,
          'name': 'NewPlayer',
          'publicId': '44444444-4444-4444-8444-444444444444',
          'score': 0,
          'runs': 0,
          'online': false,
        },
      ],
      'nextCursor': null,
    };
  }
}

void main() {
  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> setup(
    WidgetTester tester,
    Widget child, {
    double width = 844,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final f in [
        ('PressStart2P', 'PressStart2P-Regular.ttf'),
        ('Orbitron', 'Orbitron-Regular.ttf'),
      ]) {
        await (FontLoader(
          f.$1,
        )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
      }
      await RegunArt.shared.load();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(47, 0, 47, 21),
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(key: const Key('capture'), child: child!),
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('landscape home keeps new entry reachable with Continue', (
    tester,
  ) async {
    await setup(
      tester,
      HomeMenu(
        ready: true,
        reducedMotion: true,
        onPlay: () {},
        onContinue: () {},
        onOnline: () {},
        onTraining: () {},
        onCollection: () {},
        onSettings: () {},
        onLeaderboards: () {},
      ),
    );
    expect(find.text('LEADERBOARDS').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'leaderboard-home-844x390');
  });
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('landscape board/profile navigation at text scale $scale', (
      tester,
    ) async {
      final service = FakeBoards();
      await setup(tester, LeaderboardView(service: service), scale: scale);
      expect(find.text('AshRunner').hitTestable(), findsOneWidget);
      expect(find.text('Guest-12345678'), findsOneWidget);
      expect(find.text('Playing'), findsNWidgets(2));
      expect(find.text('JOIN'), findsNothing);
      expect(find.text('WITHDRAW'), findsNothing);
      expect(tester.takeException(), isNull);
      if (scale == 1) await capture(tester, 'leaderboard-list-844x390');
      await tester.tap(find.text('AshRunner'));
      await tester.pumpAndSettle();
      expect(find.text('AshRunner'), findsOneWidget);
      expect(find.textContaining('tracking began'), findsNothing);
      expect(find.textContaining('Community records'), findsNothing);
      expect(tester.takeException(), isNull);
      if (scale == 1) await capture(tester, 'leaderboard-profile-844x390');
      await tester.tap(find.text('WEAPONS'));
      await tester.pumpAndSettle();
      expect(find.text('Most played'), findsOneWidget);
      if (scale == 1) await capture(tester, 'leaderboard-weapons-844x390');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('UPGRADES'));
      await tester.pumpAndSettle();
      expect(find.text('24 runs'), findsOneWidget);
      expect(find.text('89'), findsOneWidget);
      if (scale == 1) await capture(tester, 'leaderboard-upgrades-844x390');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      expect(find.text('AshRunner'), findsOneWidget);
    });
  }
  testWidgets(
    'returning to the board keeps rows visible during a silent refresh',
    (tester) async {
      final service = FakeBoards();
      await setup(tester, LeaderboardView(service: service));
      expect(find.text('1,234,567'), findsOneWidget);
      await setup(tester, const SizedBox());
      service.pending = Completer<void>();
      await setup(tester, LeaderboardView(service: service));
      expect(find.text('1,234,567'), findsOneWidget);
      expect(find.text('Guest-12345678'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      service.offline = true;
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('1,234,567'), findsOneWidget);
      expect(find.textContaining('Connect to load'), findsNothing);
      service.offline = false;
      service.pending = Completer<void>();
      service.topScore = 1234568;
      await tester.tap(find.text('REFRESH'));
      await tester.pump();
      expect(find.text('1,234,567'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('1,234,568'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'returning to a player retains stats while offline refresh completes',
    (tester) async {
      final service = FakeBoards();
      Widget profile() => PublicPlayerView(
        service: service,
        publicId: 'sample-player',
        board: 'global',
      );
      await setup(tester, profile());
      expect(find.text('8,916'), findsOneWidget);
      await setup(tester, const SizedBox());
      service.pending = Completer<void>();
      await setup(tester, profile());
      expect(find.text('8,916'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      service.offline = true;
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('8,916'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing breakdowns are history gaps, not claims of unused equipment',
    (tester) async {
      final service = FakeBoards()..noHistory = true;
      await setup(
        tester,
        PublicPlayerView(
          service: service,
          publicId: 'legacy-player',
          board: 'global',
        ),
      );
      expect(find.text('8,916'), findsOneWidget);
      await tester.tap(find.text('WEAPONS'));
      await tester.pumpAndSettle();
      expect(find.text('No weapon history.'), findsOneWidget);
      expect(find.text('No weapons yet.'), findsNothing);
      await tester.tap(find.text('UPGRADES'));
      await tester.pumpAndSettle();
      expect(find.text('No upgrade history.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('disabled and offline are never presented as an empty board', (
    tester,
  ) async {
    final s = FakeBoards()..disabled = true;
    await setup(tester, LeaderboardView(service: s));
    expect(find.text('Leaderboards unavailable.'), findsOneWidget);
    expect(find.text('No players yet.'), findsNothing);
    s.disabled = false;
    s.offline = true;
    await tester.tap(find.text('REFRESH'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connect to load'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
