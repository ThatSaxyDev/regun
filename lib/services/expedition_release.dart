import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:regun/services/account/account_api.dart';

class ExpeditionRelease {
  const ExpeditionRelease({
    this.revision = 0,
    this.enabled = false,
    this.pressure = 0,
    this.repairPercent = 30,
    this.startingHealth,
  });

  static const defaultStartingHealth = 6;
  static const bundled = ExpeditionRelease();
  static ExpeditionRelease current = bundled;

  final int revision, pressure, repairPercent;
  final int? startingHealth;
  int get startingHearts => startingHealth ?? defaultStartingHealth;
  // Kept in the signed release/checkpoint payload for hash compatibility.
  // Expedition admission is part of the client and does not use this field.
  final bool enabled;
  String get hash => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            2,
            revision,
            enabled,
            pressure,
            repairPercent,
            if (startingHealth != null) startingHealth,
          ]),
        ),
      )
      .toString();

  Map<String, Object> toJson() => {
    'schema': 1,
    'generator': 2,
    'revision': revision,
    'values': {
      'enabled': enabled,
      'pressure': pressure,
      'repairPercent': repairPercent,
      if (startingHealth != null) 'startingHealth': startingHealth!,
    },
    'hash': hash,
  };

  factory ExpeditionRelease.read(Object? raw) {
    if (raw is! Map || raw['schema'] != 1 || raw['generator'] != 2) {
      throw const FormatException('Unsupported Expedition release');
    }
    final values = raw['values'] as Map;
    final value = ExpeditionRelease(
      revision: raw['revision'] as int,
      enabled: values['enabled'] as bool,
      pressure: values['pressure'] as int,
      repairPercent: values['repairPercent'] as int,
      startingHealth: values['startingHealth'] as int?,
    );
    if (value.revision < 0 ||
        value.revision > 0xffffffff ||
        value.pressure < 0 ||
        value.pressure > 10 ||
        value.repairPercent < 15 ||
        value.repairPercent > 45 ||
        (values.containsKey('startingHealth') &&
            (value.startingHealth == null ||
                value.startingHealth! < 1 ||
                value.startingHealth! > 20)) ||
        value.hash != raw['hash']) {
      throw const FormatException('Invalid Expedition release');
    }
    return value;
  }

  static Future<void> refresh() async {
    final api = AccountApi();
    if (!api.configured) return;
    try {
      current = ExpeditionRelease.read(
        await api.request('/expedition/v1/current'),
      );
    } on Object {
      // Keep the last known balance. Bundled balance is always playable offline.
    }
  }
}
