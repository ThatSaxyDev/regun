import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/upgrade_art.dart';

class _DelayedArt extends RegunArt {
  final loads = <Completer<void>>[];
  int owners = 0;
  @override
  Future<void> acquire(String name) async {
    owners++;
    final c = Completer<void>();
    loads.add(c);
    try {
      await c.future;
    } catch (_) {
      owners--;
      rethrow;
    }
  }

  @override
  void release(String name) {
    owners--;
  }

  @override
  bool contains(String name) => owners > 0;
}

void main() {
  test(
    'pending art releases on disposal; restart keeps only its new lease',
    () async {
      final art = _DelayedArt(), lease = UpgradeArtLease(art: null);
      lease.clear();
      final owner = UpgradeArtLease(art: art);
      owner.prewarm();
      expect(art.owners, 1);
      owner.clear();
      owner.prewarm();
      art.loads[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(art.loads.length, 2);
      expect(art.owners, 1);
      expect(owner.ready, isFalse);
      art.loads[1].complete();
      await Future<void>.delayed(Duration.zero);
      expect(owner.ready, isTrue);
      owner.clear();
      expect(art.owners, 0);
    },
  );
  test(
    'load failure leaves a steady-pose fallback and can retry next picker',
    () async {
      final art = _DelayedArt(), owner = UpgradeArtLease(art: _DelayedArt());
      owner.clear();
      final lease = UpgradeArtLease(art: art);
      lease.prewarm();
      art.loads[0].completeError(StateError('decode failed'));
      await Future<void>.delayed(Duration.zero);
      expect(lease.ready, isFalse);
      expect(art.owners, 0);
      lease.prewarm();
      art.loads[1].complete();
      await Future<void>.delayed(Duration.zero);
      expect(lease.ready, isTrue);
      lease.clear();
      expect(art.owners, 0);
    },
  );
  test('switching offered recipes releases pending retired art only', () async {
    final art = _DelayedArt(), lease = UpgradeArtLease(art: _DelayedArt());
    lease.clear();
    final owner = UpgradeArtLease(art: art);
    owner.prewarm(['hotShot', 'ricochet']);
    expect(art.owners, 2);
    owner.prewarm(['ricochet']);
    art.loads[0].complete();
    art.loads[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(owner.readyFor('hotShot'), isFalse);
    expect(owner.readyFor('ricochet'), isTrue);
    expect(art.owners, 1);
    owner.clear();
    expect(art.owners, 0);
  });
}
