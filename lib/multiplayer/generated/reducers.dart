// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';

import 'package:spacetimedb/spacetimedb.dart';

import 'reducer_args.dart';

/// Generated reducer methods with async/await support
///
/// All methods return Future<TransactionResult> containing:
/// - status: Committed/Failed/OutOfEnergy
/// - timestamp: When the reducer executed
/// - energyConsumed: Energy used (null for TransactionUpdateLight)
/// - executionDuration: How long it took (null for TransactionUpdateLight)
class Reducers {
  final ReducerCaller _reducerCaller;
  final ReducerEmitter _reducerEmitter;

  Reducers(this._reducerCaller, this._reducerEmitter);

  /// Call the acknowledge_probe reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> acknowledgeProbe({
    required Int64 probe,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(probe);

    return await _reducerCaller.call(
      'acknowledge_probe',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the attach_combat reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> attachCombat({
    required int version,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(version);

    return await _reducerCaller.call(
      'attach_combat',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the ban_upgrade reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> banUpgrade({
    required int offerid,
    required String choice,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(offerid);
    encoder.writeString(choice);

    return await _reducerCaller.call(
      'ban_upgrade',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the begin_probe reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> beginProbe({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'begin_probe',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the choose_loadout reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> chooseLoadout({
    required String weapon,
    required String survivor,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(weapon);
    encoder.writeString(survivor);

    return await _reducerCaller.call(
      'choose_loadout',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the choose_team reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> chooseTeam({
    required int team,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU8(team);

    return await _reducerCaller.call(
      'choose_team',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the choose_upgrade reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> chooseUpgrade({
    required int offerid,
    required String choice,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(offerid);
    encoder.writeString(choice);

    return await _reducerCaller.call(
      'choose_upgrade',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the combat_input reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> combatInput({
    required Int64 roomid,
    required Int64 generation,
    required Int64 seq,
    required Int64 reloadseq,
    required bool firing,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(roomid);
    encoder.writeU64(generation);
    encoder.writeU64(seq);
    encoder.writeU64(reloadseq);
    encoder.writeBool(firing);

    return await _reducerCaller.call(
      'combat_input',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the configure_room reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> configureRoom({
    required bool enemies,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeBool(enemies);

    return await _reducerCaller.call(
      'configure_room',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the create_room reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> createRoom({
    required String mode,
    required int teamsize,
    required String mapid,
    required String name,
    required int protocol,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(mode);
    encoder.writeU8(teamsize);
    encoder.writeString(mapid);
    encoder.writeString(name);
    encoder.writeU32(protocol);

    return await _reducerCaller.call(
      'create_room',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the enable_combat reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> enableCombat({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'enable_combat',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the join_room reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> joinRoom({
    required String code,
    required String name,
    required int protocol,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(code);
    encoder.writeString(name);
    encoder.writeU32(protocol);

    return await _reducerCaller.call(
      'join_room',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the leave_room reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> leaveRoom({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'leave_room',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the open_fusion reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> openFusion({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'open_fusion',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the rematch reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> rematch({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'rematch',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the reroll_upgrade reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> rerollUpgrade({
    required int offerid,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(offerid);

    return await _reducerCaller.call(
      'reroll_upgrade',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the revive_input reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> reviveInput({
    required Int64 roomid,
    required Int64 generation,
    required String target,
    required bool holding,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(roomid);
    encoder.writeU64(generation);
    encoder.writeString(target);
    encoder.writeBool(holding);

    return await _reducerCaller.call(
      'revive_input',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the set_ready reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> setReady({
    required bool ready,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeBool(ready);

    return await _reducerCaller.call(
      'set_ready',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the start_match reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> startMatch({
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call(
      'start_match',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the submit_input reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> submitInput({
    required Int64 roomid,
    required Int64 generation,
    required Int64 seq,
    required double movex,
    required double movey,
    required double aimx,
    required double aimy,
    required Int64 dashseq,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(roomid);
    encoder.writeU64(generation);
    encoder.writeU64(seq);
    encoder.writeF64(movex);
    encoder.writeF64(movey);
    encoder.writeF64(aimx);
    encoder.writeF64(aimy);
    encoder.writeU64(dashseq);

    return await _reducerCaller.call(
      'submit_input',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  /// Call the throw_grenade reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> throwGrenade({
    required Int64 roomid,
    required Int64 generation,
    required Int64 seq,
    List<OptimisticChange>? optimisticChanges,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(roomid);
    encoder.writeU64(generation);
    encoder.writeU64(seq);

    return await _reducerCaller.call(
      'throw_grenade',
      encoder.toBytes(),
      optimisticChanges: optimisticChanges,
    );
  }

  StreamSubscription<void> onAcknowledgeProbe(
    void Function(EventContext ctx, Int64 probe) callback,
  ) {
    return _reducerEmitter.on('acknowledge_probe').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! AcknowledgeProbeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.probe);
    });
  }

  StreamSubscription<void> onAttachCombat(
    void Function(EventContext ctx, int version) callback,
  ) {
    return _reducerEmitter.on('attach_combat').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! AttachCombatArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.version);
    });
  }

  StreamSubscription<void> onBanUpgrade(
    void Function(EventContext ctx, int offerid, String choice) callback,
  ) {
    return _reducerEmitter.on('ban_upgrade').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! BanUpgradeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.offerid, args.choice);
    });
  }

  StreamSubscription<void> onBeginProbe(
    void Function(EventContext ctx) callback,
  ) {
    return _reducerEmitter.on('begin_probe').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! BeginProbeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onChooseLoadout(
    void Function(EventContext ctx, String weapon, String survivor) callback,
  ) {
    return _reducerEmitter.on('choose_loadout').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ChooseLoadoutArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.weapon, args.survivor);
    });
  }

  StreamSubscription<void> onChooseTeam(
    void Function(EventContext ctx, int team) callback,
  ) {
    return _reducerEmitter.on('choose_team').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ChooseTeamArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.team);
    });
  }

  StreamSubscription<void> onChooseUpgrade(
    void Function(EventContext ctx, int offerid, String choice) callback,
  ) {
    return _reducerEmitter.on('choose_upgrade').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ChooseUpgradeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.offerid, args.choice);
    });
  }

  StreamSubscription<void> onCombatInput(
    void Function(
      EventContext ctx,
      Int64 roomid,
      Int64 generation,
      Int64 seq,
      Int64 reloadseq,
      bool firing,
    )
    callback,
  ) {
    return _reducerEmitter.on('combat_input').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! CombatInputArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(
        ctx,
        args.roomid,
        args.generation,
        args.seq,
        args.reloadseq,
        args.firing,
      );
    });
  }

  StreamSubscription<void> onConfigureRoom(
    void Function(EventContext ctx, bool enemies) callback,
  ) {
    return _reducerEmitter.on('configure_room').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ConfigureRoomArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.enemies);
    });
  }

  StreamSubscription<void> onCreateRoom(
    void Function(
      EventContext ctx,
      String mode,
      int teamsize,
      String mapid,
      String name,
      int protocol,
    )
    callback,
  ) {
    return _reducerEmitter.on('create_room').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! CreateRoomArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(
        ctx,
        args.mode,
        args.teamsize,
        args.mapid,
        args.name,
        args.protocol,
      );
    });
  }

  StreamSubscription<void> onEnableCombat(
    void Function(EventContext ctx) callback,
  ) {
    return _reducerEmitter.on('enable_combat').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! EnableCombatArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onJoinRoom(
    void Function(EventContext ctx, String code, String name, int protocol)
    callback,
  ) {
    return _reducerEmitter.on('join_room').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! JoinRoomArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.code, args.name, args.protocol);
    });
  }

  StreamSubscription<void> onLeaveRoom(
    void Function(EventContext ctx) callback,
  ) {
    return _reducerEmitter.on('leave_room').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! LeaveRoomArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onOpenFusion(
    void Function(EventContext ctx) callback,
  ) {
    return _reducerEmitter.on('open_fusion').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! OpenFusionArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onRematch(void Function(EventContext ctx) callback) {
    return _reducerEmitter.on('rematch').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! RematchArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onRerollUpgrade(
    void Function(EventContext ctx, int offerid) callback,
  ) {
    return _reducerEmitter.on('reroll_upgrade').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! RerollUpgradeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.offerid);
    });
  }

  StreamSubscription<void> onReviveInput(
    void Function(
      EventContext ctx,
      Int64 roomid,
      Int64 generation,
      String target,
      bool holding,
    )
    callback,
  ) {
    return _reducerEmitter.on('revive_input').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ReviveInputArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.roomid, args.generation, args.target, args.holding);
    });
  }

  StreamSubscription<void> onSetReady(
    void Function(EventContext ctx, bool ready) callback,
  ) {
    return _reducerEmitter.on('set_ready').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! SetReadyArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.ready);
    });
  }

  StreamSubscription<void> onStartMatch(
    void Function(EventContext ctx) callback,
  ) {
    return _reducerEmitter.on('start_match').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! StartMatchArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onSubmitInput(
    void Function(
      EventContext ctx,
      Int64 roomid,
      Int64 generation,
      Int64 seq,
      double movex,
      double movey,
      double aimx,
      double aimy,
      Int64 dashseq,
    )
    callback,
  ) {
    return _reducerEmitter.on('submit_input').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! SubmitInputArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(
        ctx,
        args.roomid,
        args.generation,
        args.seq,
        args.movex,
        args.movey,
        args.aimx,
        args.aimy,
        args.dashseq,
      );
    });
  }

  StreamSubscription<void> onThrowGrenade(
    void Function(EventContext ctx, Int64 roomid, Int64 generation, Int64 seq)
    callback,
  ) {
    return _reducerEmitter.on('throw_grenade').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ThrowGrenadeArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.roomid, args.generation, args.seq);
    });
  }
}
