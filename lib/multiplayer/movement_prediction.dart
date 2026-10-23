import 'dart:math' as math;
import 'dart:ui';

/// Match server rules.ts: 50ms simulation, radius 30, <=18-unit collision steps.
/// This predicts presentation only. Health/hits/rewards always use server state.
class MotionMap {
  MotionMap(Map<String, dynamic> geometry)
    : bounds = _rect(geometry['bounds'] as List),
      obstacles = [
        for (final r in geometry['obstacles'] as List) _rect(r as List),
      ];
  static Rect _rect(List r) => Rect.fromLTRB(
    (r[0] as num).toDouble(),
    (r[1] as num).toDouble(),
    (r[2] as num).toDouble(),
    (r[3] as num).toDouble(),
  );
  final Rect bounds;
  final List<Rect> obstacles;
  Offset move(Offset point, Offset delta, [List<Offset> occupied = const []]) {
    var position = point;
    final steps = math.max(1, (delta.distance / 18).ceil());
    for (var i = 0; i < steps; i++) {
      var p = position + delta / steps.toDouble();
      p = Offset(
        p.dx.clamp(bounds.left + 30, bounds.right - 30),
        p.dy.clamp(bounds.top + 30, bounds.bottom - 30),
      );
      for (final obstacle in obstacles) {
        final r = obstacle.inflate(30);
        if (p.dx <= r.left ||
            p.dx >= r.right ||
            p.dy <= r.top ||
            p.dy >= r.bottom) {
          continue;
        }
        final distances = [
          p.dx - r.left,
          r.right - p.dx,
          p.dy - r.top,
          r.bottom - p.dy,
        ];
        final side = distances.indexOf(distances.reduce(math.min));
        p = switch (side) {
          0 => Offset(r.left, p.dy),
          1 => Offset(r.right, p.dy),
          2 => Offset(p.dx, r.top),
          _ => Offset(p.dx, r.bottom),
        };
      }
      if (!occupied.any((other) => (other - p).distance < 59.999)) position = p;
    }
    return position;
  }
}

class MotionInput {
  const MotionInput(this.seq, this.movement, this.aim, this.dash);
  final int seq, dash;
  final Offset movement, aim;
}

class MotionBody {
  const MotionBody({
    required this.position,
    this.dashDirection = const Offset(1, 0),
    this.dashRemaining = 0,
    this.cooldown = 0,
    this.dashSeq = 0,
    this.dashCapacity = 1,
    this.dashCharges = -1,
    this.rechargeRemaining = -1,
  });
  final Offset position, dashDirection;
  final double dashRemaining, cooldown;
  final int dashSeq, dashCapacity, dashCharges;
  final double rechargeRemaining;
  MotionBody step(
    MotionInput? command,
    double dt,
    MotionMap map,
    List<Offset> occupied, {
    required double speed,
    required double dashCooldown,
  }) {
    var movement = command?.movement ?? Offset.zero;
    if (movement.distance > 1) movement /= movement.distance;
    var charges = dashCharges < 0 ? (cooldown > 0 ? 0 : 1) : dashCharges;
    var recharge = rechargeRemaining < 0 ? cooldown : rechargeRemaining;
    final dash =
        command != null &&
        command.dash > dashSeq &&
        charges > 0 &&
        dashRemaining <= 1e-9;
    if (dash) {
      charges--;
      if (recharge <= 0) recharge = dashCooldown;
    }
    if (charges < dashCapacity) {
      recharge -= dt;
      while (recharge <= 1e-9 && charges < dashCapacity) {
        charges++;
        recharge = charges < dashCapacity ? recharge + dashCooldown : 0;
      }
    }
    var direction = dashDirection;
    if (dash) {
      direction = movement != Offset.zero ? movement : command.aim;
      if (direction == Offset.zero) direction = dashDirection;
      direction /= direction.distance == 0 ? 1 : direction.distance;
    }
    final remaining = dash ? .15 : dashRemaining;
    final dashTime = math.min(dt, remaining), walkTime = dt - dashTime;
    return MotionBody(
      position: map.move(
        position,
        direction * (1450 * dashTime) + movement * (speed * walkTime),
        occupied,
      ),
      dashDirection: direction,
      dashRemaining: math.max(0, remaining - dt),
      cooldown: charges > 0 ? 0 : math.max(0, recharge),
      dashCapacity: dashCapacity,
      dashCharges: charges,
      rechargeRemaining: recharge,
      dashSeq: command?.dash ?? dashSeq,
    );
  }
}

