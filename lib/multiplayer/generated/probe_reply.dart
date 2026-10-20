// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class ProbeReply {
  final Int64 probe;
  final Int64 sentAt;
  final bool pending;

  ProbeReply({
    required this.probe,
    required this.sentAt,
    required this.pending,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeU64(probe);
    encoder.writeU64(sentAt);
    encoder.writeBool(pending);
  }

  static ProbeReply decodeBsatn(BsatnDecoder decoder) {
    return ProbeReply(
      probe: decoder.readU64(),
      sentAt: decoder.readU64(),
      pending: decoder.readBool(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'probe': probe.toInt(),
      'sentAt': sentAt.toInt(),
      'pending': pending,
    };
  }

  factory ProbeReply.fromJson(Map<String, dynamic> json) {
    return ProbeReply(
      probe: Int64((json['probe'] as int?) ?? 0),
      sentAt: Int64((json['sentAt'] as int?) ?? 0),
      pending: (json['pending'] as bool?) ?? false,
    );
  }
}

class ProbeReplyDecoder extends RowDecoder<ProbeReply> {
  @override
  ProbeReply decode(BsatnDecoder decoder) {
    return ProbeReply.decodeBsatn(decoder);
  }

  @override
  dynamic getPrimaryKey(ProbeReply row) {
    return 0; // Identity-scoped singleton view.
  }

  @override
  Map<String, dynamic>? toJson(ProbeReply row) => row.toJson();

  @override
  ProbeReply? fromJson(Map<String, dynamic> json) => ProbeReply.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
