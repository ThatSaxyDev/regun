/// Base supply/sentry impact. Owner modifiers belong to the caller's explicit
/// reaction policy; they never alter the crush fraction or flat blast damage.
class FriendlyImpact {
  static const crushRadius = 62.0,
      bossFraction = .03,
      blastRadius = 205.0,
      blastDamage = 8.0,
      pressureBand = 130.0;
  static double crushDamage({
    required bool boss,
    required double maximum,
    required double current,
  }) => boss ? maximum * bossFraction : current;
}
