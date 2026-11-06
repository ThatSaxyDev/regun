import 'dart:async';
import 'dart:convert';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}

  @override
  Future<void> playMusic(String theme) async {}
}

// A valid 1x1 transparent PNG. Atlas metadata supplies the frame rects, so
// decoding a tiny image exercises the real load path without the arena-sized
// texture upload that stalls Chrome.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUA'
  'AXpeqz8AAAAASUVORK5CYII=',
);

const _layout = '''
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down"
  width="141" height="141" tilewidth="32" tileheight="32"
  infinite="0" nextlayerid="16" nextobjectid="325">
 <objectgroup name="breach_obstacles"/>
 <objectgroup name="foundry_obstacles"/>
 <objectgroup name="floodworks_obstacles"/>
 <objectgroup name="relayGraveyard_obstacles"/>
 <objectgroup name="foundry_vents">
  <object id="1" x="2200" y="2200" width="32" height="32"/>
 </objectgroup>
</map>
''';

const _atlasNames = <String>[
  'characters/rook_run',
  'characters/scrapper_run',
  'characters/warden_run',
  'characters/rook_actions',
  'characters/scrapper_actions',
  'characters/warden_actions',
  'characters/rook',
  'characters/scrapper',
  'characters/warden',
  'enemies/scorpion',
  'enemies/mummy',
  'enemies/ranged',
  'enemies/runner',
  'enemies/shield',
  'enemies/burster',
  'enemies/nest',
  'enemies/sentinel',
  'bosses/shadow',
  'bosses/demon',
  'bosses/queen',
  'items/items',
  'weapons/arsenal',
  'arenas/props',
  'effects/combat_materials',
  'bosses/bellkeeper',
  'bosses/magistrate',
  'bosses/saint',
  'bosses/sovereign',
  'bosses/marshal',
  'arenas/breach_floor',
  'arenas/foundry_floor',
  'arenas/supply_pod',
  'effects/landing_dust',
  'arenas/multiplayer_walls',
  'arenas/multiplayer_walls_hd',
  'items/grenade',
  'enemies/ranged_remains',
  'effects/ground_motion',
  'effects/marshal_aim',
  'characters/scrapper_left_run',
  'weapons/burst_rifle',
  'weapons/rail_lance',
  'weapons/rivet_driver',
  'weapons/cinder_hose',
  'weapons/reaper_disc',
  'weapons/frost_shotgun',
  'weapons/prism_cutter',
  'weapons/spore_lobber',
  'weapons/scrap_mortar',
  'weapons/belt_repeater',
  'weapons/longwatch_sniper',
  'effects/cinder_flame',
  'effects/grounded_ordnance',
  'effects/grounded_areas',
  'enemies/burster_walk',
  'weapons/twin_verdict',
  'weapons/flak_regent',
  'weapons/anchor_engine',
  'weapons/faultline_driver',
  'weapons/cyclone_breacher',
  'weapons/mourning_bell',
  'characters/flint',
  'characters/vesper',
  'characters/moth',
  'characters/coil',
  'characters/suture',
  'characters/harrow',
  'characters/fuse_run',
  'characters/fuse',
  'characters/flint_left_run',
  'characters/vesper_left_run',
  'characters/fuse_left_run',
  'characters/moth_left_run',
  'characters/coil_left_run',
  'characters/suture_left_run',
  'characters/harrow_left_run',
  'enemies/mummy_walk',
  'weapons/houndrack',
  'weapons/storm_orb',
  'weapons/ring_caster',
  'effects/cutter_ring',
  'support/base',
  'support/carbine',
  'support/burstRifle',
  'support/aura',
  'support/emitter',
  'upgrades/rook_fit',
  'upgrades/rook_infusion',
  'upgrades/rook_fleet',
  'upgrades/rook_armour',
  'upgrades/rook_ember',
  'upgrades/rook_ricochet',
  'upgrades/rook_sentry',
  'effects/status_flame',
  'arenas/floodworks_floor',
  'arenas/relayGraveyard_floor',
  'arenas/district_evacuation',
  'arenas/district_press',
  'arenas/district_sluice',
  'arenas/district_relay',
  'arenas/sluice_water',
  'effects/ballistic_flash',
  'effects/frost_flash',
  'arenas/foundry_cart',
  'arenas/foundry_cart_lamps',
];

const _nonLazy = <String>{
  'enemies/scorpion',
  'enemies/mummy',
  'enemies/ranged',
  'enemies/runner',
  'enemies/shield',
  'enemies/burster',
  'enemies/nest',
  'enemies/sentinel',
  'bosses/shadow',
  'bosses/demon',
  'bosses/queen',
  'items/items',
  'weapons/arsenal',
  'arenas/props',
  'effects/combat_materials',
  'arenas/breach_floor',
  'arenas/foundry_floor',
  'arenas/multiplayer_walls',
  'items/grenade',
  'enemies/ranged_remains',
  'effects/ground_motion',
  'effects/marshal_aim',
  'effects/grounded_ordnance',
  'effects/grounded_areas',
  'enemies/burster_walk',
  'enemies/mummy_walk',
  'arenas/floodworks_floor',
  'arenas/relayGraveyard_floor',
  'arenas/district_evacuation',
  'arenas/district_press',
  'arenas/district_sluice',
  'arenas/district_relay',
  'arenas/sluice_water',
  'effects/ballistic_flash',
  'effects/frost_flash',
  'arenas/foundry_cart',
  'arenas/foundry_cart_lamps',
};

