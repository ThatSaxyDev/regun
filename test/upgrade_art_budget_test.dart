import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/upgrade_art.dart';
import 'package:regun/presentation/support_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Rook activation, largest pair, every equipped weapon and active supports fit 32MiB', () async {
    final art = RegunArt.shared;
    await art.load();
    final extras = [
      ...UpgradeArtLease.familyAtlases.values,
      'bosses/marshal',
      'bosses/sovereign',
      ...SupportArt.atlases,
      'arenas/supply_pod',
      'effects/landing_dust',
      'effects/cinder_flame',
      'effects/status_flame',
    ];
    final held = <String>[];
    var peak = 0;
    String? largest;
    try {
      for (final key in extras) {
        await art.acquire(key);
        held.add(key);
      }
      for (final survivor in CharacterType.values) {
        await art.acquireSurvivor(survivor.name);
        for (final w in WeaponType.values) {
          await art.acquire(w.atlasName);
          if (art.decodedBytes > peak) {
            peak = art.decodedBytes;
            largest = '${survivor.name}/${w.name}';
          }
          expect(
            art.decodedBytes,
            lessThanOrEqualTo(32 * 1024 * 1024),
            reason: '${survivor.name}/${w.name}',
          );
          art.release(w.atlasName);
        }
        art.releaseSurvivor(survivor.name);
      }
      await Directory('build/upgrade-feel-audit').create(recursive: true);
      await File('build/upgrade-feel-audit/art-budget.json').writeAsString(
        jsonEncode({
          'peakBytes': peak,
          'limitBytes': 32 * 1024 * 1024,
          'largestEquippedWeapon': largest,
          'scope': 'decoded art only; not allocation spikes, frame time or device performance',
        }),
      );
    } finally {
      for (final key in held.reversed) {
        art.release(key);
      }
    }
  });
}
