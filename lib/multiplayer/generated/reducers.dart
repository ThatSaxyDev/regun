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
}