final _manifest = jsonEncode({
  for (final name in _atlasNames)
    name: {
      'columns': 8,
      'rows': 8,
      'decodeWidth': 64,
      'height': .2,
      'frames': [
        for (var frame = 0; frame < 64; frame++)
          {
            'rect': [.01, .01, .1, .2],
            'pivot': .5,
          },
      ],
      if (!_nonLazy.contains(name)) 'lazy': true,
    },
});

ByteData _bytes(String value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));

void main() {
  // Chrome's test runner drops Flutter's exception log, so surface the real
  // failure instead of the generic "See exception logs above".
  reportTestException = (details, description) {
    Zone.current.handleUncaughtError(
      'REPORTED DETAILS:\n${details.toString()}\nSTACK:\n${details.stack}',
      details.stack ?? StackTrace.empty,
    );
  };

  testWidgets('web boss arrival keeps combat moving while the atlas loads', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    void collect(FlutterErrorDetails details) => errors.add(details);
    FlutterError.onError = collect;
    addTearDown(() => FlutterError.onError = previousOnError);
    void check() {
      final captured = List<FlutterErrorDetails>.of(errors);
      FlutterError.onError = previousOnError;
      expect(
        captured,
        isEmpty,
        reason: captured.map((error) => error.toString()).join('\n---\n'),
      );
      FlutterError.onError = collect;
    }

    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final assetManifestData = <String, Object?>{
      for (final name in _atlasNames)
        'assets/art/$name.png': <Object?>[
          <String, Object?>{'asset': 'assets/art/$name.png'},
        ],
      'assets/images/heart.png': <Object?>[
        <String, Object?>{'asset': 'assets/images/heart.png'},
      ],
    };
    final assetManifestBytes = const StandardMessageCodec().encodeMessage(
      assetManifestData,
    )!;
    final assetManifest = jsonEncode(
      base64Encode(
        assetManifestBytes.buffer.asUint8List(
          assetManifestBytes.offsetInBytes,
          assetManifestBytes.lengthInBytes,
        ),
      ),
    );

    final bossAtlas = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final path = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (path == 'AssetManifest.bin.json') return _bytes(assetManifest);
      if (path == 'AssetManifest.json' || path == 'FontManifest.json') {
        return _bytes('{}');
      }
      if (path == 'assets/art/manifest.json') return _bytes(_manifest);
      if (path == 'assets/tiles/maptile.tmx') return _bytes(_layout);
      if (path == 'assets/art/bosses/magistrate.png') await bossAtlas.future;
      if (path.endsWith('.png')) {
        return ByteData.sublistView(Uint8List.fromList(_pixel));
      }
      return null;
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(home: BaseView()),
        ),
      );
      game =
          tester
                  .widget<RiverpodAwareGameWidget>(
                    find.byType(RiverpodAwareGameWidget),
                  )
                  .game!
              as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
      }
    });
    check();

    expect(game.inputBlocked, isFalse);
    game.director.restore({
      'elapsed': 179.9,
      'spawnElapsed': 0.0,
      'nextBoss': 180.0,
      'recoveryUntil': 0.0,
      'bossActive': false,
      'bossesDefeated': 0,
      'bossBag': ['magistrate'],
      'lastBoss': null,
    });

    await tester.runAsync(() async {
      game.update(.2);
      game.update(1 / 60);
      expect(game.bossReveal.active, isTrue);
      expect(game.bossReveal.actors.single.isMounted, isFalse);
      expect(game.inputBlocked, isFalse);
      check();

      final before = game.director.elapsed;
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      expect(
        game.director.elapsed,
        greaterThan(before + 1.5),
        reason:
            'combat time must keep advancing while the boss atlas downloads',
      );
      expect(game.inputBlocked, isFalse);
      expect(game.bossReveal.actors.single.isMounted, isFalse);
      check();

      bossAtlas.complete();
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        if (i % 5 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        if (game.bossReveal.actors.single.isMounted) break;
      }
      expect(game.bossReveal.actors.single.isMounted, isTrue);
      expect(
        game.inputBlocked,
        isTrue,
        reason: 'the normal entrance resumes once the boss is ready',
      );

      for (var i = 0; i < 240; i++) {
        game.update(1 / 60);
      }
      check();
    });

    expect(game.bossReveal.active, isFalse);
    expect(game.inputBlocked, isFalse);
    expect(game.activeBoss, isNotNull);
    expect(game.director.bossActive, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    check();
  }, skip: !kIsWeb);
}
