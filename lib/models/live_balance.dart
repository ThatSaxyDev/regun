import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:regun/data/balance_catalog.dart';

/// Full immutable numeric input for one run. No network dependency.
class LiveBalance {
  LiveBalance._(this.revision, this.hash, Map<String, num> values)
    : values = Map.unmodifiable(values);
  static final Map<String, dynamic> catalog = jsonDecode(balanceCatalogJson);
  static final String catalogId = catalog['catalogId'];
  static final List<Map<String, dynamic>> fields = (catalog['fields'] as List)
      .cast<Map<String, dynamic>>();
  static final bundled = LiveBalance.create(0, {
    for (final f in fields) f['id'] as String: f['value'] as num,
  });
  final int revision;
  final String hash;
  final Map<String, num> values;
  static Map<String, num> validate(dynamic raw) {
    if (raw is! Map || raw.length != fields.length) {
      throw const FormatException('Incomplete balance');
    }
    final result = <String, num>{};
    for (final f in fields) {
      final v = raw[f['id']];
      if (v is! num ||
          !v.isFinite ||
          v < f['minimum'] ||
          v > f['maximum'] ||
          (f['integer'] == true && v != v.roundToDouble())) {
        throw const FormatException('Invalid balance');
      }
      result[f['id']] = v == v.roundToDouble() ? v.toInt() : v.toDouble();
    }
    const prefix = 'effects.sporelobber.';
    if (result['${prefix}eliteSporeStride']! <
            result['${prefix}sporeStride']! ||
        result['${prefix}sporeLifetime']! < result['${prefix}sporeTick']!) {
      throw const FormatException('Invalid field relationship');
    }
    return result;
  }

  static String digest(Map<String, num> values) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'schema': 1,
            'catalogId': catalogId,
            'values': {
              for (final key in (values.keys.toList()..sort()))
                key: values[key],
            },
          }),
        ),
      )
      .toString();
  factory LiveBalance.create(int revision, Map<String, num> raw) {
    if (revision < 0 || revision > 1000000000) {
      throw const FormatException('Invalid revision');
    }
    final values = validate(raw);
    return LiveBalance._(revision, digest(values), values);
  }
  factory LiveBalance.fromJson(dynamic raw) {
    if (raw is! Map ||
        raw.length != 5 ||
        raw['schema'] != 1 ||
        raw['catalogId'] != catalogId ||
        raw['revision'] is! int) {
      throw const FormatException('Unsupported balance snapshot');
    }
    final values = validate(raw['values']),
        snapshot = LiveBalance.create(raw['revision'], values);
    if (raw['hash'] != snapshot.hash) {
      throw const FormatException('Balance hash mismatch');
    }
    return snapshot;
  }
  double number(String key, num fallback) =>
      (values[key] ?? fallback).toDouble();
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'catalogId': catalogId,
    'revision': revision,
    'hash': hash,
    'values': values,
  };
}
