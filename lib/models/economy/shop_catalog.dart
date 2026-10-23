import 'package:regun/models/player_profile.dart';

class ShopCatalog {
  const ShopCatalog({
    required this.version,
    required this.prices,
    required this.available,
  });
  static const bundled = ShopCatalog(
    version: 'scrap-cosmetics-1',
    prices: shopCosmetics,
    available: {'copper', 'moss', 'ivory', 'rust', 'slate', 'dusk'},
  );
  final String version;
  final Map<String, int> prices;
  final Set<String> available;
  factory ShopCatalog.fromJson(Map<String, dynamic> data) {
    final version = data['version'];
    if (version is! String ||
        !RegExp(r'^scrap-cosmetics-[a-zA-Z0-9-]{1,40}$').hasMatch(version) ||
        data['prices'] is! Map) {
      throw const FormatException('Invalid shop catalogue');
    }
    final raw = data['prices'] as Map;
    final flags = data['available'];
    final prices = <String, int>{};
    final available = <String>{};
    for (final id in shopCosmetics.keys) {
      final value = raw[id];
      if (value == null) {
        continue; // Older deployed catalogues have three styles.
      }
      if (value is! int ||
          value < 25 ||
          value > 5000 ||
          (flags != null && (flags is! Map || flags[id] is! bool))) {
        throw const FormatException('Invalid shop price');
      }
      prices[id] = value;
      if (flags == null || flags[id] == true) available.add(id);
    }
    if (prices.isEmpty) throw const FormatException('Empty shop catalogue');
    return ShopCatalog(
      version: version,
      prices: Map.unmodifiable(prices),
      available: Set.unmodifiable(available),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': version,
    'prices': prices,
    'available': {for (final id in prices.keys) id: available.contains(id)},
  };
}

const shopDescriptions = {
  'copper': 'Warm copper finish. Appearance only.',
  'moss': 'Weathered green finish. Appearance only.',
  'ivory': 'Pale salvaged enamel. Appearance only.',
  'rust': 'Deep iron-red finish. Appearance only.',
  'slate': 'Cold blue-grey finish. Appearance only.',
  'dusk': 'Muted violet finish. Appearance only.',
};
