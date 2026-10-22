// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';

import 'package:spacetimedb/spacetimedb.dart';

import 'reducers.dart';
import 'reducer_args.dart';
import 'fighter.dart';
import 'match_combat.dart';
import 'member.dart';
import 'motion_state.dart';
import 'online_account.dart';
import 'online_result.dart';
import 'projectile.dart';
import 'room.dart';
import 'scene.dart';
import 'probe_reply.dart';
import 'scene_view.dart';

class SpacetimeDbClient {
  final SpacetimeDbConnection connection;
  final SubscriptionManager subscriptions;
  final AuthTokenStore _authStorage;
  final bool _ssl; // Store SSL state for OIDC generation
  late final Reducers reducers;
  StreamSubscription<IdentityTokenMessage>? _identityTokenSub;

  /// Access to ReducerEmitter for event-driven patterns
  ReducerEmitter get reducerEmitter => subscriptions.reducerEmitter;

  /// Current user identity (32-byte public key hash)
  ///
  /// Available after connection is established. Returns null before first IdentityToken message.
  ///
  /// Example:
  /// ```dart
  /// // Check ownership
  /// if (note.ownerId == client.identity?.toHexString) {
  ///   // User owns this note
  /// }
  ///
  /// // Display in UI
  /// print("User: ${client.identity?.toAbbreviated}"); // "2ab4...9f1c"
  /// ```
  Identity? get identity => subscriptions.identity;

  /// Current connection address (16-byte connection ID as hex string)
  ///
  /// Available after connection is established. Returns null before first IdentityToken message.
  String? get address => subscriptions.address;

  /// Current authentication token (JWT string)
  ///
  /// Available after connection is established. Returns null if not authenticated.
  String? get token => connection.token;

  /// Whether offline storage is enabled
  bool get hasOfflineStorage => subscriptions.hasOfflineStorage;

  /// Current sync state for offline mutations
  SyncState get syncState => subscriptions.syncState;

  /// Stream of sync state changes
  Stream<SyncState> get onSyncStateChanged => subscriptions.onSyncStateChanged;

  /// Stream of individual mutation sync results
  Stream<MutationSyncResult> get onMutationSyncResult =>
      subscriptions.onMutationSyncResult;

  TableCache<Fighter> get fighter {
    return subscriptions.cache.getTableByTypedName<Fighter>('fighter');
  }

  TableCache<MatchCombat> get matchCombat {
    return subscriptions.cache.getTableByTypedName<MatchCombat>('match_combat');
  }

  TableCache<Member> get member {
    return subscriptions.cache.getTableByTypedName<Member>('member');
  }

  TableCache<MotionState> get motionState {
    return subscriptions.cache.getTableByTypedName<MotionState>('motion_state');
  }

  TableCache<OnlineAccount> get onlineAccount {
    return subscriptions.cache.getTableByTypedName<OnlineAccount>(
      'online_account',
    );
  }

  TableCache<OnlineResult> get onlineResult {
    return subscriptions.cache.getTableByTypedName<OnlineResult>(
      'online_result',
    );
  }

  TableCache<Projectile> get projectile {
    return subscriptions.cache.getTableByTypedName<Projectile>('projectile');
  }

  TableCache<Room> get room {
    return subscriptions.cache.getTableByTypedName<Room>('room');
  }

  TableCache<Scene> get scene {
    return subscriptions.cache.getTableByTypedName<Scene>('scene');
  }

  TableCache<MotionState> get myMotion {
    return subscriptions.cache.getTableByTypedName<MotionState>('my_motion');
  }

  TableCache<OnlineAccount> get myOnlineAccount {
    return subscriptions.cache.getTableByTypedName<OnlineAccount>(
      'my_online_account',
    );
  }

  TableCache<OnlineResult> get myOnlineResults {
    return subscriptions.cache.getTableByTypedName<OnlineResult>(
      'my_online_results',
    );
  }

  TableCache<ProbeReply> get myProbe {
    return subscriptions.cache.getTableByTypedName<ProbeReply>('my_probe');
  }

  TableCache<Room> get myRoom {
    return subscriptions.cache.getTableByTypedName<Room>('my_room');
  }

