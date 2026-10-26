import 'package:flutter_test/flutter_test.dart';
import 'package:regun/models/accepted_upgrade.dart';
import 'package:regun/presentation/upgrade_presentation.dart';
import 'package:regun/multiplayer/upgrade_receipts.dart';
import 'package:regun/multiplayer/combat_state.dart';

AcceptedUpgrade receipt({int serial = 1, int generation = 1}) =>
    AcceptedUpgrade(
      generation: generation,
      actor: 'solo',
      serial: serial,
      offerId: 1,
      source: 'xp',
      id: 'heavyLoad',
      beforeRank: 0,
      afterRank: 1,
      balance: 'pinned-hash',
      before: const {'Damage multiplier': 1},
      after: const {'Damage multiplier': 1.35},
    );
void main() {
  test('online impact waits for released authority, tolerates split snapshots, never replays', () {
    final ledger = OnlineUpgradeReceipts();
    OnlineGun gun(int serial, bool released, double age) => OnlineGun('solo', {
      'health': 6,
      'progress': {
        'acceptedReward': {
          ...receipt(serial: serial).toJson(),
          'generation': '1',
          'holdSerial': 1,
          'released': released,
          'activeAge': age,
        },
      },
    });
    final hold = OnlineMatch({
      'phase': 'confirmation',
      'confirmationSerial': 1,
    });
    final active = OnlineMatch({'phase': 'active', 'confirmationSerial': 1});
    ledger.sync('room:1', active, {'solo': gun(1, false, 1)});
    ledger.sync('room:1', hold, {'solo': gun(2, false, 0)});
    ledger.sync('room:1', active, {'solo': gun(2, false, 0)});
    expect(ledger.releasing, isEmpty);
    ledger.sync('room:1', active, {'solo': gun(2, true, .05)});
    expect(ledger.releasing['solo']?.serial, 2);
    ledger.advanceActive(.05);
    ledger.sync('room:1', active, {'solo': gun(2, true, .05)});
    expect(ledger.releaseAge('solo'), closeTo(.10, 1e-8));
    ledger.advanceActive(.2);
    expect(ledger.releasing, isEmpty);
    final reconnect = OnlineUpgradeReceipts();
    reconnect.sync('room:1', active, {'solo': gun(2, true, .05)});
    expect(reconnect.releasing, isEmpty);
  });

  test('absorption contains until release; impact is consumed once and never restored', () {
    final c = UpgradePresentationController(mode: UpgradeFeelMode.full);
    c.accept(receipt(), reducedMotion: false, rook: true);
    c.advanceHold(1.0);
    expect(c.frame, 5);
    expect(c.releaseImpact(), isFalse);
    c.advanceHold(.1);
    expect(c.releaseImpact(), isTrue);
    expect(c.releaseAge, 0);
    expect(c.frame, 6);
    expect(c.releaseImpact(), isFalse);
    c.advanceActive(.13);
    expect(c.frame, 7);
    c.advanceActive(.12);
    expect(c.releasing, isFalse);
    c.restoreStatic(receipt());
    expect(c.releaseImpact(), isFalse);
    expect(c.releasing, isFalse);
  });

  test('bounded presentation clock, deduplication, static restore and real-use expiry', () {
    final c = UpgradePresentationController(mode: UpgradeFeelMode.full);
    expect(c.accept(receipt(), reducedMotion: false, rook: true), isTrue);
    expect(c.duration, 1.1);
    c.advanceActive(100);
    expect(c.activeAge, 0);
    expect(c.observe('heavyLoad', 'hit'), isFalse);
    c.advanceHold(.2);
    expect(c.holding, isTrue);
    c.advanceHold(5);
    expect(c.holding, isFalse);
    expect(c.observe('hotShot', 'burn'), isFalse);
    expect(c.observe('heavyLoad', 'hit'), isTrue);
    expect(c.observe('heavyLoad', 'hit'), isFalse);
    expect(c.accept(receipt(), reducedMotion: false, rook: true), isFalse);
    c.restoreStatic(AcceptedUpgrade.read(receipt().toJson()));
    expect(c.holding, isFalse);
    expect(c.visible, isTrue);
    expect(c.firstUsePending, isFalse);
    expect(
      c.accept(receipt(serial: 2), reducedMotion: true, rook: true),
      isTrue,
    );
    expect(c.duration, .18);
    c.advanceHold(.18);
    c.advanceActive(20);
    expect(c.firstUsePending, isFalse);
    expect(c.observe('heavyLoad', 'late hit'), isFalse);
    expect(
      () => AcceptedUpgrade.read({
        ...receipt().toJson(),
        'after': {'x': double.nan},
      }),
      throwsFormatException,
    );
    expect(
      () => AcceptedUpgrade.read({...receipt().toJson(), 'id': 'unknown'}),
      throwsFormatException,
    );
  });
  test(
    'reconnect establishes watermark; retries and old holds cannot replay',
    () {
      final ledger = OnlineUpgradeReceipts();
      final match = OnlineMatch({
        'phase': 'confirmation',
        'confirmationSerial': 1,
      });
      OnlineGun gun(int serial, int hold) => OnlineGun('solo', {
        'progress': {
          'acceptedReward': {
            ...receipt(serial: serial).toJson(),
            'generation': '1',
            'holdSerial': hold,
          },
        },
      });
      ledger.sync('room:1', match, {'solo': gun(1, 1)});
      expect(ledger.active, isEmpty);
      ledger.sync('room:1', match, {'solo': gun(2, 1)});
      expect(ledger.active['solo']?.serial, 2);
      ledger.sync('room:1', OnlineMatch({'phase': 'active'}), {
        'solo': gun(2, 1),
      });
      expect(ledger.active, isEmpty);
      ledger.sync('room:1', match, {'solo': gun(2, 1)});
      expect(ledger.active, isEmpty);
      ledger.sync('room:2', match, {'solo': gun(3, 1)});
      expect(ledger.active, isEmpty);
    },
  );
  test(
    'a delayed real mechanic survives another selection but not a run change',
    () {
      final c = UpgradePresentationController(mode: UpgradeFeelMode.full);
      c.accept(receipt(), reducedMotion: false, rook: true);
      c.advanceHold(1.1);
      const hot = AcceptedUpgrade(
        generation: 1,
        actor: 'solo',
        serial: 2,
        offerId: 2,
        source: 'xp',
        id: 'hotShot',
        beforeRank: 0,
        afterRank: 1,
        balance: 'pinned',
        before: {'Burn per tick': 0},
        after: {'Burn per tick': .45},
      );
      c.accept(hot, reducedMotion: false, rook: true);
      c.advanceHold(1.1);
      expect(c.observe('heavyLoad', 'Stronger primary hit'), isTrue);
      expect(c.observe('hotShot', 'Burn applied'), isTrue);
      c.accept(
        receipt(serial: 1, generation: 2),
        reducedMotion: false,
        rook: true,
      );
      c.advanceHold(1.1);
      expect(c.observe('hotShot', 'old burn'), isFalse);
    },
  );
}
