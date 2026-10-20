import 'package:flame/components.dart';

/// A solo encounter and a pair use the same actor registry and attack ownership.
/// Explicit actor IDs prevent one boss death from retiring a surviving partner.
class BossEncounterRuntime {
  final Map<int, PositionComponent> actors = {};
  final Map<PositionComponent, int> _ids = {};
  int _next = 0;
  PositionComponent? _major, _previous;
  bool _released = false;

  int add(PositionComponent actor, {int? restoredId}) {
    final existing = _ids[actor];
    if (existing != null) return existing;
    final id = restoredId ?? _next++;
    if (id >= _next) _next = id + 1;
    actors[id] = actor;
    _ids[actor] = id;
    return id;
  }

  int? idOf(PositionComponent actor) => _ids[actor];
  Iterable<PositionComponent> get live =>
      actors.values.where((actor) => !actor.isRemoving && !actor.isRemoved);
  bool get isEmpty => live.isEmpty;

  bool claim(PositionComponent actor) {
    if (!_ids.containsKey(actor) || actor.isRemoving || actor.isRemoved) {
      return false;
    }
    if (_major != null && _major != actor) return false;
    if (_major == actor && _released && live.length > 1) return false;
    if (_major == null && _previous == actor && live.length > 1) return false;
    _major = actor;
    _previous = actor;
    _released = false;
    return true;
  }

  void release(PositionComponent actor) {
    if (_major == actor) _released = true;
  }

  void advance(bool Function(PositionComponent) hasLingeringAttack) {
    final owner = _major;
    if (owner != null &&
        (owner.isRemoving ||
            owner.isRemoved ||
            (_released && !hasLingeringAttack(owner)))) {
      _major = null;
      _released = false;
    }
  }

  void remove(PositionComponent actor) {
    final id = _ids.remove(actor);
    if (id != null) actors.remove(id);
    if (_major == actor) {
      _major = null;
      _released = false;
    }
  }

  void clear() {
    actors.clear();
    _ids.clear();
    _next = 0;
    _major = null;
    _previous = null;
    _released = false;
  }
}