class _PendingMotion {
  _PendingMotion(this.input);
  final MotionInput input;
  double elapsed = 0;
}

/// Bounded replay of input commands after the *simulation* acknowledgement.
/// Receipt acknowledgements must never be passed to reconcile().
class MovementPrediction {
  static const step = .05, limit = 12;
  final List<_PendingMotion> _pending = [];
  MotionBody? _base;
  _PendingMotion? _current;
  double _slice = 0;
  double _wallTime = 0,
      _rateSampleAt = 0,
      _serverRate = 1,
      _pace = 1,
      _ackAt = 0;
  int _rateSampleTick = -1, _serverQueued = 0;
  bool timingAvailable = false, projectileProtocolAvailable = false;
  double inputAgeMs = 0, tickIntervalMs = 0;
  int droppedCommands = 0;
  double get simulationRate => _pace;
  int get serverQueued => _serverQueued;
  bool compactAcknowledgements = false;
  double get acknowledgementAge => _wallTime - _ackAt;
  int _next = 0, _tick = -1, _ack = 0;
  String? _epoch;
  Offset _correction = Offset.zero;
  MotionBody? body;
  double speed = 300, dashCooldown = 1.6;
  int get pendingCount => _pending.length;
  int get acknowledged => _ack;
  Offset? get position => body?.position;
  bool get stalled => _pending.length >= limit;

  void reset() {
    _pending.clear();
    _current = null;
    _base = null;
    body = null;
    _epoch = null;
    _tick = -1;
    _ack = 0;
    _next = 0;
    _slice = 0;
    _wallTime = 0;
    _rateSampleAt = 0;
    _serverRate = 1;
    _pace = 1;
    _ackAt = 0;
    _rateSampleTick = -1;
    _serverQueued = 0;
    compactAcknowledgements = false;
    timingAvailable = projectileProtocolAvailable = false;
    inputAgeMs = tickIntervalMs = 0;
    droppedCommands = 0;
    _correction = Offset.zero;
  }

  void seed(
    String epoch,
    MotionBody authoritative, {
    required double movementSpeed,
    required double cooldownDuration,
  }) {
    if (_epoch == epoch && _base != null) return;
    reset();
    _epoch = epoch;
    _base = authoritative;
    body = authoritative;
    speed = movementSpeed;
    dashCooldown = cooldownDuration;
  }

