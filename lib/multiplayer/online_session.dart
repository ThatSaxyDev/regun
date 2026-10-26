import 'package:regun/multiplayer/upgrade_receipts.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';

import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'combat_state.dart';
import 'movement_prediction.dart';
import 'remote_motion.dart';
import 'projectile_presentation.dart';
import 'combat_input_pump.dart';
import 'guest_recovery.dart';
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
  OnlineSession({AuthTokenStore? tokens})
    : tokens = tokens ?? AccountOnlineTokens(AccountController.shared);
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
  bool get usesAccountIdentity => tokens is AccountOnlineTokens;
  bool chargeUpgradesAvailable = false, groundOrdnanceAvailable = false;
  bool rankCurvesAvailable = false;
  bool supportOpsAvailable = false;
  bool supportRanksAvailable = false;
  bool upgradeConfirmationAvailable = false;
  static const upgradeConfirmationsEnabled = true;
  final upgradeReceipts = OnlineUpgradeReceipts();
  bool grenadesAvailable = false, grenadeAimingAvailable = false;
  bool predictionAvailable = false;
  bool predictionReducedMotion = false;
  final movementPrediction = MovementPrediction();
  final remoteMotion = <String, RemoteMotion>{};
  final projectilePresentation = ProjectilePresentation();
  ProjectileMap? _projectileMap;
  String? _projectileMapId;
  bool projectileInputsAvailable = false;
  bool get projectilePredictionAvailable =>
      projectileInputsAvailable &&
      movementPrediction.projectileProtocolAvailable;

  List<OnlineRound> presentedProjectiles() {
    final map = _projectileMap;
    if (map == null) return projectiles;
    final mine = me;
    final bodies = <(Offset, double)>[
      if (mine != null && room?.mode == 'versus')
        for (final m in members)
          if (m.team != mine.team &&
              !m.expired &&
              (fighters[m.identity.toHexString]?.health ?? 0) > 0)
            (Offset(m.x, m.y), 30),
      for (final e in scene)
        if (e.kind == 'enemy' &&
            e.number('health') > 0 &&
            e.number('spawning') <= 0)
          (Offset(e.x, e.y), e.number('radius', 25)),
    ];
    return projectilePresentation.render(
      _time.elapsedMicroseconds / 1e6,
      map,
      active:
          connected && active && (match == null || match!.phase == 'active'),
      bodies: bodies,
    );
  }

  void _captureProjectiles() {
    final r = room, mine = me;
    if (!connected || r == null || mine == null || !compatible) {
      projectilePresentation.clear();
      return;
    }
    if (_projectileMapId != r.mapId) {
      _projectileMapId = r.mapId;
      _projectileMap = ProjectileMap(gameplayGeometry);
      projectilePresentation.clear();
    }
    _projectileMap = ProjectileMap(gameplayGeometry);
    projectilePresentation.capture(
      epoch: '${r.id}:${mine.generation}',
      tick: r.tick.toInt(),
      serverTime: r.lastTickAt.toInt() / 1e6,
      now: _time.elapsedMicroseconds / 1e6,
      rounds: projectiles,
      identity: identity!,
      gun: gun,
      map: _projectileMap!,
    );
  }

  void _predictProjectiles() {
    final mine = me;
    if (mine == null) {
      projectilePresentation.cancelPrediction();
      return;
    }
    projectilePresentation.predict(
      now: _time.elapsedMicroseconds / 1e6,
      enabled:
          controlsEnabled &&
          projectilePredictionAvailable &&
          !movementPrediction.stalled,
      held: firing && !_reloadPending,
      gun: gun,
      origin: predictedPosition ?? Offset(mine.x, mine.y),
      aim: Offset(aimX, aimY),
      identity: identity!,
      team: mine.team,
      burst: _fireBurst,
    );
  }

  MotionMap? _remoteMap;
  String? _remoteMapId;
  Offset remotePosition(Member member, {bool reducedMotion = false}) =>
      _remoteMap == null
      ? Offset(member.x, member.y)
      : remoteMotion[member.identity.toHexString]?.render(
              _time.elapsedMicroseconds / 1e6,
              _remoteMap!,
              reducedMotion: reducedMotion,
            ) ??
            Offset(member.x, member.y);

  void _captureRemoteMotion() {
    final r = room;
    if (!connected ||
        r == null ||
        !compatible ||
        !active ||
        (match != null && match!.phase != 'active')) {
      remoteMotion.clear();
      return;
    }
    if (_remoteMapId != r.mapId) {
      _remoteMapId = r.mapId;
      _remoteMap = MotionMap(onlineGeometry[r.mapId]!);
      remoteMotion.clear();
    }
    for (final member in members) {
      final key = member.identity.toHexString;
      if (key == identity) continue;
      final walking = fighters[key]?.rank('walkingSpeedIncrease') ?? 0;
      final remoteGun = fighters[key];
      final speed =
          (remoteGun?.baseNumber(
                'movement',
                remoteGun.survivor == 'warden'
                    ? 261
                    : remoteGun.survivor == 'scrapper'
                    ? 345
                    : 300,
              ) ??
              300) +
          (walking.clamp(0, 3) * 50 + (walking - 3).clamp(0, 5) * 12) *
              (remoteGun?.strength('walkingSpeedIncrease') ?? 1);
      final alive =
          member.connected &&
          !member.expired &&
          (match == null || (fighters[key]?.health ?? 0) > 0);
      final track = remoteMotion.putIfAbsent(key, RemoteMotion.new);
      track.add(
        epoch: '${r.id}:${member.generation}:$alive',
        tick: r.tick.toInt(),
        serverTime: r.lastTickAt.toInt() / 1e6,
        arrival: _time.elapsedMicroseconds / 1e6,
        position: Offset(member.x, member.y),
        maxSpeed: member.dashRemaining > 0 ? 1450 : speed.toDouble(),
        extrapolationLimit: member.dashRemaining > 0
            ? member.dashRemaining
            : .08,
        moving:
            alive &&
            (member.moveX != 0 ||
                member.moveY != 0 ||
                member.dashRemaining > 0),
      );
    }
    remoteMotion.removeWhere(
      (key, _) => !members.any((m) => m.identity.toHexString == key),
    );
  }

  Map<String, dynamic> get gameplayGeometry {
    final base = onlineGeometry[room?.mapId] ?? onlineGeometry['network_lab']!;
    return {
      ...base,
      'obstacles': [
        ...base['obstacles'] as List,
        if (supportOpsAvailable)
          for (final unit in scene.where(
            (e) =>
                e.kind == 'support' &&
                e.data['id'].toString().startsWith('support:sentry:') &&
                ['deploying', 'active'].contains(e.data['phase']),
          ))
            [unit.x - 35, unit.y - 44, unit.x + 35, unit.y],
        if (groundOrdnanceAvailable)
          for (final drop in scene.where(
            (e) =>
                e.kind == 'supply' &&
                ['active', 'opened'].contains(e.data['phase']),
          ))
            [drop.x - 46, drop.y - 52, drop.x + 46, drop.y],
      ],
    };
  }

  MotionMap? _motionMap;
  String? _predictionEpoch;
  int _predictionAt = 0;
  double maxPredictionTimerGapMs = 0, maxRefreshGapMs = 0;
  int _refreshAt = 0;
  bool _predictionRunning = false;
  Timer? _predictionClock;
  Offset? get predictedPosition => _motionMap == null
      ? null
      : movementPrediction.rendered(_motionMap!, _occupied());
  double get predictedDashCooldown =>
      movementPrediction.body?.cooldown ?? me?.cooldown ?? 0;
  double get predictedDashDuration =>
      movementPrediction.body == null ? 1.6 : movementPrediction.dashCooldown;
  double get predictedDashRemaining =>
      movementPrediction.body?.dashRemaining ?? me?.dashRemaining ?? 0;

  bool combatAvailable = false, _attaching = false;
  final combatInputPump = CombatInputPump();
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
  bool _firing = false, _reloadPending = false;
  int _fireBurst = 0;
  bool get firing => _firing;
  set firing(bool value) {
    if (value && !_firing) _fireBurst++;
    _firing = value;
  }

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
  bool get connecting => _connecting;
  bool get retryScheduled => _retry?.isActive ?? false;

  /// Safe diagnostic category, never a token, URL query or raw server payload.
  String connectionDiagnostic = '';
  bool guestRejected = false;
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
    if (_closed || _connecting || suspended || connected || guestRejected) {
      return;
    }
    _connecting = true;
    _retry?.cancel();
    status = _lostAt == null ? 'Connecting…' : 'Reconnecting…';
    error = '';
    connectionDiagnostic = '';
    _notify();
    final epoch = ++_epoch;
    SpacetimeDbClient? fresh;
    var stage = 'service';
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
          .timeout(const Duration(seconds: 10));
      if (schema.statusCode != 200) {
        connectionDiagnostic = 'schema_http_${schema.statusCode}';
        throw StateError('Server schema unavailable');
      }
      if (_closed || epoch != _epoch || suspended) return;
      stage = 'schema';
      final schemaJson = jsonDecode(schema.body) as Map<String, dynamic>;
      projectileInputsAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'combat_input_v_2',
      );
      predictionAvailable =
          (schemaJson['reducers'] as List? ?? []).any(
            (v) => v is Map && v['name'] == 'queue_motion',
          ) &&
          (schemaJson['reducers'] as List? ?? []).any(
            (v) => v is Map && v['name'] == 'stop_motion',
          ) &&
          (schemaJson['misc_exports'] as List? ?? []).any(
            (v) =>
                v is Map &&
                v['View'] is Map &&
                v['View']['name'] == 'my_motion',
          );
      groundOrdnanceAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'ground_ordnance',
      );
      grenadeAimingAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'aim_grenade',
      );
      upgradeConfirmationAvailable = (schemaJson['reducers'] as List? ?? [])
          .any((v) => v is Map && v['name'] == 'upgrade_confirmation');
      supportRanksAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'support_ranks_viii',
      );
      supportOpsAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'support_ops',
      );
      rankCurvesAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'rank_curve_support',
      );
      chargeUpgradesAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'charge_upgrades',
      );
      grenadesAvailable = (schemaJson['reducers'] as List? ?? []).any(
        (v) => v is Map && v['name'] == 'throw_grenade',
      );
      combatAvailable = (schemaJson['misc_exports'] as List? ?? []).any(
        (v) =>
            v is Map && v['View'] is Map && v['View']['name'] == 'room_combat',
      );
      if (combatAvailable && !_assetsReady) {
        stage = 'assets';
        status = 'Preparing arena…';
        _notify();
        await prepareAssets?.call().timeout(const Duration(seconds: 20));
        if (_closed || epoch != _epoch || suspended) return;
        _assetsReady = true;
      }
      stage = 'session';
      fresh = await SpacetimeDbClient.connect(
        host: host,
        database: database,
        ssl: tls,
        authStorage: tokens,
        config: const ConnectionConfig(
          autoReconnect: false,
          connectTimeout: Duration(seconds: 12),
        ),
        subscriptionTimeout: const Duration(seconds: 12),
        initialSubscriptions: [
          'SELECT * FROM my_room',
          'SELECT * FROM room_members',
          'SELECT * FROM my_probe',
          if (predictionAvailable) 'SELECT * FROM my_motion',
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
        _listeners.add(table.insertStream.listen((_) => _queueRefresh()));
        _listeners.add(table.updateStream.listen((_) => _queueRefresh()));
        _listeners.add(table.deleteStream.listen((_) => _queueRefresh()));
      }

      watch(fresh.myRoom);
      watch(fresh.roomMembers);
      watch(fresh.myProbe);
      if (predictionAvailable) watch(fresh.myMotion);
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
      _predictionClock ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _predict(),
      );
      _clock ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _tick(),
      );
    } catch (failure) {
      if (_closed || epoch != _epoch) return;
      connected = false;
      status = 'Connection failed';
      connectionDiagnostic = connectionDiagnostic.isNotEmpty
          ? connectionDiagnostic
          : '${stage}_${failure.runtimeType}';
      guestRejected =
          failure is SpacetimeDbAuthException ||
          (usesAccountIdentity && failure is AccountError);
      error = guestRejected && usesAccountIdentity
          ? 'Sign in again from Settings to reconnect. Solo and Training are available.'
          : guestRejected
          ? 'This device’s saved online guest is no longer accepted. Start a new guest to reconnect. Previous online records may be unavailable.'
          : switch (stage) {
              'assets' => 'Arena preparation failed. Try connecting again.',
              'schema' =>
                'Online service needs an update. Please try again later.',
              'session' =>
                'Could not open the online session. Try connecting again.',
              _ =>
                connectionDiagnostic.startsWith('schema_http_')
                    ? 'Online service is unavailable. Please try again shortly.'
                    : 'Could not contact the online service. Check your connection.',
            };
      if (!guestRejected) _scheduleRetry();
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

  Future<void> recoverGuest() async {
    if (usesAccountIdentity ||
        !guestRejected ||
        busy ||
        _closed ||
        _connecting) {
      return;
    }
    busy = true;
    _notify();
    try {
      if (tokens is RejectedGuestArchive) {
        await (tokens as RejectedGuestArchive).archiveRejectedGuest();
      }
      await tokens.clearToken();
      if (_closed) return;
      guestRejected = false;
      _lostAt = null;
      error = '';
    } catch (_) {
      error = 'Could not update the saved guest. Please try again.';
    } finally {
      busy = false;
      _notify();
    }
    if (!guestRejected && !_closed) await connect();
  }

  bool _refreshQueued = false;
  void _queueRefresh() {
    if (_closed || _refreshQueued) return;
    _refreshQueued = true;
    // One subscription transaction can change every fighter. Decode/reconcile
    // once after its row events drain, instead of once per changed row.
    Timer.run(() {
      _refreshQueued = false;
      if (!_closed) _refresh();
    });
  }

  void _refresh() {
    final client = _client;
    if (client == null || _closed) return;
    final refreshAt = _time.elapsedMicroseconds;
    if (controlsEnabled && _refreshAt != 0) {
      maxRefreshGapMs = math.max(
        maxRefreshGapMs,
        (refreshAt - _refreshAt) / 1000,
      );
    }
    _refreshAt = refreshAt;
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
      final owner = AccountController.shared.session?.accountId;
      if (owner != null && account != null) {
        LocalPreferences.shared.updateOnlineScrap(
          owner,
          account!.scrap.toInt(),
        );
      }
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
            aiming: f.fireHeld,
          ),
      };
      upgradeReceipts.sync(
        '${room?.id}:${match?.data['matchId']}',
        match,
        fighters,
      );
      scene = [
        for (final row in client.roomScene.iter())
          OnlineEntity(row.id.toString(), row.kind, combatObject(row.data)),
      ];
      projectiles = [
        for (final p in client.roomProjectiles.iter())
          OnlineRound(p.id.toString(), combatObject(p.data)),
      ];
    }
    final ownFighter = client.roomFighters
        .iter()
        .where((f) => identityKeyFromCanonical(f.key) == identity)
        .firstOrNull;
    if (ownFighter != null && ownFighter.reloadSeq.toInt() >= _reloadSeq) {
      _reloadPending = false;
    }
    _captureRemoteMotion();
    _captureProjectiles();
    final mine = me;
    if (mine != null &&
        (mine.generation != _generation || mine.roomId != _inputRoom)) {
      movementPrediction.reset();
      combatInputPump.reset();
      maxPredictionTimerGapMs = maxRefreshGapMs = 0;
      _predictionEpoch = null;
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
      _fireBurst = math.max(
        _fireBurst,
        int.tryParse(gun?.data['fireBurst'] as String? ?? '0') ?? 0,
      );
      _reloadSeq = fighter?.reloadSeq.toInt() ?? 0;
      _reloadPending = false;
      _grenadeSeq =
          int.tryParse(gun?.data['grenadeSeq'] as String? ?? '0') ?? 0;
      neutral();
    }
    if (_motionMap != null) {
      _motionMap!.obstacles
        ..clear()
        ..addAll(MotionMap(gameplayGeometry).obstacles);
    }
    if (predictionAvailable && controlsEnabled && mine != null) {
      _seedPrediction();
      final snapshot = client.myMotion.iter().firstOrNull;
      if (snapshot != null &&
          snapshot.generation == mine.generation &&
          snapshot.roomId == mine.roomId) {
        movementPrediction.reconcile(
          _predictionEpoch!,
          combatObject(snapshot.data),
          _motionMap!,
          _occupied(),
          reducedMotion: predictionReducedMotion,
        );
      }
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
        _quiet(
          () => client.reducers.attachCombat(
            version: upgradeConfirmationsEnabled && upgradeConfirmationAvailable
                ? 8
                : supportRanksAvailable
                ? 7
                : supportOpsAvailable
                ? 6
                : rankCurvesAvailable
                ? 5
                : chargeUpgradesAvailable
                ? 4
                : 3,
          ),
        ).whenComplete(() => _attaching = false),
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
    if (controlsEnabled && match != null) {
      _reloadSeq++;
      _reloadPending = true;
    }
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
    (c) => supportOpsAvailable
        ? c.reducers.chooseReward(
            roomid: room!.id,
            generation: me!.generation,
            offerid: gun!.offerId,
            choice: choice,
          )
        : c.reducers.chooseUpgrade(offerid: gun!.offerId, choice: choice),
  );
  Future<void> rerollUpgrade() => command(
    (c) => supportOpsAvailable
        ? c.reducers.rerollReward(
            roomid: room!.id,
            generation: me!.generation,
            offerid: gun!.offerId,
          )
        : c.reducers.rerollUpgrade(offerid: gun!.offerId),
  );
  Future<void> banUpgrade(String choice) => command(
    (c) => supportOpsAvailable
        ? c.reducers.banReward(
            roomid: room!.id,
            generation: me!.generation,
            offerid: gun!.offerId,
            choice: choice,
          )
        : c.reducers.banUpgrade(offerid: gun!.offerId, choice: choice),
  );
  Future<void> openFusion() => command((c) => c.reducers.openFusion());
  Future<void> rematch() => command((c) => c.reducers.rematch());
  List<Offset> _occupied() => [
    for (final m in members)
      if (m.identity.toHexString != identity &&
          !m.expired &&
          (match == null ||
              (fighters[m.identity.toHexString]?.health ?? 0) > 0))
        Offset(m.x, m.y),
  ];

  void _seedPrediction() {
    final mine = me!, r = room!;
    final epoch = '${r.id}:${mine.generation}';
    if (_predictionEpoch == epoch && movementPrediction.body != null) return;
    _predictionEpoch = epoch;
    _motionMap = MotionMap(gameplayGeometry);
    final walking = gun?.rank('walkingSpeedIncrease') ?? 0;
    final quickstep = gun?.rank('quickstep') ?? 0;
    final effectiveQuickstep = quickstep <= 3
        ? quickstep.toDouble()
        : 3 + (quickstep - 3) * .2;
    movementPrediction.seed(
      epoch,
      MotionBody(
        position: Offset(mine.x, mine.y),
        dashDirection: Offset(mine.dashX, mine.dashY),
        dashRemaining: mine.dashRemaining,
        cooldown: mine.cooldown,
        dashSeq: mine.dashSeq.toInt(),
        dashCapacity: (gun?.data['dashCapacity'] as num?)?.toInt() ?? 1,
        dashCharges: (gun?.data['dashCharges'] as num?)?.toInt() ?? -1,
        rechargeRemaining:
            (gun?.data['dashRecharge'] as num?)?.toDouble() ?? -1,
      ),
      movementSpeed:
          (gun?.baseNumber(
                'movement',
                gun?.survivor == 'warden'
                    ? 261
                    : gun?.survivor == 'scrapper'
                    ? 345
                    : 300,
              ) ??
              (gun?.survivor == 'warden'
                  ? 261
                  : gun?.survivor == 'scrapper'
                  ? 345
                  : 300)) +
          (walking.clamp(0, 3) * 50 + (walking - 3).clamp(0, 5) * 12) *
              (gun?.strength('walkingSpeedIncrease') ?? 1),
      cooldownDuration:
          (1.6 - effectiveQuickstep * (gun?.strength('quickstep') ?? 1) * .25)
              .clamp(.6, 1.6),
    );
    // Returning from a local menu in the same server epoch starts at the last
    // received sequence; stale inputs from the old prediction are never replayed.
    final snapshot = _client?.myMotion.iter().firstOrNull;
    if (snapshot != null &&
        snapshot.generation == mine.generation &&
        snapshot.roomId == mine.roomId) {
      movementPrediction.reconcile(
        epoch,
        combatObject(snapshot.data),
        _motionMap!,
        _occupied(),
        reducedMotion: predictionReducedMotion,
      );
    }
  }

  void _predict() {
    final at = _time.elapsedMicroseconds;
    final dt = _predictionAt == 0 ? .016 : (at - _predictionAt) / 1000000;
    _predictionAt = at;
    if (_predictionRunning && controlsEnabled) {
      maxPredictionTimerGapMs = math.max(maxPredictionTimerGapMs, dt * 1000);
    }
    if (!predictionAvailable ||
        !controlsEnabled ||
        me == null ||
        _client == null) {
      if (_predictionRunning) {
        _predictionRunning = false;
        movementPrediction.reset();
        _predictionEpoch = null;
        final mine = me, client = _client;
        if (connected && mine != null && client != null) {
          unawaited(
            _quiet(
              () => client.reducers.stopMotion(
                roomid: mine.roomId,
                generation: mine.generation,
              ),
            ),
          );
        }
      }
      projectilePresentation.cancelPrediction();
      return;
    }
    _predictionRunning = true;
    _seedPrediction();
    movementPrediction.advance(
      dt,
      Offset(moveX, moveY),
      Offset(aimX, aimY),
      _dash,
      _motionMap!,
      _occupied(),
      _sendMotion,
    );
    _predictProjectiles();
  }

  void _sendMotion(MotionInput input) {
    final client = _client!, mine = me!, epoch = _epoch;
    unawaited(() async {
      try {
        await client.reducers
            .queueMotion(
              roomid: mine.roomId,
              generation: mine.generation,
              seq: Int64(input.seq),
              movex: input.movement.dx,
              movey: input.movement.dy,
              aimx: input.aim.dx,
              aimy: input.aim.dy,
              dashseq: Int64(input.dash),
            )
            .timeout(const Duration(seconds: 4));
      } on ReducerException {
        if (!_closed &&
            epoch == _epoch &&
            me?.generation == mine.generation &&
            controlsEnabled) {
          // Resynchronize without replaying rejected movement or trusting a
          // local position. This also bounds the effect of a full queue.
          neutral();
          movementPrediction.reset();
          _predictionEpoch = null;
        }
      } catch (_) {
        if (!_closed && epoch == _epoch && connected) _lost();
      }
    }());
  }

  bool _renewingAccount = false;
  DateTime? _nextAccountRenewal;
  Future<void> _renewAccountSocket() async {
    if (_renewingAccount || tokens is! AccountOnlineTokens) return;
    _renewingAccount = true;
    _nextAccountRenewal = DateTime.now().add(const Duration(seconds: 20));
    try {
      await (tokens as AccountOnlineTokens).account.accessToken();
      if (_closed || suspended) return;
      connected = false;
      _lostAt ??= DateTime.now();
      await connect();
    } catch (_) {
      final expires =
          (tokens as AccountOnlineTokens).account.session?.expiresAt ?? 0;
      if (expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        connected = false;
        guestRejected = true;
        status = 'Sign in again';
        error = 'Sign in again from Settings. Solo and Training are available.';
        _notify();
      }
    } finally {
      _renewingAccount = false;
    }
  }

  void _tick() {
    if (!connected || suspended || _closed) return;
    if (tokens is AccountOnlineTokens &&
        !_renewingAccount &&
        (_nextAccountRenewal == null ||
            DateTime.now().isAfter(_nextAccountRenewal!))) {
      final expires =
          (tokens as AccountOnlineTokens).account.session?.expiresAt ?? 0;
      if (expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45) {
        unawaited(_renewAccountSocket());
      }
    }
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
    if (!controlsEnabled || mine == null || r == null) {
      combatInputPump.reset();
      return;
    }
    if (match != null && gun?.enabled == true) {
      final client = _client!, epoch = _epoch, burst = _fireBurst;
      combatInputPump.tick(_time.elapsedMicroseconds / 1e6, firing, _reloadSeq, (
        held,
        reload,
      ) async {
        try {
          final sequence = Int64(++_combatSeq);
          final response =
              await (projectileInputsAvailable
                      ? client.reducers.combatInputV2(
                          roomid: r.id,
                          generation: mine.generation,
                          seq: sequence,
                          reloadseq: Int64(reload),
                          firing: held,
                          burst: Int64(burst),
                        )
                      : client.reducers.combatInput(
                          roomid: r.id,
                          generation: mine.generation,
                          seq: sequence,
                          reloadseq: Int64(reload),
                          firing: held,
                        ))
                  .timeout(const Duration(seconds: 4));
          return response.isSuccess;
        } on ReducerException {
          // Batched arrivals can hit the server's 10ms limit. Retry the latest
          // intent on the next bounded send; an old rejection must not release
          // the player's current sticks or replay a previous reload.
          return false;
        } catch (_) {
          if (!_closed && epoch == _epoch && connected) _lost();
          return false;
        }
      }, burst: burst);
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
    if (predictionAvailable || _sending) return;
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
    remoteMotion.clear();
    projectilePresentation.clear();
    combatInputPump.reset();
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
      // Commands may immediately depend on their new room/owner state (create
      // enables combat). Flush the cache before completing the command even
      // when subscription row notifications are coalesced.
      _refresh();
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
    upgradeReceipts.clear();
    // Detach ownership before awaiting: route disposal and a simultaneous
    // lifecycle disconnect may both arrive while cancellation is pending.
    final subscriptions = List<StreamSubscription<dynamic>>.of(_listeners);
    _listeners.clear();
    final old = _client;
    _client = null;
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    await old?.dispose();
  }

  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    ++_epoch;
    connected = false;
    remoteMotion.clear();
    projectilePresentation.clear();
    combatInputPump.reset();
    neutral();
    _retry?.cancel();
    _clock?.cancel();
    _predictionClock?.cancel();
    movementPrediction.reset();
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

/// Account service owns refresh credentials; the socket may only reuse its JWT.
class AccountOnlineTokens implements AuthTokenStore {
  AccountOnlineTokens(this.account);
  final AccountController account;
  @override
  Future<String?> loadToken() async {
    if (!account.ready) {
      throw StateError('Verify your email and choose a username in Settings.');
    }
    return account.accessToken();
  }

  @override
  Future<void> saveToken(String token) async {}
  @override
  Future<void> clearToken() async {}
}
