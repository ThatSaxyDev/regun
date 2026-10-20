import 'dart:async';
import 'dart:math' as math;

import 'package:spacetimedb/spacetimedb.dart';

import 'generated/client.dart';
import 'generated/member.dart';
import 'generated/room.dart';
import 'geometry.dart';

/// No disk token/cache and no offline mutation replay. An identity lasts for
/// this app process; reopening Online can resume within the server grace.
class OnlineSession {
  OnlineSession({AuthTokenStore? tokens}) : tokens = tokens ?? appTokens;
  static final appTokens = InMemoryTokenStore();
  static const host = String.fromEnvironment(
    'REGUN_SERVER_HOST',
    defaultValue: 'regunserver.kiishi.space',
  );
  final AuthTokenStore tokens;
  final changes = StreamController<void>.broadcast();
  SpacetimeDbClient? _client;
  final List<StreamSubscription<dynamic>> _listeners = [];
  Timer? _clock, _retry;
  bool _closed = false, _connecting = false, _probing = false, _sending = false;
  bool busy = false, connected = false, suspended = false;
  String status = 'Offline', error = '';
  Room? room;
  List<Member> members = [];
  String? identity;
  final _time = Stopwatch()..start();
  final Map<String, (Int64, int)> _pingSamples = {};
  Duration pingAge(Member member) => Duration(
    microseconds:
        _time.elapsedMicroseconds -
        (_pingSamples[member.identity.toHexString]?.$2 ?? -3000001),
  );
  int _seq = 0, _dash = 0, _pulse = 0, _epoch = 0;
  Int64? _generation, _inputRoom, _ack;
  DateTime? _lostAt;
  double moveX = 0, moveY = 0, aimX = 1, aimY = 0;
  Member? get me =>
      members.where((m) => m.identity.toHexString == identity).firstOrNull;
  bool get owner => room?.owner.toHexString == identity;
  bool get compatible =>
      room == null ||
      (room!.protocol == 1 &&
          room!.geometryHash == geometryHash &&
          onlineGeometry.containsKey(room!.mapId));
  bool get active => room?.phase == 'active';
  bool get canStart {
    final r = room;
    if (!compatible || r == null || !owner || active || members.length < 2) {
      return false;
    }
    if (members.any((m) => !m.connected || !m.ready || m.expired)) return false;
    return r.mode == 'coop' ||
        (members.length == r.capacity &&
            members.where((m) => m.team == 0).length == r.teamSize &&
            members.where((m) => m.team == 1).length == r.teamSize);
  }

  void _notify() {
    if (!_closed) changes.add(null);
  }