  void reconcile(
    String epoch,
    Map<String, dynamic> snapshot,
    MotionMap map,
    List<Offset> occupied, {
    bool reducedMotion = false,
  }) {
    if (_epoch != epoch || _base == null) return;
    final tick = int.parse(snapshot['tick'] as String),
        ack = int.parse(snapshot['ack'] as String);
    if (tick <= _tick || ack < _ack) return;
    // Track the simulation clock, not reducer receipts. A server callback can
    // take longer than 50ms in wall time; generating exactly 20 commands per
    // wall second otherwise builds a queue even on a healthy connection.
    projectileProtocolAvailable = snapshot['projectileProtocol'] == 2;
    timingAvailable = snapshot.containsKey('inputAgeMs');
    inputAgeMs = (snapshot['inputAgeMs'] as num?)?.toDouble() ?? 0;
    tickIntervalMs = (snapshot['tickIntervalMs'] as num?)?.toDouble() ?? 0;
    droppedCommands = (snapshot['droppedCommands'] as num?)?.toInt() ?? 0;
    compactAcknowledgements = snapshot.containsKey('queueLength');
    _serverQueued =
        (snapshot['queueLength'] as num?)?.toInt() ??
        (snapshot['commands'] as List?)?.length ??
        0;
    if (ack > _ack) _ackAt = _wallTime;
    if (_rateSampleTick < 0) {
      _rateSampleTick = tick;
      _rateSampleAt = _wallTime;
    } else if (_wallTime - _rateSampleAt >= .75) {
      final observed =
          ((tick - _rateSampleTick) * step / (_wallTime - _rateSampleAt)).clamp(
            .5,
            1.0,
          );
      _serverRate += (observed - _serverRate) * .35;
      _rateSampleTick = tick;
      _rateSampleAt = _wallTime;
    }
    final before = rendered(map, occupied);
    _tick = tick;
    _ack = ack;
    _next = math.max(_next, int.parse(snapshot['received'] as String));
    _pending.removeWhere((p) => p.input.seq <= ack);
    _base = MotionBody(
      position: Offset(
        (snapshot['x'] as num).toDouble(),
        (snapshot['y'] as num).toDouble(),
      ),
      dashDirection: Offset(
        (snapshot['dashX'] as num).toDouble(),
        (snapshot['dashY'] as num).toDouble(),
      ),
      dashRemaining: (snapshot['dashRemaining'] as num).toDouble(),
      cooldown: (snapshot['cooldown'] as num).toDouble(),
      dashSeq: int.parse(snapshot['dashSeq'] as String),
      dashCapacity: (snapshot['dashCapacity'] as num?)?.toInt() ?? 1,
      dashCharges: (snapshot['dashCharges'] as num?)?.toInt() ?? -1,
      rechargeRemaining:
          (snapshot['rechargeRemaining'] as num?)?.toDouble() ?? -1,
    );
    speed = (snapshot['speed'] as num).toDouble();
    dashCooldown = (snapshot['dashCooldown'] as num).toDouble();
    _replay(map, occupied);
    final correction = before == null ? Offset.zero : before - body!.position;
    // Teleports, respawns and large corrections are authoritative immediately.
    _correction = reducedMotion || correction.distance > 120
        ? Offset.zero
        : correction;
  }

  void advance(
    double dt,
    Offset movement,
    Offset aim,
    int dash,
    MotionMap map,
    List<Offset> occupied,
    void Function(MotionInput) send,
  ) {
    if (_base == null || !dt.isFinite || dt <= 0) return;
    final wallStep = dt.clamp(0.0, .1);
    _wallTime += wallStep;
    // Keep a small server input buffer while matching its observed cadence.
    // High RTT alone does not slow the clock: queued simulation work does.
    final bufferCorrection = _serverQueued > 2
        ? (1 - (_serverQueued - 2) * .08).clamp(.65, 1.0)
        : 1.0;
    var targetRate = (_serverRate * bufferCorrection).clamp(.6, 1.0);
    if (_pending.length >= limit - 2) targetRate = math.min(targetRate, .65);
    _pace += (targetRate - _pace) * (1 - math.exp(-12 * wallStep));
    var remaining = wallStep * _pace;
    while (remaining > .000001) {
      if (_current == null) {
        if (_pending.length >= limit) break;
        _current = _PendingMotion(MotionInput(++_next, movement, aim, dash));
        _pending.add(_current!);
        _slice = 0;
        send(_current!.input);
      }
      final portion = math.min(remaining, step - _slice);
      _slice += portion;
      _current!.elapsed = _slice;
      remaining -= portion;
      if (_slice >= step - .000001) _current = null;
    }
    _correction *= math.exp(-24 * dt);
    _replay(map, occupied);
  }

  void _replay(MotionMap map, List<Offset> occupied) {
    var state = _base!;
    for (final pending in _pending) {
      state = state.step(
        pending.input,
        pending.elapsed,
        map,
        occupied,
        speed: speed,
        dashCooldown: dashCooldown,
      );
    }
    body = state;
  }

  Offset? rendered(MotionMap map, List<Offset> occupied) =>
      body == null ? null : map.move(body!.position, _correction, occupied);
}