  TableCache<MatchCombat> get roomCombat {
    return subscriptions.cache.getTableByTypedName<MatchCombat>('room_combat');
  }

  TableCache<Fighter> get roomFighters {
    return subscriptions.cache.getTableByTypedName<Fighter>('room_fighters');
  }

  TableCache<Member> get roomMembers {
    return subscriptions.cache.getTableByTypedName<Member>('room_members');
  }

  TableCache<Projectile> get roomProjectiles {
    return subscriptions.cache.getTableByTypedName<Projectile>(
      'room_projectiles',
    );
  }

  TableCache<SceneView> get roomScene {
    return subscriptions.cache.getTableByTypedName<SceneView>('room_scene');
  }

  SpacetimeDbClient._({
    required this.connection,
    required this.subscriptions,
    required AuthTokenStore authStorage,
    required bool ssl,
  }) : _authStorage = authStorage,
       _ssl = ssl {
    // Initialize Reducers with ReducerCaller and ReducerEmitter
    reducers = Reducers(subscriptions.reducers, subscriptions.reducerEmitter);
  }

  static Future<SpacetimeDbClient> connect({
    required String host,
    required String database,
    AuthTokenStore? authStorage,
    OfflineStorage? offlineStorage,
    bool ssl = false,
    ConnectionConfig config = const ConnectionConfig(),
    List<String>? initialSubscriptions,
    Duration subscriptionTimeout = const Duration(seconds: 10),
    void Function(SpacetimeDbClient client)? onCacheLoaded,
  }) async {
    // Setup storage (default to in-memory)
    final storage = authStorage ?? InMemoryTokenStore();

    // Try to load existing token
    final savedToken = await storage.loadToken();

    // Connect with token
    final connection = SpacetimeDbConnection(
      host: host,
      database: database,
      initialToken: savedToken,
      ssl: ssl, // Pass SSL config to connection
      config: config, // Pass connection config
    );

    final subscriptionManager = SubscriptionManager(
      connection,
      offlineStorage: offlineStorage,
    );

    // Auto-register table decoders
    subscriptionManager.cache.registerDecoder<Fighter>(
      'fighter',
      FighterDecoder(),
    );
    subscriptionManager.cache.registerDecoder<MatchCombat>(
      'match_combat',
      MatchCombatDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Member>(
      'member',
      MemberDecoder(),
    );
    subscriptionManager.cache.registerDecoder<MotionState>(
      'motion_state',
      MotionStateDecoder(),
    );
    subscriptionManager.cache.registerDecoder<OnlineAccount>(
      'online_account',
      OnlineAccountDecoder(),
    );
    subscriptionManager.cache.registerDecoder<OnlineResult>(
      'online_result',
      OnlineResultDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Projectile>(
      'projectile',
      ProjectileDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Room>('room', RoomDecoder());
    subscriptionManager.cache.registerDecoder<Scene>('scene', SceneDecoder());

    // Auto-register view decoders
    subscriptionManager.cache.registerDecoder<MotionState>(
      'my_motion',
      MotionStateDecoder(),
    );
    subscriptionManager.cache.registerDecoder<OnlineAccount>(
      'my_online_account',
      OnlineAccountDecoder(),
    );
    subscriptionManager.cache.registerDecoder<OnlineResult>(
      'my_online_results',
      OnlineResultDecoder(),
    );
    subscriptionManager.cache.registerDecoder<ProbeReply>(
      'my_probe',
      ProbeReplyDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Room>('my_room', RoomDecoder());
    subscriptionManager.cache.registerDecoder<MatchCombat>(
      'room_combat',
      MatchCombatDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Fighter>(
      'room_fighters',
      FighterDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Member>(
      'room_members',
      MemberDecoder(),
    );
    subscriptionManager.cache.registerDecoder<Projectile>(
      'room_projectiles',
      ProjectileDecoder(),
    );
    subscriptionManager.cache.registerDecoder<SceneView>(
      'room_scene',
      SceneViewDecoder(),
    );

    // Auto-register reducer argument decoders
    subscriptionManager.reducerRegistry.registerDecoder(
      'acknowledge_probe',
      AcknowledgeProbeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'aim_grenade',
      AimGrenadeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'attach_combat',
      AttachCombatArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'ban_upgrade',
      BanUpgradeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'begin_probe',
      BeginProbeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'choose_loadout',
      ChooseLoadoutArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'choose_team',
      ChooseTeamArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'choose_upgrade',
      ChooseUpgradeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'combat_input',
      CombatInputArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'combat_input_v_2',
      CombatInputV2ArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'configure_room',
      ConfigureRoomArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'create_room',
      CreateRoomArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'enable_combat',
      EnableCombatArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'join_room',
      JoinRoomArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'leave_room',
      LeaveRoomArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'open_fusion',
      OpenFusionArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'queue_motion',
      QueueMotionArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'rematch',
      RematchArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'reroll_upgrade',
      RerollUpgradeArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'revive_input',
      ReviveInputArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'set_ready',
      SetReadyArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'start_match',
      StartMatchArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'stop_motion',
      StopMotionArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'submit_input',
      SubmitInputArgsDecoder(),
    );
    subscriptionManager.reducerRegistry.registerDecoder(
      'throw_grenade',
      ThrowGrenadeArgsDecoder(),
    );

    final client = SpacetimeDbClient._(
      connection: connection,
      subscriptions: subscriptionManager,
      authStorage: storage,
      ssl: ssl,
    );

    // Auto-save new tokens
    client._identityTokenSub = subscriptionManager.onIdentityToken.listen((
      msg,
    ) async {
      await storage.saveToken(msg.token);
      connection.updateToken(msg.token);
    });

    // Load cached data before connecting (for offline-first support)
    if (offlineStorage != null) {
      await subscriptionManager.loadFromOfflineCache();
      onCacheLoaded?.call(client);
    }

    // Connect and subscribe - with offline support, this is non-blocking on failure
    try {
      await connection.connect().timeout(config.connectTimeout);
      if (initialSubscriptions != null && initialSubscriptions.isNotEmpty) {
        await subscriptionManager
            .subscribe(initialSubscriptions)
            .timeout(subscriptionTimeout);
      }
    } catch (e) {
      if (offlineStorage != null) {
        // Offline mode: connection failed but we have cached data, continue in offline mode
        SdkLogger.w('Connection failed, operating in offline mode: $e');
      } else {
        await client.dispose();
        rethrow;
      }
    }

    return client;
  }

  Future<void> disconnect() async {
    await connection.disconnect();
  }

  /// Dispose all resources - cancel listeners, dispose subscription manager, close connection.
  ///
  /// Call this when the client is no longer needed (e.g., logout, app shutdown).
  /// After dispose, the client instance should not be reused.
  Future<void> dispose() async {
    _identityTokenSub?.cancel();
    _identityTokenSub = null;
    subscriptions.dispose();
    await connection.disconnect();
  }

  /// Logout - clear stored token and disconnect
  ///
  /// This clears the authentication token from storage and disconnects
  /// from the server. On next connect, the server will assign a new
  /// anonymous identity.
  Future<void> logout() async {
    await _authStorage.clearToken();
    await dispose();
  }

  /// Get authentication URL for OAuth/OIDC provider.
  ///
  /// Example:
  /// ```dart
  /// final url = client.getAuthUrl('google');
  /// await launchUrl(Uri.parse(url)); // Open in browser
  /// ```
  String getAuthUrl(String provider, {String? redirectUri}) {
    final helper = OidcHelper(
      host: connection.host,
      database: connection.database,
      ssl: _ssl, // Uses the captured SSL state
    );
    return helper.getAuthUrl(provider, redirectUri: redirectUri);
  }

  /// Parse token from OAuth callback URL.
  ///
  /// Example:
  /// ```dart
  /// // After user authenticates, your app receives callback:
  /// final token = client.parseTokenFromCallback('myapp://callback?token=abc123');
  /// if (token != null) {
  ///   // Save and reconnect with new token
  /// }
  /// ```
  String? parseTokenFromCallback(String callbackUrl) {
    final helper = OidcHelper(
      host: connection.host,
      database: connection.database,
      ssl: _ssl,
    );
    return helper.parseTokenFromCallback(callbackUrl);
  }
}
