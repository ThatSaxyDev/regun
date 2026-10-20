// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class Member {
  final Identity identity;
  final Int64 roomId;
  final String name;
  final int team;
  final int slot;
  final bool ready;
  final bool connected;
  final bool expired;
  final Int64 disconnectedAt;
  final Int64 generation;
  final double x;
  final double y;
  final double aimX;
  final double aimY;
  final double moveX;
  final double moveY;
  final Int64 seq;
  final Int64 lastInputAt;
  final Int64 dashSeq;
  final double dashX;
  final double dashY;
  final double dashRemaining;
  final double cooldown;
  final int pingMs;
  final Int64 pingAt;

  Member({
    required this.identity,
    required this.roomId,
    required this.name,
    required this.team,
    required this.slot,
    required this.ready,
    required this.connected,
    required this.expired,
    required this.disconnectedAt,
    required this.generation,
    required this.x,
    required this.y,
    required this.aimX,
    required this.aimY,
    required this.moveX,
    required this.moveY,
    required this.seq,
    required this.lastInputAt,
    required this.dashSeq,
    required this.dashX,
    required this.dashY,
    required this.dashRemaining,
    required this.cooldown,
    required this.pingMs,
    required this.pingAt,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeBytes((identity as Identity).bytes);
    encoder.writeU64(roomId);
    encoder.writeString(name);
    encoder.writeU8(team);
    encoder.writeU8(slot);
    encoder.writeBool(ready);
    encoder.writeBool(connected);
    encoder.writeBool(expired);
    encoder.writeU64(disconnectedAt);
    encoder.writeU64(generation);
    encoder.writeF64(x);
    encoder.writeF64(y);
    encoder.writeF64(aimX);
    encoder.writeF64(aimY);
    encoder.writeF64(moveX);
    encoder.writeF64(moveY);
    encoder.writeU64(seq);
    encoder.writeU64(lastInputAt);
    encoder.writeU64(dashSeq);
    encoder.writeF64(dashX);
    encoder.writeF64(dashY);
    encoder.writeF64(dashRemaining);
    encoder.writeF64(cooldown);
    encoder.writeU32(pingMs);
    encoder.writeU64(pingAt);
  }

  static Member decodeBsatn(BsatnDecoder decoder) {
    return Member(
      identity: Identity(decoder.readBytes(32)),
      roomId: decoder.readU64(),
      name: decoder.readString(),
      team: decoder.readU8(),
      slot: decoder.readU8(),
      ready: decoder.readBool(),
      connected: decoder.readBool(),
      expired: decoder.readBool(),
      disconnectedAt: decoder.readU64(),
      generation: decoder.readU64(),
      x: decoder.readF64(),
      y: decoder.readF64(),
      aimX: decoder.readF64(),
      aimY: decoder.readF64(),
      moveX: decoder.readF64(),
      moveY: decoder.readF64(),
      seq: decoder.readU64(),
      lastInputAt: decoder.readU64(),
      dashSeq: decoder.readU64(),
      dashX: decoder.readF64(),
      dashY: decoder.readF64(),
      dashRemaining: decoder.readF64(),
      cooldown: decoder.readF64(),
      pingMs: decoder.readU32(),
      pingAt: decoder.readU64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toHexString,
      'roomId': roomId.toInt(),
      'name': name,
      'team': team,
      'slot': slot,
      'ready': ready,
      'connected': connected,
      'expired': expired,
      'disconnectedAt': disconnectedAt.toInt(),
      'generation': generation.toInt(),
      'x': x,
      'y': y,
      'aimX': aimX,
      'aimY': aimY,
      'moveX': moveX,
      'moveY': moveY,
      'seq': seq.toInt(),
      'lastInputAt': lastInputAt.toInt(),
      'dashSeq': dashSeq.toInt(),
      'dashX': dashX,
      'dashY': dashY,
      'dashRemaining': dashRemaining,
      'cooldown': cooldown,
      'pingMs': pingMs,
      'pingAt': pingAt.toInt(),
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      identity: json['identity'],
      roomId: Int64((json['roomId'] as int?) ?? 0),
      name: (json['name'] as String?) ?? '',
      team: (json['team'] as int?) ?? 0,
      slot: (json['slot'] as int?) ?? 0,
      ready: (json['ready'] as bool?) ?? false,
      connected: (json['connected'] as bool?) ?? false,
      expired: (json['expired'] as bool?) ?? false,
      disconnectedAt: Int64((json['disconnectedAt'] as int?) ?? 0),
      generation: Int64((json['generation'] as int?) ?? 0),
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      aimX: (json['aimX'] as num?)?.toDouble() ?? 0.0,
      aimY: (json['aimY'] as num?)?.toDouble() ?? 0.0,
      moveX: (json['moveX'] as num?)?.toDouble() ?? 0.0,
      moveY: (json['moveY'] as num?)?.toDouble() ?? 0.0,
      seq: Int64((json['seq'] as int?) ?? 0),
      lastInputAt: Int64((json['lastInputAt'] as int?) ?? 0),
      dashSeq: Int64((json['dashSeq'] as int?) ?? 0),
      dashX: (json['dashX'] as num?)?.toDouble() ?? 0.0,
      dashY: (json['dashY'] as num?)?.toDouble() ?? 0.0,
      dashRemaining: (json['dashRemaining'] as num?)?.toDouble() ?? 0.0,
      cooldown: (json['cooldown'] as num?)?.toDouble() ?? 0.0,
      pingMs: (json['pingMs'] as int?) ?? 0,
      pingAt: Int64((json['pingAt'] as int?) ?? 0),
    );
  }
}

class MemberDecoder extends RowDecoder<Member> {
  @override
  Member decode(BsatnDecoder decoder) {
    return Member.decodeBsatn(decoder);
  }

  @override
  Identity? getPrimaryKey(Member row) {
    return row.identity;
  }

  @override
  Map<String, dynamic>? toJson(Member row) => row.toJson();

  @override
  Member? fromJson(Map<String, dynamic> json) => Member.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
