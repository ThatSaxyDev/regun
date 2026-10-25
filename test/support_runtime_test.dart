import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';

final values = <String, num>{
  ...LiveBalance.bundled.values,
  'support.sentry.enabled': 1,
  'support.aura.enabled': 1,
};

class Harness {
  Harness({Map<String, num>? overrides})
    : config = SupportConfig({...values, ...?overrides});
  final progress = SupportProgress(), runtime = SupportRuntime();
  final SupportConfig config;
  Offset player = Offset.zero;
  List<SupportTarget> targets = [];
  bool occluded = false;
  bool capacity = true;
  final List<String> events = [];
  final List<double> shots = [];
  double damage = 0;
  void grant(SupportCard c) {
    progress.offer = c;
    expect(progress.confirm(c.id), true);
  }

  void advance(double seconds, {double hz = 60}) {
    var left = seconds;
    while (left > 1e-8) {
      final dt = left < 1 / hz ? left : 1 / hz;
      left -= dt;
      runtime.advance(
        dt,
        player: player,
        progress: progress,
        config: config,
        targets: () => targets,
        place: (p, u) => p,
        blocked: (a, b, u) => occluded,
        impact: (u, breaking) =>
            events.add(breaking ? 'impact_break' : 'impact_land'),
        release: (u, p, d, damage) {
          if (!capacity) return false;
          shots.add(damage);
          return true;
        },
        auraHit: (t, d) => damage += d,
        cue: (u, c) => events.add(c),
      );
    }
  }
}

