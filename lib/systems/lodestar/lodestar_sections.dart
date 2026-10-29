import 'dart:math' as math;

/// Stable local IDs; deliberately independent of BossKind and online protocols.
enum LodestarSection {
  head(80),
  accelerator(30),
  mortars(40),
  feeder(25),
  mines(30),
  tail(35);

  const LodestarSection(this.maxIntegrity);
  final double maxIntegrity;
  bool get offensive => this != feeder;
  bool get weapon => this != head && this != feeder;
}

/// Owned by ONE projectile/release, not a global growing encounter ledger.
/// A later section, bounce or chain cannot reacquire this same boss owner.
class LodestarHitLedger {
  final Set<Object> _owners = {};
  bool claim(Object owner) => _owners.add(owner);
}

class LodestarDamage {
  const LodestarDamage(this.section, this.amount, this.broke);
  final LodestarSection section;
  final double amount;
  final bool broke;
}

/// Local integrity and cancellation generations for the future encounter.
/// No rewards, game/provider state, attacks or global registration occur here.
class LodestarSections {
  final Object owner = Object();
  final _integrity = [for (final s in LodestarSection.values) s.maxIntegrity];
  final _generation = List<int>.filled(6, 0);
  bool _defeated = false;
  double integrity(LodestarSection s) => _integrity[s.index];
  bool living(LodestarSection s) => !_defeated && integrity(s) > 0;
  int generation(LodestarSection s) => _generation[s.index];
  bool get defeated => _defeated;
  static final double maxTotal = LodestarSection.values.fold(
    0,
    (a, s) => a + s.maxIntegrity,
  );
  int get brokenWeapons =>
      LodestarSection.values.where((s) => s.weapon && integrity(s) <= 0).length;
  bool get coreExposed => brokenWeapons >= 2;
  double get total => _defeated ? 0 : _integrity.fold(0, (a, b) => a + b);
  double get fraction => total / maxTotal;
  int get mortarSalvo => living(LodestarSection.mortars)
      ? (living(LodestarSection.feeder) ? 3 : 1)
      : 0;

  Map<String, dynamic> checkpoint() => {
    'hp': [..._integrity],
    'dead': _defeated,
  };
  void restore(Map data) {
    final hp = data['hp'] as List;
    for (final s in LodestarSection.values) {
      _integrity[s.index] = (hp[s.index] as num).toDouble();
    }
    _defeated = data['dead'] == true;
  }

  /// Primary damage is local but its consumption/proc ownership is encounter-wide.
  List<LodestarDamage> primary(
    LodestarSection section,
    double amount,
    LodestarHitLedger ledger,
  ) {
    if (!amount.isFinite || amount <= 0 || !living(section)) return const [];
    if (!ledger.claim(owner)) return const [];
    return _apply({section: amount});
  }

  /// Caller supplies only exposed, intersected, cover-visible LIVE sections.
  /// Water-fill shares one total blast budget, including overkill redistribution.
  List<LodestarDamage> blast(
    Iterable<LodestarSection> exposed,
    double budget,
    LodestarHitLedger ledger,
  ) {
    if (!budget.isFinite || budget <= 0 || _defeated) return const [];
    final selected = exposed.toSet().where(living).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (selected.isEmpty || !ledger.claim(owner)) return const [];
    final shares = <LodestarSection, double>{};
    var remaining = budget;
    while (selected.isNotEmpty && remaining > 1e-9) {
      final share = remaining / selected.length;
      final capped = selected.where((s) => integrity(s) <= share).toList();
      if (capped.isEmpty) {
        for (final s in selected) {
          shares[s] = share;
        }
        break;
      }
      for (final s in capped) {
        shares[s] = integrity(s);
        remaining -= integrity(s);
        selected.remove(s);
      }
    }
    return _apply(shares);
  }

  List<LodestarDamage> _apply(Map<LodestarSection, double> amounts) {
    final hits = <LodestarDamage>[];
    // A blast sees the armor state at release contact, never unlocks and kills
    // the head with the same shared damage budget. Armor absorbs its share.
    final armored = !coreExposed;
    for (final entry in amounts.entries) {
      final s = entry.key;
      if (s == LodestarSection.head && armored) {
        hits.add(LodestarDamage(s, 0, false));
        continue;
      }
      final loss = math.min(integrity(s), entry.value);
      _integrity[s.index] -= loss;
      final broke = integrity(s) == 0;
      if (broke) {
        _generation[s.index]++;
        // Feeder loss also invalidates a staged mortar loading plan. Already
        // released shells must remain owned by their separate finite flights.
        if (s == LodestarSection.feeder) {
          _generation[LodestarSection.mortars.index]++;
        }
      }
      hits.add(LodestarDamage(s, loss, broke));
    }
    if (integrity(LodestarSection.head) <= 0) {
      _defeated = true;
      // Keep remaining integrity as a visual shutdown snapshot. All combat and
      // target queries use living()/defeated and become inert immediately.
      for (final s in LodestarSection.values) {
        _generation[s.index]++;
      }
    }
    return List.unmodifiable(hits);
  }
}
