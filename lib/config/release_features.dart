/// Build 11 and later resolve availability from the public server policy.
/// Change REGUN_ONLINE_PLAY_ENABLED on the server; no app rebuild is needed.
abstract final class ReleaseFeatures {
  static const remoteConfigUrl = 'https://regunserver.kiishi.space/features';
}
