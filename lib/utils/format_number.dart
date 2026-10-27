/// Display-only grouping. Never use formatted text for storage or API values.
String formatNumber(num value) => groupNumberText(value.toString());

String groupNumberText(String value) {
  final match = RegExp(r'^([+-]?)([0-9]+)(\.[0-9]+)?$').firstMatch(value);
  if (match == null) return value;
  final whole = match[2]!.replaceAllMapped(
    RegExp(r'\B(?=([0-9]{3})+(?![0-9]))'),
    (_) => ',',
  );
  return '${match[1]}$whole${match[3] ?? ''}';
}

String formatMetric(Object? value) =>
    value is num ? formatNumber(value) : '$value';
