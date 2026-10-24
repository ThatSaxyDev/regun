/// Earned Solo recovery only. Eligibility reports share offline progression's
/// device trust boundary; this is not authority for cash or ranked play.
class SoloRecovery {
  SoloRecovery({required this.owner, required this.startingScrap});
  static const price = 55, minimumSeconds = 300;
  final String owner;
  final int startingScrap;
  String stage = 'alive', epoch = '';
  bool continued = false;
  bool busy = false, available = false;
  String message = '';
  bool get pending => ['offered', 'requested', 'prepared'].contains(stage);
  bool eligible(int seconds, bool training) =>
      !training &&
      owner != 'guest' &&
      startingScrap >= price &&
      seconds >= minimumSeconds &&
      !continued;
  Map<String, dynamic> toJson() => {
    'owner': owner,
    'startingScrap': startingScrap,
    'stage': stage,
    'epoch': epoch,
    'continued': continued,
  };
  factory SoloRecovery.fromJson(Map raw) {
    if (raw['owner'] is! String ||
        raw['startingScrap'] is! int ||
        raw['startingScrap'] < 0 ||
        raw['startingScrap'] > 1000000000 ||
        ![
          'alive',
          'offered',
          'requested',
          'prepared',
          'ended',
        ].contains(raw['stage']) ||
        raw['epoch'] is! String ||
        raw['continued'] is! bool) {
      throw const FormatException('Invalid Solo recovery');
    }
    final r = SoloRecovery(
      owner: raw['owner'],
      startingScrap: raw['startingScrap'],
    );
    r.stage = raw['stage'];
    r.epoch = raw['epoch'];
    r.continued = raw['continued'];
    if (r.stage == 'prepared' && !r.continued) {
      throw const FormatException('Invalid recovery receipt state');
    }
    return r;
  }
}
