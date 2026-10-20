// ignore_for_file: avoid_print
import 'dart:async';

import 'package:regun/multiplayer/online_session.dart';
import 'package:spacetimedb/spacetimedb.dart';

Future<void> until(bool Function() condition, String label) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('Timed out: $label');
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

Future<void> verifyVersus(int size) async {
  final players = List.generate(
    size * 2,
    (_) => OnlineSession(tokens: InMemoryTokenStore()),
  );
  try {
    for (final player in players) {
      await player.connect();
    }
    final host = players.first;
    await host.create(
      name: 'PvP host',
      mode: 'versus',
      teamSize: size,
      map: 'network_lab',
    );
    await until(() => host.room != null, 'PvP create');
    if (!host.room!.enemies) throw StateError('PvP must default enemies On');
    for (var i = 1; i < players.length; i++) {
      await players[i].join(host.room!.code, 'Player $i');
    }
    await until(() => host.members.length == size * 2, 'PvP roster');
    await host.enemies(false);
    if (host.error.isNotEmpty || !host.connected) {
      throw StateError(
        'Configure $size v $size: ${host.status}: ${host.error}',
      );
    }
    await until(() => host.room?.enemies == false, 'enemies option');
    for (final player in players) {
      await player.ready();
    }
    await until(() => host.canStart, 'balanced PvP readiness');
    await host.start();
    await until(() => players.every((p) => p.active), 'PvP active');
    for (final player in players.reversed) {
      await player.leave();
    }
    print(
      'PASS: Dart $size v $size room, balanced teams, enemies default/option, ready/start/leave',
    );
  } finally {
    for (final player in players) {
      await player.close();
    }
  }
}

Future<void> main() async {
  final a = OnlineSession(tokens: InMemoryTokenStore());
  final b = OnlineSession(tokens: InMemoryTokenStore());
  try {
    await a.connect();
    await b.connect();
    if (!a.connected || !b.connected) throw StateError('Connection failed');
    await a.create(name: 'Dart host', mode: 'coop', teamSize: 0, map: 'breach');
    await until(() => a.room != null, 'create');
    await b.join(a.room!.code, 'Dart friend');
    await until(
      () => a.members.length == 2 && b.members.length == 2,
      'members',
    );
    await a.ready();
    await b.ready();
    await until(() => a.canStart, 'ready');
    await a.start();
    await until(() => a.active && b.active, 'active');
    final startX = a.me!.x;
    a.moveX = 1;
    await until(() => a.me!.x > startX + 60, 'authoritative movement');
    a.neutral();
    a.dash();
    await until(() => a.me!.dashSeq > Int64.ZERO, 'dash action');
    await until(
      () => a.me!.pingAt.toInt() > 0 && b.me!.pingAt.toInt() > 0,
      'probe',
    );
    final identity = a.identity, generation = a.me!.generation;
    await a.suspend();
    await a.resume();
    await until(() => a.connected && a.me != null, 'reconnect');
    if (a.identity != identity || a.me!.generation <= generation) {
      throw StateError('Reconnect did not preserve identity/change generation');
    }
    if (a.moveX != 0 || a.moveY != 0) {
      throw StateError('Held movement survived reconnect');
    }
    a.dash();
    await until(() => a.me!.dashSeq > Int64.ZERO, 'dash after reconnect');
    await b.leave();
    await a.leave();
    await until(() => a.room == null && b.room == null, 'first room left');
    await a.create(
      name: 'Second room',
      mode: 'coop',
      teamSize: 0,
      map: 'foundry',
    );
    await until(() => a.room != null, 'second room');
    await b.join(a.room!.code, 'Friend again');
    await until(() => a.members.length == 2, 'second roster');
    await a.ready();
    await b.ready();
    await until(() => a.canStart, 'second readiness');
    await a.start();
    await until(() => a.active && b.active, 'second active');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (a.me!.dashSeq != Int64.ZERO) {
      throw StateError('Dash replayed across rooms');
    }
    await b.leave();
    await a.leave();
    print(
      'PASS: two Dart identities, scoped room views, ready/start, server movement, ping, reconnect and leave',
    );
  } finally {
    await a.close();
    await b.close();
  }
  for (final size in [1, 2, 3]) {
    await verifyVersus(size);
  }
}
