// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class SceneView {
  final Int64 id;
  final String kind;
  final String data;

  SceneView({required this.id, required this.kind, required this.data});

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(id);
    encoder.writeString(kind);
    encoder.writeString(data);
  }

  static SceneView decodeBsatn(BsatnDecoder decoder) {
    return SceneView(
      id: decoder.readU64(),
      kind: decoder.readString(),
      data: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id.toInt(), 'kind': kind, 'data': data};
  }

  factory SceneView.fromJson(Map<String, dynamic> json) {
    return SceneView(
      id: Int64((json['id'] as int?) ?? 0),
      kind: (json['kind'] as String?) ?? '',
      data: (json['data'] as String?) ?? '',
    );
  }
}

class SceneViewDecoder extends RowDecoder<SceneView> {
  @override
  SceneView decode(BsatnDecoder decoder) {
    return SceneView.decodeBsatn(decoder);
  }

  @override
  dynamic getPrimaryKey(SceneView row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(SceneView row) => row.toJson();

  @override
  SceneView? fromJson(Map<String, dynamic> json) => SceneView.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
