import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// One decoded texture per atlas, shared by every instance. Metadata is measured
/// from source alpha; generation's nonuniform row spacing cannot clip frames.
class RegunArt {
  static final shared = RegunArt();
  final Map<String, ui.Image> _images = {};
  final Map<String, List<Sprite>> _sprites = {};
  final Map<String, Sprite> _rawSprites = {};
  Future<void>? _loading;
  Map<String, dynamic> _manifest = {};
  final _leases = <String, int>{};
  final _pending = <String, Future<void>>{};
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    _manifest =
        jsonDecode(await rootBundle.loadString('assets/art/manifest.json'))
            as Map<String, dynamic>;
    await Future.wait(_manifest.entries
        .where((e) => (e.value as Map)['lazy'] != true)
        .map((entry) => _decode(entry.key)));
  }

  Future<void> _decode(String name) async {
    if (_images.containsKey(name)) return;
    final entry = MapEntry(name, _manifest[name]);
    final bytes = await rootBundle.load('assets/art/${entry.key}.png');
    final data = entry.value as Map<String, dynamic>;
    final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: data['decodeWidth'] as int,
        allowUpscaling: false);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    _images[entry.key] = image;
    if (data['texture'] == true) return;
    final referenceHeight = (data['height'] as num).toDouble() * image.height;
    _sprites[entry.key] = (data['frames'] as List).map((raw) {
      final frame = raw as Map;
      final r =
          (frame['rect'] as List).map((v) => (v as num).toDouble()).toList();
      return _GroundedSprite(
          image,
          ui.Rect.fromLTWH(r[0] * image.width, r[1] * image.height,
              r[2] * image.width, r[3] * image.height),
          (frame['pivot'] as num).toDouble(),
          referenceHeight);
    }).toList();
  }

  /// Only active expansion encounters retain their atlases. A pair fits the
  /// existing texture budget; inactive new bosses are not preloaded globally.
  Future<void> acquire(String name) async {
    await load();
    _leases[name] = (_leases[name] ?? 0) + 1;
    await (_pending[name] ??= _decode(name));
  }

  void release(String name) {
    final count = (_leases[name] ?? 0) - 1;
    if (count > 0) {
      _leases[name] = count;
      return;
    }
    _leases.remove(name);
    if ((_manifest[name] as Map?)?['lazy'] != true) return;
    _sprites.remove(name);
    _rawSprites.removeWhere((key, _) => key.startsWith('$name:'));
    _images.remove(name)?.dispose();
    _pending.remove(name);
  }

  /// Complete full-body cycles: eight full-body poses, evenly spaced at 12 poses/sec.
  SpriteAnimation survivorRun(String survivor, {int facing = 0}) =>
      animation('characters/${survivor}_run',
          row: facing, count: 8, step: 1 / 12);

  bool contains(String name) => _sprites.containsKey(name);
  ui.Image image(String name) => _images[name]!;
  Sprite sprite(String name, int frame) => _sprites[name]![frame];
  SpriteAnimation animation(String name,
      {int row = 0,
      int from = 0,
      int count = 4,
      double step = 0.12,
      bool loop = true}) {
    final columns = _manifest[name]['columns'] as int;
    return SpriteAnimation.spriteList([
      for (var i = from; i < from + count; i++) sprite(name, row * columns + i)
    ], stepTime: step, loop: loop);
  }

  Sprite rawSprite(String name, int frame) {
    return _rawSprites.putIfAbsent('$name:$frame', () {
      final s = sprite(name, frame);
      return Sprite(image(name),
          srcPosition: s.srcPosition, srcSize: s.srcSize);
    });
  }

  int get decodedBytes =>
      _images.values.fold(0, (sum, im) => sum + im.width * im.height * 4);
}

class _GroundedSprite extends Sprite {
  _GroundedSprite(super.image, ui.Rect rect, this.pivot, this.referenceHeight)
      : super(
            srcPosition: Vector2(rect.left, rect.top),
            srcSize: Vector2(rect.width, rect.height));
  final double pivot, referenceHeight;
  @override
  void render(ui.Canvas canvas,
      {Vector2? position,
      Vector2? size,
      Anchor anchor = Anchor.topLeft,
      ui.Paint? overridePaint,
      double? bleed}) {
    final bounds = size ?? Vector2.all(100);
    final scale = bounds.y * 0.8 / referenceHeight;
    final output = srcSize * scale;
    final origin = (position ?? Vector2.zero()) -
        Vector2(bounds.x * anchor.x, bounds.y * anchor.y);
    super.render(canvas,
        position: origin +
            Vector2(
                bounds.x * 0.5 - output.x * pivot, bounds.y * 0.88 - output.y),
        size: output,
        overridePaint: overridePaint);
  }
}
