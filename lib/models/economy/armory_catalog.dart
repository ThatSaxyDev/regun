/// Earned-Scrap permanent unlocks. IDs/gates match the server Armory contract.
const armoryWeapons = <String, ({String title, int bosses, int price})>{
  'beltRepeater': (title: 'Belt-fed Repeater', bosses: 5, price: 10000),
  'longwatchSniper': (title: 'Longwatch Sniper', bosses: 30, price: 8500),
  'flakRegent': (title: 'Flak Regent', bosses: 36, price: 8000),
  'anchorEngine': (title: 'Anchor Engine', bosses: 40, price: 11000),
  'cycloneBreacher': (title: 'Cyclone Breacher', bosses: 48, price: 12500),
  'mourningBell': (title: 'Mourning Bell', bosses: 52, price: 15000),
};

class ArmoryCatalog {
  const ArmoryCatalog({
    required this.version,
    required this.enabled,
    required this.prices,
    required this.available,
  });
  static final bundled = ArmoryCatalog(
    version: 'scrap-armory-r0',
    enabled: false,
    prices: {for (final e in armoryWeapons.entries) e.key: e.value.price},
    available: armoryWeapons.keys.toSet(),
  );
  final String version;
  final bool enabled;
  final Map<String, int> prices;
  final Set<String> available;
  factory ArmoryCatalog.fromJson(Map<String, dynamic> raw) {
    if (raw['minimumWeaponAccessVersion'] != 2 ||
        raw['version'] is! String ||
        !RegExp(r'^scrap-armory-r\d+$').hasMatch(raw['version']) ||
        raw['enabled'] is! bool ||
        raw['prices'] is! Map ||
        raw['available'] is! Map) {
      throw const FormatException('Invalid Armory catalogue');
    }
    final prices = <String, int>{}, available = <String>{};
    for (final id in armoryWeapons.keys) {
      final price = raw['prices'][id], flag = raw['available'][id];
      if (price is! int || price < 8000 || price > 15000 || flag is! bool) {
        throw const FormatException('Invalid Armory offer');
      }
      prices[id] = price;
      if (flag) available.add(id);
    }
    return ArmoryCatalog(
      version: raw['version'],
      enabled: raw['enabled'],
      prices: Map.unmodifiable(prices),
      available: Set.unmodifiable(available),
    );
  }
  Map<String, dynamic> toJson() => {
    'minimumWeaponAccessVersion': 2,
    'version': version,
    'enabled': enabled,
    'prices': prices,
    'available': {
      for (final id in armoryWeapons.keys) id: available.contains(id),
    },
  };
}
