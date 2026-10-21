// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

class OnlineAccount {
  final Identity identity;
  final Int64 scrap;
  final Int64 matches;
  final Int64 wins;
  final Int64 lastMatch;

  OnlineAccount({
    required this.identity,
    required this.scrap,
    required this.matches,
    required this.wins,
    required this.lastMatch,
  });

  void encodeBsatn(BsatnEncoder encoder) {
    encoder.writeBytes((identity as Identity).bytes);
    encoder.writeU64(scrap);
    encoder.writeU64(matches);
    encoder.writeU64(wins);
    encoder.writeU64(lastMatch);
  }

  static OnlineAccount decodeBsatn(BsatnDecoder decoder) {
    return OnlineAccount(
      identity: Identity(decoder.readBytes(32)),
      scrap: decoder.readU64(),
      matches: decoder.readU64(),
      wins: decoder.readU64(),
      lastMatch: decoder.readU64(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toHexString,
      'scrap': scrap.toInt(),
      'matches': matches.toInt(),
      'wins': wins.toInt(),
      'lastMatch': lastMatch.toInt(),
    };
  }

  factory OnlineAccount.fromJson(Map<String, dynamic> json) {
    return OnlineAccount(
      identity: json['identity'],
      scrap: Int64((json['scrap'] as int?) ?? 0),
      matches: Int64((json['matches'] as int?) ?? 0),
      wins: Int64((json['wins'] as int?) ?? 0),
      lastMatch: Int64((json['lastMatch'] as int?) ?? 0),
    );
  }
}

class OnlineAccountDecoder extends RowDecoder<OnlineAccount> {
  @override
  OnlineAccount decode(BsatnDecoder decoder) {
    return OnlineAccount.decodeBsatn(decoder);
  }

  @override
  Identity? getPrimaryKey(OnlineAccount row) {
    return row.identity;
  }

  @override
  Map<String, dynamic>? toJson(OnlineAccount row) => row.toJson();

  @override
  OnlineAccount? fromJson(Map<String, dynamic> json) =>
      OnlineAccount.fromJson(json);

  @override
  bool get supportsJsonSerialization => true;
}
