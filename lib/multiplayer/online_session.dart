import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'combat_state.dart';
import 'identity_key.dart';

import 'dart:math' as math;

import 'package:spacetimedb/spacetimedb.dart';

import 'generated/client.dart';
import 'generated/member.dart';
import 'generated/room.dart';
import 'generated/online_account.dart';
import 'generated/online_result.dart';
import 'geometry.dart';

/// No offline mutation replay. Native startup installs secure durable storage;
/// standalone tests inject an isolated memory token store.
class OnlineSession {
  OnlineSession({AuthTokenStore? tokens}) : tokens = tokens ?? appTokens;
  static AuthTokenStore appTokens = InMemoryTokenStore();
  static Future<void> Function()? prepareAssets;
  bool _assetsReady = false;
  static const host = String.fromEnvironment(
    'REGUN_SERVER_HOST',
    defaultValue: 'regunserver.kiishi.space',
  );
  static const database = String.fromEnvironment(
    'REGUN_DATABASE',
    defaultValue: 'regun',
  );
  static const tls = bool.fromEnvironment(
    'REGUN_SERVER_TLS',
    defaultValue: true,
  );
  final AuthTokenStore tokens;
  bool grenadesAvailable = false, grenadeAimingAvailable = false;
  bool combatAvailable = false, _attaching = false, _combatSending = false;
  OnlineMatch? match;
  Map<String, OnlineGun> fighters = {};
  List<OnlineRound> projectiles = [];
  List<OnlineEntity> scene = [];
  OnlineAccount? account;
  List<OnlineResult> results = [];
  OnlineResult? get result => results
      .where((r) => r.matchId.toString() == match?.data['matchId'])
      .firstOrNull;
  bool menuOpen = false;
  String reviveTarget = "";
  OnlineGun? get gun => fighters[identity];
  bool firing = false;
  int _combatSeq = 0, _reloadSeq = 0, _grenadeSeq = 0;
  bool get controlsEnabled =>
      connected &&
      !suspended &&
      !menuOpen &&
      me?.expired != true &&
      active &&
      compatible &&
      (match == null ||
          (match!.version == 1 &&
              match!.phase == 'active' &&
              (gun?.health ?? 0) > 0));
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
          room!.geometryHash == (geometryHashes[room!.mapId] ?? geometryHash) &&
          onlineGeometry.containsKey(room!.mapId));
  bool get active => room?.phase == 'active';
  bool get canStart {
    final r = room;
    if (!compatible || r == null || !owner || active || members.length < 2) {
      return false;
    }
    if (members.any((m) => !m.connected || !m.ready || m.expired)) return false;
    if (match != null &&
        (match!.version != 1 ||
            members.any(
              (m) => fighters[m.identity.toHexString]?.enabled != true,
            ))) {
      return false;
    }
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
      if (!tls &&
          ![
            'localhost',
            '127.0.0.1',
            '10.0.2.2',
          ].contains(host.split(':').first)) {
        throw StateError('TLS is required for remote servers');
      }
      // Schema capability detection preserves the deployed movement-only service.
      final schema = await http
          .get(
            Uri.parse(
              '${tls ? 'https' : 'http'}://$host/v1/database/$database/schema?version=9',
            ),
          )
          .timeout(const Duration(seconds: 6));
      if (schema.statusCode != 200) {
        throw StateError('Server schema unavailable');
      }
      final schemaJson = jsonDecode(schema.body) as Map<String, dynamic>;
      grenadeAimingAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'aim_grenade',
      );
      grenadesAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'throw_grenade',
      );
      combatAvailable = (schemaJson['misc_exports'] as List? ?? []).any(
        (v) =>
            v is Map && v['View'] is Map && v['View']['name'] == 'room_combat',
      );
      if (combatAvailable && !_assetsReady) {
        status = 'Preparing arena…';
        _notify();
        await prepareAssets?.call().timeout(const Duration(seconds: 20));
        _assetsReady = true;
      }
      fresh = await SpacetimeDbClient.connect(
        host: host,
        database: database,
        ssl: tls,
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
          if (combatAvailable) ...[
            'SELECT * FROM room_combat',
            'SELECT * FROM room_fighters',
            'SELECT * FROM room_projectiles',
            'SELECT * FROM room_scene',
            'SELECT * FROM my_online_account',
            'SELECT * FROM my_online_results',
          ],
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
      if (combatAvailable) {
        watch(fresh.roomCombat);
        watch(fresh.roomFighters);
        watch(fresh.roomProjectiles);
        watch(fresh.roomScene);
        watch(fresh.myOnlineAccount);
        watch(fresh.myOnlineResults);
      }
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
    if (combatAvailable) {
      account = client.myOnlineAccount.iter().firstOrNull;
      results = client.myOnlineResults.iter().toList()
        ..sort((a, b) => b.matchId.compareTo(a.matchId));
      final meta = client.roomCombat.iter().firstOrNull;
      match = meta == null ? null : OnlineMatch(combatObject(meta.data));
      fighters = {
        for (final f in client.roomFighters.iter())
          identityKeyFromCanonical(f.key): OnlineGun(
            identityKeyFromCanonical(f.key),
            combatObject(f.data),
            enabled: f.enabled,
          ),
      };
      scene = [
        for (final row in client.roomScene.iter())
          OnlineEntity(row.id.toString(), row.kind, combatObject(row.data)),
      ];
      projectiles = [
        for (final p in client.roomProjectiles.iter())
          OnlineRound(p.id.toString(), combatObject(p.data)),
      ];
    }
    final mine = me;
    if (mine != null &&
        (mine.generation != _generation || mine.roomId != _inputRoom)) {
      _inputRoom = mine.roomId;
      _generation = mine.generation;
      _seq = mine.seq.toInt();
      _dash = mine.dashSeq.toInt();
      final fighter = combatAvailable
          ? client.roomFighters
                .iter()
                .where((f) => identityKeyFromCanonical(f.key) == identity)
                .firstOrNull
          : null;
      _combatSeq = fighter?.inputSeq.toInt() ?? 0;
      _reloadSeq = fighter?.reloadSeq.toInt() ?? 0;
      _grenadeSeq =
          int.tryParse(gun?.data['grenadeSeq'] as String? ?? '0') ?? 0;
      neutral();
    }
    // A reconnect can deliver the member view before the fighter snapshot.
    _grenadeSeq = math.max(
      _grenadeSeq,
      int.tryParse(gun?.data['grenadeSeq'] as String? ?? '0') ?? 0,
    );
    if (combatAvailable &&
        connected &&
        match != null &&
        match!.version == 1 &&
        mine != null &&
        gun?.enabled != true &&
        !_attaching) {
      _attaching = true;
      unawaited(
        _quiet(() => client.reducers.attachCombat(version: 1))
            .whenComplete(() => _attaching = false),
      );
    }
    if (match != null && !controlsEnabled) neutral();
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
    firing = false;
    reviveTarget = "";
  }

  void dash() {
    if (controlsEnabled) _dash++;
  }

  void reload() {
    if (controlsEnabled && match != null) _reloadSeq++;
  }

  Offset get quickGrenadeDirection => moveX * moveX + moveY * moveY > .0036
      ? Offset(moveX, moveY)
      : Offset(aimX, aimY);
  void throwGrenade({Offset? aim, double power = 1}) {
    if (!controlsEnabled ||
        !grenadesAvailable ||
        room == null ||
        me == null ||
        (gun?.grenadeCharges ?? 0) <= 0 ||
        (gun?.offers.isNotEmpty ?? true)) {
      return;
    }
    unawaited(
      _quiet(
        () => grenadeAimingAvailable
            ? _client!.reducers.aimGrenade(
                roomid: room!.id,
                generation: me!.generation,
                seq: Int64(++_grenadeSeq),
                aimx:
                    (aim ?? quickGrenadeDirection).dx /
                    (aim ?? quickGrenadeDirection).distance.clamp(
                      .001,
                      double.infinity,
                    ),
                aimy:
                    (aim ?? quickGrenadeDirection).dy /
                    (aim ?? quickGrenadeDirection).distance.clamp(
                      .001,
                      double.infinity,
                    ),
                power: power.clamp(.4, 1),
              )
            : _client!.reducers.throwGrenade(
                roomid: room!.id,
                generation: me!.generation,
                seq: Int64(++_grenadeSeq),
              ),
      ),
    );
  }

  Future<void> chooseLoadout(String weapon, String survivor) => command(
    (c) => c.reducers.chooseLoadout(weapon: weapon, survivor: survivor),
  );
  Future<void> chooseUpgrade(String choice) => command(
    (c) => c.reducers.chooseUpgrade(offerid: gun!.offerId, choice: choice),
  );
  Future<void> rerollUpgrade() =>
      command((c) => c.reducers.rerollUpgrade(offerid: gun!.offerId));
  Future<void> banUpgrade(String choice) => command(
    (c) => c.reducers.banUpgrade(offerid: gun!.offerId, choice: choice),
  );
  Future<void> openFusion() => command((c) => c.reducers.openFusion());
  Future<void> rematch() => command((c) => c.reducers.rematch());
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
    if (!controlsEnabled || mine == null || r == null || _sending) return;
    if (match != null && !_combatSending && gun?.enabled == true) {
      _combatSending = true;
      unawaited(
        _quiet(
          () => _client!.reducers.combatInput(
            roomid: r.id,
            generation: mine.generation,
            seq: Int64(++_combatSeq),
            reloadseq: Int64(_reloadSeq),
            firing: firing,
          ),
        ).whenComplete(() => _combatSending = false),
      );
    }
    if (reviveTarget.isNotEmpty && _pulse % 2 == 0) {
      final target = identityKeyFromCanonical(reviveTarget);
      unawaited(
        _quiet(
          () => _client!.reducers.reviveInput(
            roomid: r.id,
            generation: mine.generation,
            target: target,
            holding: true,
          ),
        ),
      );
    }
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
  }) async {
    await command(
      (c) => c.reducers.createRoom(
        mode: mode,
        teamsize: teamSize,
        mapid: map,
        name: name.trim(),
        protocol: 1,
      ),
    );
    if (combatAvailable && room != null && owner && error.isEmpty) {
      await command((c) => c.reducers.enableCombat());
    }
  }

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
