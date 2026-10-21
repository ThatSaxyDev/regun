// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class MatchCombat {
  final Int64 roomId;
  final String data;

  MatchCombat({required this.roomId, required this.data});

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(roomId);
    encoder.writeString(data);
  }

  static MatchCombat decodeBsatn(BsatnDecoder decoder) {
    return MatchCombat(roomId: decoder.readU64(), data: decoder.readString());
  }

  Map<String, dynamic> toJson() {
    return {'roomId': roomId.toInt(), 'data': data};
  }

  factory MatchCombat.fromJson(Map<String, dynamic> json) {
    return MatchCombat(
      roomId: Int64((json['roomId'] as int?) ?? 0),
      data: (json['data'] as String?) ?? '',
    );
  }
}

class MatchCombatDecoder extends RowDecoder<MatchCombat> {
  @override
  MatchCombat decode(BsatnDecoder decoder) {
    return MatchCombat.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(MatchCombat row) {
    return row.roomId;
  }

  @override
  Map<String, dynamic>? toJson(MatchCombat row) => row.toJson();

  @override
  MatchCombat? fromJson(Map<String, dynamic> json) =>
      MatchCombat.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
