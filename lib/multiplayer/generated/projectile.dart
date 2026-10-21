// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class Projectile {
  final Int64 id;
  final Int64 roomId;
  final String data;

  Projectile({required this.id, required this.roomId, required this.data});

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(id);
    encoder.writeU64(roomId);
    encoder.writeString(data);
  }

  static Projectile decodeBsatn(BsatnDecoder decoder) {
    return Projectile(
      id: decoder.readU64(),
      roomId: decoder.readU64(),
      data: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id.toInt(), 'roomId': roomId.toInt(), 'data': data};
  }

  factory Projectile.fromJson(Map<String, dynamic> json) {
    return Projectile(
      id: Int64((json['id'] as int?) ?? 0),
      roomId: Int64((json['roomId'] as int?) ?? 0),
      data: (json['data'] as String?) ?? '',
    );
  }
}

class ProjectileDecoder extends RowDecoder<Projectile> {
  @override
  Projectile decode(BsatnDecoder decoder) {
    return Projectile.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(Projectile row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Projectile row) => row.toJson();

  @override
  Projectile? fromJson(Map<String, dynamic> json) => Projectile.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
