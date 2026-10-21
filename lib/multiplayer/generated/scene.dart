// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class Scene {
  final Int64 id;
  final Int64 roomId;
  final String kind;
  final String data;

  Scene({
    required this.id,
    required this.roomId,
    required this.kind,
    required this.data,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(id);
    encoder.writeU64(roomId);
    encoder.writeString(kind);
    encoder.writeString(data);
  }

  static Scene decodeBsatn(BsatnDecoder decoder) {
    return Scene(
      id: decoder.readU64(),
      roomId: decoder.readU64(),
      kind: decoder.readString(),
      data: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toInt(),
      'roomId': roomId.toInt(),
      'kind': kind,
      'data': data,
    };
  }

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: Int64((json['id'] as int?) ?? 0),
      roomId: Int64((json['roomId'] as int?) ?? 0),
      kind: (json['kind'] as String?) ?? '',
      data: (json['data'] as String?) ?? '',
    );
  }
}

class SceneDecoder extends RowDecoder<Scene> {
  @override
  Scene decode(BsatnDecoder decoder) {
    return Scene.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(Scene row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Scene row) => row.toJson();

  @override
  Scene? fromJson(Map<String, dynamic> json) => Scene.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