  Future<void> connect() async {
    if (_closed || _connecting || suspended || connected) return;
    _connecting = true;
    status = _lostAt == null ? 'Connecting…' : 'Reconnecting…';
    error = '';
    _notify();
    final epoch = ++_epoch;
    SpacetimeDbClient? fresh;
    try {
      await _clearClient();
      fresh = await SpacetimeDbClient.connect(
        host: host,
        database: 'regun',
        ssl: true,
        authStorage: tokens,
        config: const ConnectionConfig(
          autoReconnect: false,
          connectTimeout: Duration(seconds: 6),
        ),
        subscriptionTimeout: const Duration(seconds: 6),
        initialSubscriptions: [
          'SELECT * FROM my_room',
          'SELECT * FROM room_members',
          'SELECT * FROM my_probe',
        ],
      );
      if (_closed || epoch != _epoch || suspended) {
        await fresh.dispose();
        return;
      }
      _client = fresh;
      identity = fresh.identity?.toHexString;
      connected = true;
      status = 'Connected';
      _lostAt = null;
      _generation = null;
      _ack = null;
      _pingSamples.clear();
      _sending = false;
      void watch<T>(TableCache<T> table) {
        _listeners.add(table.insertStream.listen((_) => _refresh()));
        _listeners.add(table.updateStream.listen((_) => _refresh()));
        _listeners.add(table.deleteStream.listen((_) => _refresh()));
      }

      watch(fresh.myRoom);
      watch(fresh.roomMembers);
      watch(fresh.myProbe);
      _listeners.add(
        fresh.connection.connectionStatus.listen((s) {
          if (s != ConnectionStatus.connected) _lost();
        }),
      );
      _refresh();
      _clock ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _tick(),
      );
    } catch (_) {
      if (_closed || epoch != _epoch) return;
      connected = false;
      status = 'Connection failed';
      error = 'Cannot reach the server. Check your connection and retry.';
      _scheduleRetry();
    } finally {
      _connecting = false;
      _notify();
      if (!_closed && !suspended && !connected && epoch != _epoch) {
        unawaited(
          connect(),
        ); // Foregrounded while an older connect was finishing.
      }
    }
  }

  void _refresh() {
    final client = _client;
    if (client == null || _closed) return;
    room = client.myRoom.iter().firstOrNull;
    if (!compatible) {
      neutral();
      error =
          'This room needs a newer game build. Leave and update to continue.';
    }
    members = client.roomMembers.iter().toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    for (final member in members) {
      final key = member.identity.toHexString;
      if (member.pingAt != Int64.ZERO &&
          _pingSamples[key]?.$1 != member.pingAt) {
        _pingSamples[key] = (member.pingAt, _time.elapsedMicroseconds);
      }
    }
    _pingSamples.removeWhere(
      (key, _) => !members.any((m) => m.identity.toHexString == key),
    );
    final mine = me;
    if (mine != null &&
        (mine.generation != _generation || mine.roomId != _inputRoom)) {
      _inputRoom = mine.roomId;
      _generation = mine.generation;
      _seq = mine.seq.toInt();
      _dash = mine.dashSeq.toInt();
      neutral();
    }
    final probe = client.myProbe.iter().firstOrNull;
    if (connected && probe != null && probe.pending && probe.probe != _ack) {
      _ack = probe.probe;
      unawaited(
        _quiet(() => client.reducers.acknowledgeProbe(probe: probe.probe)),
      );
    }
    _notify();
  }

  void neutral() {
    moveX = 0;
    moveY = 0;
  }

  void dash() {
    if (connected && active && !suspended) _dash++;
  }

  void _tick() {
    if (!connected || suspended || _closed) return;
    if (++_pulse % 40 == 0 &&
        !_probing &&
        room != null &&
        me?.connected == true) {
      _probing = true;
      unawaited(
        _quiet(() => _client!.reducers.beginProbe())
            .whenComplete(() => _probing = false),
      );
    }
    final mine = me, r = room;
    if (_pulse % 20 == 0) _notify();
    if (!compatible || !active || mine == null || r == null || _sending) return;
    _sending = true;
    final length = math.max(1.0, math.sqrt(moveX * moveX + moveY * moveY));
    unawaited(
      _quiet(
        () => _client!.reducers.submitInput(
          roomid: r.id,
          generation: mine.generation,
          seq: Int64(++_seq),
          movex: moveX / length,
          movey: moveY / length,
          aimx: aimX,
          aimy: aimY,
          dashseq: Int64(_dash),
        ),
      ).whenComplete(() => _sending = false),
    );
    _notify(); // refresh stale connection labels even without table changes
  }

  Future<void> _quiet(Future<TransactionResult> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 4));
    } on ReducerException {
      // Validation rejection is not a transport failure. Never replay it.
      neutral();
    } catch (_) {
      if (connected) _lost();
    }
  }

  void _lost() {
    if (_closed || !connected) return;
    connected = false;
    neutral();
    _lostAt ??= DateTime.now();
    status = suspended ? 'Paused — reconnect on return' : 'Reconnecting…';
    _scheduleRetry();
    _notify();
  }

  void _scheduleRetry() {
    _lostAt ??= DateTime.now();
    if (_closed ||
        suspended ||
        DateTime.now().difference(_lostAt!).inSeconds >= 25) {
      status = suspended ? 'Paused' : 'Disconnected — retry';
      return;
    }
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  Future<void> suspend() async {
    if (_closed || suspended) return;
    suspended = true;
    status = 'Paused - reconnect on return';
    neutral();
    _retry?.cancel();
    ++_epoch;
    _lost();
    await _clearClient();
  }

  Future<void> resume() async {
    suspended = false;
    await connect();
  }

  Future<void> command(
    Future<TransactionResult> Function(SpacetimeDbClient) call,
  ) async {
    if (busy || !connected || _client == null || _closed) return;
    busy = true;
    error = '';
    _notify();
    try {
      final result = await call(_client!).timeout(const Duration(seconds: 7));
      if (!result.isSuccess) error = result.errorMessage ?? 'Request rejected.';
    } on TimeoutException {
      error = 'No reply yet. Reconnect to check the room before trying again.';
      _lost();
    } catch (e) {
      // Reducer errors contain server-owned validation messages, never tokens.
      error = e is ReducerException
          ? e.message
          : 'Request failed. Please retry.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> create({
    required String name,
    required String mode,
    required int teamSize,
    required String map,
  }) => command(
    (c) => c.reducers.createRoom(
      mode: mode,
      teamsize: teamSize,
      mapid: map,
      name: name.trim(),
      protocol: 1,
    ),
  );
  Future<void> join(String code, String name) => command(
    (c) => c.reducers.joinRoom(
      code: code.trim().toUpperCase(),
      name: name.trim(),
      protocol: 1,
    ),
  );
  Future<void> ready() =>
      command((c) => c.reducers.setReady(ready: !(me?.ready ?? false)));
  Future<void> team(int team) =>
      command((c) => c.reducers.chooseTeam(team: team));
  Future<void> enemies(bool value) =>
      command((c) => c.reducers.configureRoom(enemies: value));
  Future<void> start() => command((c) => c.reducers.startMatch());
  Future<void> leave() => command((c) => c.reducers.leaveRoom());
  Future<void> _clearClient() async {
    for (final sub in _listeners) {
      await sub.cancel();
    }
    _listeners.clear();
    final old = _client;
    _client = null;
    await old?.dispose();
  }

  Future<void> close() async {
    _closed = true;
    ++_epoch;
    connected = false;
    neutral();
    _retry?.cancel();
    _clock?.cancel();
    await _clearClient();
    await changes.close();
  }
}

/// Thresholds describe application round-trip quality, including server work.
String pingLabel(
  Member member,
  DateTime now, {
  required bool online,
  Duration? age,
}) {
  if (!online || !member.connected) return 'Offline';
  final sampled = member.pingAt.toInt();
  if (sampled == 0) return 'Measuring…';
  if ((age?.inMicroseconds ?? now.microsecondsSinceEpoch - sampled) > 3000000) {
    return 'Stale';
  }
  final quality = member.pingMs < 100
      ? 'Good'
      : member.pingMs < 200
      ? 'Fair'
      : 'Poor';
  return '${member.pingMs} ms | $quality';
}
