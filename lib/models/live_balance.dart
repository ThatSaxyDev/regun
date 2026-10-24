import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:regun/data/balance_catalog.dart';

/// Full immutable numeric input for one run. No network dependency.
class LiveBalance {
  LiveBalance._(
    this.revision,
    this.hash,
    Map<String, num> values,
    this.documentCatalogId,
  ) : values = Map.unmodifiable(values);
  static final Map<String, dynamic> catalog = jsonDecode(balanceCatalogJson);
  static final String catalogId = catalog['catalogId'];
  static final List<Map<String, dynamic>> fields = (catalog['fields'] as List)
      .cast<Map<String, dynamic>>();
  static final bundled = LiveBalance.create(0, {
    for (final f in fields) f['id'] as String: f['value'] as num,
  });
  final String documentCatalogId;
  static Map<String, dynamic> documentCatalog(String id) {
    if (id == catalogId) return catalog;
    return (catalog['previousCatalogs'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (c) => c['catalogId'] == id,
          orElse: () =>
              throw const FormatException('Unsupported balance catalogue'),
        );
  }

  final int revision;
  final String hash;
  final Map<String, num> values;
  static Map<String, num> validate(dynamic raw, {String? documentCatalogId}) {
    final fields =
        (documentCatalog(documentCatalogId ?? catalogId)['fields'] as List)
            .cast<Map<String, dynamic>>();
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
    if (result.containsKey('effects.stormorb.orbLifetime') &&
        result['effects.stormorb.orbLifetime']! <
            result['effects.stormorb.orbTick']!) {
      throw const FormatException('Orb lifetime must include an arc tick');
    }
    return result;
  }

  static String digest(Map<String, num> values, {String? documentCatalogId}) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'schema': 1,
                'catalogId': documentCatalogId ?? catalogId,
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
    return LiveBalance._(revision, digest(values), values, catalogId);
  }
  factory LiveBalance.fromJson(dynamic raw) {
    if (raw is! Map ||
        raw.length != 5 ||
        raw['schema'] != 1 ||
        raw['catalogId'] is! String ||
        raw['revision'] is! int) {
      throw const FormatException('Unsupported balance snapshot');
    }
    final id = raw['catalogId'] as String;
    final revision = raw['revision'] as int;
    if (revision < 0 || revision > 1000000000) {
      throw const FormatException('Invalid revision');
    }
    final values = validate(raw['values'], documentCatalogId: id),
        snapshot = LiveBalance._(
          revision,
          digest(values, documentCatalogId: id),
          values,
          id,
        );
    if (raw['hash'] != snapshot.hash) {
      throw const FormatException('Balance hash mismatch');
    }
    return snapshot;
  }
  double number(String key, num fallback) =>
      (values[key] ?? fallback).toDouble();
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'catalogId': documentCatalogId,
    'revision': revision,
    'hash': hash,
    'values': values,
  };
}
