// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class OnlineResult {
  final String key;
  final Identity identity;
  final Int64 matchId;
  final String data;

  OnlineResult({
    required this.key,
    required this.identity,
    required this.matchId,
    required this.data,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeString(key);
    encoder.writeBytes((identity as Identity).bytes);
    encoder.writeU64(matchId);
    encoder.writeString(data);
  }

  static OnlineResult decodeBsatn(BsatnDecoder decoder) {
    return OnlineResult(
      key: decoder.readString(),
      identity: Identity(decoder.readBytes(32)),
      matchId: decoder.readU64(),
      data: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'identity': identity.toHexString,
      'matchId': matchId.toInt(),
      'data': data,
    };
  }

  factory OnlineResult.fromJson(Map<String, dynamic> json) {
    return OnlineResult(
      key: (json['key'] as String?) ?? '',
      identity: json['identity'],
      matchId: Int64((json['matchId'] as int?) ?? 0),
      data: (json['data'] as String?) ?? '',
    );
  }
}

class OnlineResultDecoder extends RowDecoder<OnlineResult> {
  @override
  OnlineResult decode(BsatnDecoder decoder) {
    return OnlineResult.decodeBsatn(decoder);
  }

  @override
  String? getPrimaryKey(OnlineResult row) {
    return row.key;
  }

  @override
  Map<String, dynamic>? toJson(OnlineResult row) => row.toJson();

  @override
  OnlineResult? fromJson(Map<String, dynamic> json) =>
      OnlineResult.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
