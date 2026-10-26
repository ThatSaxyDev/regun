import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/widgets/boss_victory_banner.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Active-time feedback; a pair of defeats gets two readable notices.
class BossVictory extends Component with HasGameReference<RegunGame> {
  final current = ValueNotifier<BossKind?>(null);
  final List<BossKind> _waiting = [];
  double remaining = 0;
  int _serial = 0;
  String verb = 'VANQUISHED';
  void show(BossKind kind) {
    if (current.value == null) {
      verb = bossDefeatVerbs[(_serial++) % bossDefeatVerbs.length];
      current.value = kind;
      remaining = 2.8;
    } else if (_waiting.length < 8) {
      _waiting.add(kind);
    }
  }

  void reset() {
    _waiting.clear();
    remaining = 0;
    _serial = 0;
    current.value = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing ||
        current.value == null) {
      return;
    }
    remaining -= dt;
    if (remaining <= 0) {
      final next = _waiting.isEmpty ? null : _waiting.removeAt(0);
      if (next != null) {
        verb =
            bossDefeatVerbs[(_serial++) % bossDefeatVerbs.length];
      }
      current.value = next;
      remaining = current.value == null ? 0 : 2.8;
    }
  }
}
