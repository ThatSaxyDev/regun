// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class Room {
  final Int64 id;
  final String code;
  final Identity owner;
  final String mode;
  final int teamSize;
  final int capacity;
  final bool enemies;
  final String mapId;
  final String phase;
  final Int64 tick;
  final Int64 createdAt;
  final Int64 lastTickAt;
  final int protocol;
  final String geometryHash;

  Room({
    required this.id,
    required this.code,
    required this.owner,
    required this.mode,
    required this.teamSize,
    required this.capacity,
    required this.enemies,
    required this.mapId,
    required this.phase,
    required this.tick,
    required this.createdAt,
    required this.lastTickAt,
    required this.protocol,
    required this.geometryHash,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(id);
    encoder.writeString(code);
    encoder.writeBytes((owner as Identity).bytes);
    encoder.writeString(mode);
    encoder.writeU8(teamSize);
    encoder.writeU8(capacity);
    encoder.writeBool(enemies);
    encoder.writeString(mapId);
    encoder.writeString(phase);
    encoder.writeU64(tick);
    encoder.writeU64(createdAt);
    encoder.writeU64(lastTickAt);
    encoder.writeU32(protocol);
    encoder.writeString(geometryHash);
  }

  static Room decodeBsatn(BsatnDecoder decoder) {
    return Room(
      id: decoder.readU64(),
      code: decoder.readString(),
      owner: Identity(decoder.readBytes(32)),
      mode: decoder.readString(),
      teamSize: decoder.readU8(),
      capacity: decoder.readU8(),
      enemies: decoder.readBool(),
      mapId: decoder.readString(),
      phase: decoder.readString(),
      tick: decoder.readU64(),
      createdAt: decoder.readU64(),
      lastTickAt: decoder.readU64(),
      protocol: decoder.readU32(),
      geometryHash: decoder.readString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toInt(),
      'code': code,
      'owner': owner.toHexString,
      'mode': mode,
      'teamSize': teamSize,
      'capacity': capacity,
      'enemies': enemies,
      'mapId': mapId,
      'phase': phase,
      'tick': tick.toInt(),
      'createdAt': createdAt.toInt(),
      'lastTickAt': lastTickAt.toInt(),
      'protocol': protocol,
      'geometryHash': geometryHash,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: Int64((json['id'] as int?) ?? 0),
      code: (json['code'] as String?) ?? '',
      owner: json['owner'],
      mode: (json['mode'] as String?) ?? '',
      teamSize: (json['teamSize'] as int?) ?? 0,
      capacity: (json['capacity'] as int?) ?? 0,
      enemies: (json['enemies'] as bool?) ?? false,
      mapId: (json['mapId'] as String?) ?? '',
      phase: (json['phase'] as String?) ?? '',
      tick: Int64((json['tick'] as int?) ?? 0),
      createdAt: Int64((json['createdAt'] as int?) ?? 0),
      lastTickAt: Int64((json['lastTickAt'] as int?) ?? 0),
      protocol: (json['protocol'] as int?) ?? 0,
      geometryHash: (json['geometryHash'] as String?) ?? '',
    );
  }
}

class RoomDecoder extends RowDecoder<Room> {
  @override
  Room decode(BsatnDecoder decoder) {
    return Room.decodeBsatn(decoder);
  }

  @override
  Int64? getPrimaryKey(Room row) {
    return row.id;
  }

  @override
  Map<String, dynamic>? toJson(Room row) => row.toJson();

  @override
  Room? fromJson(Map<String, dynamic> json) => Room.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