void main() {
  test('both supply families progress to VIII, repeat VIII and restore old III saves', () {
    for (final family in SupportFamily.values) {
      var p = SupportProgress();
      final config = SupportConfig({
        ...values,
        'support.${family == SupportFamily.sentry ? 'aura' : 'sentry'}.enabled':
            0,
      });
      for (var selection = 1; selection <= 10; selection++) {
        final card = p.roll(config, () => 0)!;
        expect(card.tier, min(selection, 8));
        expect(p.confirm(card.id), true);
        p = SupportProgress.restore(jsonDecode(jsonEncode(p.toJson())));
        expect(p.tiers[family.name], min(selection, 8));
        p.pending.clear();
        p.busy.clear();
      }
      expect(SupportCard(family, 8).rankLabel, 'VIII');
      expect(
        SupportCard.read(
          'support:${family.name}:9:${family == SupportFamily.sentry ? 'carbine' : 'field'}',
        ),
        isNull,
      );
      final old = SupportProgress()
        ..serial = 3
        ..tiers[family.name] = 3;
      final restored = SupportProgress.restore(old.toJson());
      expect(restored.roll(config, () => 0)!.tier, 4);
    }
  });
  test(
    'old tuned III snapshots get monotone bounded higher-tier fallbacks',
    () {
      const c = SupportConfig({
        'support.sentry.life3': 60,
        'support.sentry.damage3': 6,
        'support.aura.life3': 60,
        'support.aura.radius3': 220,
        'support.aura.damage3': 1,
      });
      expect(c.sentryLife(8), 75);
      expect(c.multiplier(8), 6);
      expect(c.auraLife(8), 60);
      expect(c.auraRadius(8), 220);
      expect(c.auraDamage(8), 1);
    },
  );
  test('support competes with ordinary-only hands at weight two', () {
    final random = Random(7025), counts = <String, int>{};
    for (var i = 0; i < 12000; i++) {
      final card = SupportProgress().roll(
        SupportConfig(values),
        random.nextDouble,
      );
      final key = card?.family.name ?? 'ordinary';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    expect(counts['ordinary'], inInclusiveRange(5700, 6300));
    for (final key in ['sentry', 'aura']) {
      expect(counts[key], inInclusiveRange(2700, 3300));
    }
    final one = SupportConfig({...values, 'support.aura.enabled': 0});
    var ordinary = 0;
    for (var i = 0; i < 10000; i++) {
      if (SupportProgress().roll(one, random.nextDouble) == null) ordinary++;
    }
    expect(ordinary, inInclusiveRange(6400, 7000));
    expect(SupportProgress().roll(SupportConfig(values), () => .99), isNull);
  });
  test('called supply hands retain three choices with or without support', () {
    final previous = BalanceRepository.shared.current;
    BalanceRepository.shared.current = LiveBalance.create(1, values);
    addTearDown(() => BalanceRepository.shared.current = previous);
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final n = scope.read(gameNotifierProvider.notifier);
    var ordinary = 0, supported = 0;
    for (var seed = 1; seed <= 120; seed++) {
      n.resetRun(seed: seed);
      expect(n.offerSupplyUpgrade(), true);
      final count = scope.read(gameNotifierProvider).powerUpChoices.length;
      if (n.support.offer == null) {
        ordinary++;
        expect(count, 3);
      } else {
        supported++;
        expect(count, 2);
      }
    }
    expect(ordinary, greaterThan(15));
    expect(supported, greaterThan(40));
  });
  test(
    'terminal cleanup resets the phase and rejects impossible saved tiers',
    () {
      final h = Harness()..grant(const SupportCard(SupportFamily.aura, 1));
      h.advance(.42);
      expect(h.runtime.tickClock, greaterThan(0));
      final saved = jsonDecode(jsonEncode(h.progress.toJson()));
      saved['tiers']['aura'] = 3;
      expect(() => SupportProgress.restore(saved), throwsFormatException);
      h.runtime.clear(h.progress);
      expect(h.runtime.tickClock, 0);
      expect(h.runtime.frameOffset, 0);
      expect(h.runtime.units, isEmpty);
      expect(h.progress.busy, isEmpty);
    },
  );

  test('supply-only selection is issued-hand bound and leaves permanent ranks/XP alone', () {
    final previous = BalanceRepository.shared.current;
    BalanceRepository.shared.current = LiveBalance.create(1, values);
    addTearDown(() => BalanceRepository.shared.current = previous);
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final n = scope.read(gameNotifierProvider.notifier);
    n.resetRun(seed: 41);
    expect(n.offerSupplyUpgrade(), true);
    final before = scope.read(gameNotifierProvider), card = n.support.offer!;
    expect(before.powerUpChoices.length, 2);
    n.chooseSupport(card.id, offerId: before.offerId + 1);
    expect(n.support.pending, isEmpty);
    n.chooseSupport(card.id, offerId: before.offerId);
    n.chooseSupport(card.id, offerId: before.offerId);
    final after = scope.read(gameNotifierProvider);
    expect(n.support.pending.length, 1);
    expect(n.support.serial, 1);
    expect(after.xP, before.xP);
    expect(after.currentLevel, before.currentLevel);
    expect(after.ranks, before.ranks);
    expect(n.upgradeConfirmed.value, 1);
    final checkpoint = n.checkpoint();
    n.restoreCheckpoint(checkpoint);
    expect(n.support.pending.single.id, card.id);
  });
  test(
    'bans/rerolls keep support supply-only; both busy fall back to ordinary',
    () {
      final p = SupportProgress();
      final c = SupportConfig(values);
      p.roll(c, () => 0);
      expect(p.offer!.family, SupportFamily.sentry);
      p.banned.add('sentry');
      p.roll(c, () => 0);
      expect(p.offer!.family, SupportFamily.aura);
      p.busy.add('aura');
      expect(p.roll(c, () => 0), isNull);
      expect(p.roll(const SupportConfig({}), () => 0), isNull);
    },
  );
  test(
    'follow, lock, full warning, landing, deploy, battery and one breakup',
    () {
      final h = Harness()..grant(const SupportCard(SupportFamily.sentry, 1));
      h.advance(3);
      h.player = const Offset(100, 20);
      h.advance(.55);
      final u = h.runtime.units.single;
      expect(u.phase, 'warning');
      expect(u.position, h.player);
      h.player = const Offset(600, 600);
      h.advance(1.8);
      expect(u.phase, 'falling');
      h.advance(.65);
      expect(u.solid, true);
      expect(h.events.where((s) => s == 'impact_land').length, 1);
      h.advance(.55);
      expect(u.phase, 'active');
      expect(u.life, closeTo(0, .03));
      h.advance(36);
      expect(u.phase, 'breaking');
      expect(u.solid, false);
      h.advance(1.3);
      expect(h.runtime.units, isEmpty);
      expect(h.events.where((s) => s == 'impact_break').length, 1);
      expect(h.progress.busy, isEmpty);
    },
  );
  test('commit while legal, wait briefly behind cover, then select reachable fallback', () {
    final h = Harness()..grant(const SupportCard(SupportFamily.sentry, 1));
    h.advance(6.55);
    h.targets = [const SupportTarget('a', Offset(300, -42), 20)];
    h.advance(.5);
    final u = h.runtime.units.single;
    expect(u.target, 'a');
    h.targets = [...h.targets, const SupportTarget('b', Offset(120, -42), 20)];
    h.advance(.6);
    expect(u.target, 'a');
    h.occluded = true;
    final shots = h.shots.length;
    h.advance(.9);
    expect(u.target, 'a');
    expect(h.shots.length, shots);
    h.occluded = false;
    h.targets = [
      const SupportTarget('a', Offset(900, -42), 20),
      const SupportTarget('b', Offset(120, -42), 20),
    ];
    h.advance(.15);
    expect(u.target, 'b');
    h.targets = [];
    h.advance(.2);
    expect(u.target, isNull);
  });
  for (final mount in ['carbine', 'burstRifle']) {
    test('$mount fires through old magazine boundaries with no reload', () {
      final h = Harness()
        ..grant(SupportCard(SupportFamily.sentry, 1, mount: mount));
      h.advance(6.55);
      final u = h.runtime.units.single;
      u.ammo = 0;
      u.reload = 10; // Simulate a legacy saved empty magazine.
      h.targets = [const SupportTarget('a', Offset(300, -42), 20)];
      h.advance(12);
      expect(h.shots.length, greaterThan(mount == 'carbine' ? 100 : 50));
      expect(u.ammo, -1);
      expect(u.reload, 0);
      expect(h.events, isNot(contains('reload')));
      for (var i = 1; i < h.shots.length; i++) {
        expect(
          h.shots[i] - h.shots[i - 1],
          lessThan(mount == 'carbine' ? .13 : .65),
        );
      }
    });
  }
  test('burst rounds are separate; saturation spends no ammo; restart never detonates', () {
    final h = Harness()
      ..grant(const SupportCard(SupportFamily.sentry, 1, mount: 'burstRifle'));
    h.advance(6.55);
    h.targets = [const SupportTarget('a', Offset(300, -42), 20)];
    h.capacity = false;
    h.advance(.6);
    final u = h.runtime.units.single;
    expect(u.ammo, -1);
    expect(h.shots, isEmpty);
    h.capacity = true;
    h.advance(.025);
    expect(h.shots.length, 1);
    h.advance(.075);
    expect(h.shots.length, 1);
    h.advance(.025);
    expect(h.shots.length, 2);
    h.advance(.1);
    expect(h.shots.length, 3);
    h.runtime.clear(h.progress);
    expect(h.events.where((e) => e == 'break'), isEmpty);
  });
  for (final hz in [30.0, 60.0, 120.0]) {
    test('aura exact fixed ticks and expiry at ${hz.toInt()}Hz', () {
      final h = Harness()..grant(const SupportCard(SupportFamily.aura, 1));
      h.targets = [const SupportTarget('a', Offset(50, 0), 20)];
      h.advance(.35, hz: hz);
      expect(h.damage, 0);
      h.advance(2, hz: hz);
      expect(h.damage, closeTo(3.0, 1e-7));
      h.occluded = true;
      h.advance(1, hz: hz);
      expect(h.damage, closeTo(3.0, 1e-7));
      h.occluded = false;
      h.advance(20, hz: hz);
      expect(h.runtime.units, isEmpty);
      final d = h.damage;
      h.advance(1, hz: hz);
      expect(h.damage, d);
    });
  }
  test(
    'every incoming phase restores without replaying a landed/broken receipt',
    () {
      for (final age in [.5, 3.8, 5.5, 6.2, 7.0, 30.7]) {
        final h = Harness()..grant(const SupportCard(SupportFamily.sentry, 1));
        h.advance(age);
        final state = jsonDecode(jsonEncode(h.runtime.toJson()));
        final progress = SupportProgress.restore(
          jsonDecode(jsonEncode(h.progress.toJson())),
        );
        final runtime = SupportRuntime()..restore(state, progress, h.config);
        expect(runtime.toJson(), h.runtime.toJson());
        state['units'][0]['landed'] = !(state['units'][0]['landed'] as bool);
        expect(
          () => SupportRuntime().restore(state, progress, h.config),
          throwsFormatException,
        );
      }
    },
  );
  for (final family in SupportFamily.values) {
    test(
      'fractional ${family.name} lifetime remains valid during expiry restore',
      () {
        final life = family == SupportFamily.aura ? 5.01 : 10.01;
        final h = Harness(overrides: {'support.${family.name}.life1': life})
          ..grant(SupportCard(family, 1));
        h.advance(family == SupportFamily.aura ? 5.5 : 16.8);
        expect(h.runtime.units.single.life, life);
        final state = jsonDecode(jsonEncode(h.runtime.toJson()));
        expect(
          () => SupportRuntime().restore(state, h.progress, h.config),
          returnsNormally,
        );
      },
    );
  }
  test('shared projections fixture matches admin/API contract', () {
    final fixture = jsonDecode(
      File('test/fixtures/support-projections-v1.json').readAsStringSync(),
    ) as Map;
    for (final row in fixture['cases'] as List) {
      expect(
        supportProjection(
          values,
          SupportFamily.values.byName(row['family']),
          mount: row['mount'],
        ),
        row['rows'],
      );
    }
  });
}
