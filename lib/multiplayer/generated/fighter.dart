// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class Fighter {
  final String key;
  final Int64 roomId;
  final String data;
  final bool enabled;
  final Int64 generation;
  final Int64 inputSeq;
  final Int64 reloadSeq;
  final Int64 lastInputAt;
  final bool fireHeld;

  Fighter({
    required this.key,
    required this.roomId,
    required this.data,
    required this.enabled,
    required this.generation,
    required this.inputSeq,
    required this.reloadSeq,
    required this.lastInputAt,
    required this.fireHeld,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(key);
    encoder.writeU64(roomId);
    encoder.writeString(data);
    encoder.writeBool(enabled);
    encoder.writeU64(generation);
    encoder.writeU64(inputSeq);
    encoder.writeU64(reloadSeq);
    encoder.writeU64(lastInputAt);
    encoder.writeBool(fireHeld);
  }

  static Fighter decodeBsatn(BsatnDecoder decoder) {
    return Fighter(
      key: decoder.readString(),
      roomId: decoder.readU64(),
      data: decoder.readString(),
      enabled: decoder.readBool(),
      generation: decoder.readU64(),
      inputSeq: decoder.readU64(),
      reloadSeq: decoder.readU64(),
      lastInputAt: decoder.readU64(),
      fireHeld: decoder.readBool(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'roomId': roomId.toInt(),
      'data': data,
      'enabled': enabled,
      'generation': generation.toInt(),
      'inputSeq': inputSeq.toInt(),
      'reloadSeq': reloadSeq.toInt(),
      'lastInputAt': lastInputAt.toInt(),
      'fireHeld': fireHeld,
    };
  }

  factory Fighter.fromJson(Map<String, dynamic> json) {
    return Fighter(
      key: (json['key'] as String?) ?? '',
      roomId: Int64((json['roomId'] as int?) ?? 0),
      data: (json['data'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? false,
      generation: Int64((json['generation'] as int?) ?? 0),
      inputSeq: Int64((json['inputSeq'] as int?) ?? 0),
      reloadSeq: Int64((json['reloadSeq'] as int?) ?? 0),
      lastInputAt: Int64((json['lastInputAt'] as int?) ?? 0),
      fireHeld: (json['fireHeld'] as bool?) ?? false,
    );
  }
}

class FighterDecoder extends RowDecoder<Fighter> {
  @override
  Fighter decode(BsatnDecoder decoder) {
    return Fighter.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(Fighter row) {
    return row.key;
  }

  @override
  Map<String, dynamic>? toJson(Fighter row) => row.toJson();

  @override
  Fighter? fromJson(Map<String, dynamic> json) => Fighter.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
