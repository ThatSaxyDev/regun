import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class SoloudPlay {
  final SoLoud _soloud = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};

  Future<void> play(String assetPath) async {
    if (!_sources.containsKey(assetPath)) {
      final source = await _soloud.loadAsset('assets/audio/$assetPath');
      _sources[assetPath] = source;
    }
    await _soloud.play(_sources[assetPath]!);
  }
}

final soloudPlayProvider = Provider<SoloudPlay>((ref) {
  return SoloudPlay();
});
