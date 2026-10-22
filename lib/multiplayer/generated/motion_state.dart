// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class MotionState {
  final Identity identity;
  final Int64 roomId;
  final Int64 generation;
  final String data;

  MotionState({
    required this.identity,
    required this.roomId,
    required this.generation,
    required this.data,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeBytes((identity as Identity).bytes);
    encoder.writeU64(roomId);
    encoder.writeU64(generation);
    encoder.writeString(data);
  }

  static MotionState decodeBsatn(BsatnDecoder decoder) {
    return MotionState(
      identity: Identity(decoder.readBytes(32)),
      roomId: decoder.readU64(),
      generation: decoder.readU64(),
      data: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toHexString,
      'roomId': roomId.toInt(),
      'generation': generation.toInt(),
      'data': data,
    };
  }

  factory MotionState.fromJson(Map<String, dynamic> json) {
    return MotionState(
      identity: json['identity'],
      roomId: Int64((json['roomId'] as int?) ?? 0),
      generation: Int64((json['generation'] as int?) ?? 0),
      data: (json['data'] as String?) ?? '',
    );
  }
}

class MotionStateDecoder extends RowDecoder<MotionState> {
  @override
  MotionState decode(BsatnDecoder decoder) {
    return MotionState.decodeBsatn(decoder);
  }

  @override
  Identity? getPrimaryKey(MotionState row) {
    return row.identity;
  }

  @override
  Map<String, dynamic>? toJson(MotionState row) => row.toJson();

  @override
  MotionState? fromJson(Map<String, dynamic> json) =>
      MotionState.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
