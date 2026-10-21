// ignore_for_file: unnecessary_cast, unused_import, unnecessary_import, prefer_initializing_formals
// GENERATED REDUCER ARGUMENT CLASSES AND DECODERS - DO NOT MODIFY BY HAND

import 'package:spacetimedb/spacetimedb.dart';

/// Arguments for the acknowledge_probe reducer
class AcknowledgeProbeArgs {
  final Int64 probe;
  AcknowledgeProbeArgs({required this.probe});
}

/// Decoder for acknowledge_probe reducer arguments
class AcknowledgeProbeArgsDecoder
    implements ReducerArgDecoder<AcknowledgeProbeArgs> {
  @override
  AcknowledgeProbeArgs? decode(BsatnDecoder decoder) {
    try {
      final probe = decoder.readU64();

      return AcknowledgeProbeArgs(probe: probe);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the attach_combat reducer
class AttachCombatArgs {
  final int version;
  AttachCombatArgs({required this.version});
}

/// Decoder for attach_combat reducer arguments
class AttachCombatArgsDecoder implements ReducerArgDecoder<AttachCombatArgs> {
  @override
  AttachCombatArgs? decode(BsatnDecoder decoder) {
    try {
      final version = decoder.readU32();

      return AttachCombatArgs(version: version);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the ban_upgrade reducer
class BanUpgradeArgs {
  final int offerid;
  final String choice;
  BanUpgradeArgs({required this.offerid, required this.choice});
}

/// Decoder for ban_upgrade reducer arguments
class BanUpgradeArgsDecoder implements ReducerArgDecoder<BanUpgradeArgs> {
  @override
  BanUpgradeArgs? decode(BsatnDecoder decoder) {
    try {
      final offerid = decoder.readU32();
      final choice = decoder.readString();

      return BanUpgradeArgs(offerid: offerid, choice: choice);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the begin_probe reducer
class BeginProbeArgs {
  BeginProbeArgs();
}

/// Decoder for begin_probe reducer arguments
class BeginProbeArgsDecoder implements ReducerArgDecoder<BeginProbeArgs> {
  @override
  BeginProbeArgs? decode(BsatnDecoder decoder) {
    try {
      return BeginProbeArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the choose_loadout reducer
class ChooseLoadoutArgs {
  final String weapon;
  final String survivor;
  ChooseLoadoutArgs({required this.weapon, required this.survivor});
}

/// Decoder for choose_loadout reducer arguments
class ChooseLoadoutArgsDecoder implements ReducerArgDecoder<ChooseLoadoutArgs> {
  @override
  ChooseLoadoutArgs? decode(BsatnDecoder decoder) {
    try {
      final weapon = decoder.readString();
      final survivor = decoder.readString();

      return ChooseLoadoutArgs(weapon: weapon, survivor: survivor);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the choose_team reducer
class ChooseTeamArgs {
  final int team;
  ChooseTeamArgs({required this.team});
}

/// Decoder for choose_team reducer arguments
class ChooseTeamArgsDecoder implements ReducerArgDecoder<ChooseTeamArgs> {
  @override
  ChooseTeamArgs? decode(BsatnDecoder decoder) {
    try {
      final team = decoder.readU8();

      return ChooseTeamArgs(team: team);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the choose_upgrade reducer
class ChooseUpgradeArgs {
  final int offerid;
  final String choice;
  ChooseUpgradeArgs({required this.offerid, required this.choice});
}

/// Decoder for choose_upgrade reducer arguments
class ChooseUpgradeArgsDecoder implements ReducerArgDecoder<ChooseUpgradeArgs> {
  @override
  ChooseUpgradeArgs? decode(BsatnDecoder decoder) {
    try {
      final offerid = decoder.readU32();
      final choice = decoder.readString();

      return ChooseUpgradeArgs(offerid: offerid, choice: choice);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the combat_input reducer
class CombatInputArgs {
  final Int64 roomid;
  final Int64 generation;
  final Int64 seq;
  final Int64 reloadseq;
  final bool firing;
  CombatInputArgs({
    required this.roomid,
    required this.generation,
    required this.seq,
    required this.reloadseq,
    required this.firing,
  });
}

/// Decoder for combat_input reducer arguments
class CombatInputArgsDecoder implements ReducerArgDecoder<CombatInputArgs> {
  @override
  CombatInputArgs? decode(BsatnDecoder decoder) {
    try {
      final roomid = decoder.readU64();
      final generation = decoder.readU64();
      final seq = decoder.readU64();
      final reloadseq = decoder.readU64();
      final firing = decoder.readBool();

      return CombatInputArgs(
        roomid: roomid,
        generation: generation,
        seq: seq,
        reloadseq: reloadseq,
        firing: firing,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the configure_room reducer
class ConfigureRoomArgs {
  final bool enemies;
  ConfigureRoomArgs({required this.enemies});
}

/// Decoder for configure_room reducer arguments
class ConfigureRoomArgsDecoder implements ReducerArgDecoder<ConfigureRoomArgs> {
  @override
  ConfigureRoomArgs? decode(BsatnDecoder decoder) {
    try {
      final enemies = decoder.readBool();

      return ConfigureRoomArgs(enemies: enemies);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the create_room reducer
class CreateRoomArgs {
  final String mode;
  final int teamsize;
  final String mapid;
  final String name;
  final int protocol;
  CreateRoomArgs({
    required this.mode,
    required this.teamsize,
    required this.mapid,
    required this.name,
    required this.protocol,
  });
}

/// Decoder for create_room reducer arguments
class CreateRoomArgsDecoder implements ReducerArgDecoder<CreateRoomArgs> {
  @override
  CreateRoomArgs? decode(BsatnDecoder decoder) {
    try {
      final mode = decoder.readString();
      final teamsize = decoder.readU8();
      final mapid = decoder.readString();
      final name = decoder.readString();
      final protocol = decoder.readU32();

      return CreateRoomArgs(
        mode: mode,
        teamsize: teamsize,
        mapid: mapid,
        name: name,
        protocol: protocol,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the enable_combat reducer
class EnableCombatArgs {
  EnableCombatArgs();
}

/// Decoder for enable_combat reducer arguments
class EnableCombatArgsDecoder implements ReducerArgDecoder<EnableCombatArgs> {
  @override
  EnableCombatArgs? decode(BsatnDecoder decoder) {
    try {
      return EnableCombatArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the join_room reducer
class JoinRoomArgs {
  final String code;
  final String name;
  final int protocol;
  JoinRoomArgs({
    required this.code,
    required this.name,
    required this.protocol,
  });
}

/// Decoder for join_room reducer arguments
class JoinRoomArgsDecoder implements ReducerArgDecoder<JoinRoomArgs> {
  @override
  JoinRoomArgs? decode(BsatnDecoder decoder) {
    try {
      final code = decoder.readString();
      final name = decoder.readString();
      final protocol = decoder.readU32();

      return JoinRoomArgs(code: code, name: name, protocol: protocol);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the leave_room reducer
class LeaveRoomArgs {
  LeaveRoomArgs();
}

/// Decoder for leave_room reducer arguments
class LeaveRoomArgsDecoder implements ReducerArgDecoder<LeaveRoomArgs> {
  @override
  LeaveRoomArgs? decode(BsatnDecoder decoder) {
    try {
      return LeaveRoomArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the open_fusion reducer
class OpenFusionArgs {
  OpenFusionArgs();
}

/// Decoder for open_fusion reducer arguments
class OpenFusionArgsDecoder implements ReducerArgDecoder<OpenFusionArgs> {
  @override
  OpenFusionArgs? decode(BsatnDecoder decoder) {
    try {
      return OpenFusionArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the rematch reducer
class RematchArgs {
  RematchArgs();
}

/// Decoder for rematch reducer arguments
class RematchArgsDecoder implements ReducerArgDecoder<RematchArgs> {
  @override
  RematchArgs? decode(BsatnDecoder decoder) {
    try {
      return RematchArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the reroll_upgrade reducer
class RerollUpgradeArgs {
  final int offerid;
  RerollUpgradeArgs({required this.offerid});
}

/// Decoder for reroll_upgrade reducer arguments
class RerollUpgradeArgsDecoder implements ReducerArgDecoder<RerollUpgradeArgs> {
  @override
  RerollUpgradeArgs? decode(BsatnDecoder decoder) {
    try {
      final offerid = decoder.readU32();

      return RerollUpgradeArgs(offerid: offerid);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the revive_input reducer
class ReviveInputArgs {
  final Int64 roomid;
  final Int64 generation;
  final String target;
  final bool holding;
  ReviveInputArgs({
    required this.roomid,
    required this.generation,
    required this.target,
    required this.holding,
  });
}

/// Decoder for revive_input reducer arguments
class ReviveInputArgsDecoder implements ReducerArgDecoder<ReviveInputArgs> {
  @override
  ReviveInputArgs? decode(BsatnDecoder decoder) {
    try {
      final roomid = decoder.readU64();
      final generation = decoder.readU64();
      final target = decoder.readString();
      final holding = decoder.readBool();

      return ReviveInputArgs(
        roomid: roomid,
        generation: generation,
        target: target,
        holding: holding,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the set_ready reducer
class SetReadyArgs {
  final bool ready;
  SetReadyArgs({required this.ready});
}

/// Decoder for set_ready reducer arguments
class SetReadyArgsDecoder implements ReducerArgDecoder<SetReadyArgs> {
  @override
  SetReadyArgs? decode(BsatnDecoder decoder) {
    try {
      final ready = decoder.readBool();

      return SetReadyArgs(ready: ready);
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the start_match reducer
class StartMatchArgs {
  StartMatchArgs();
}

/// Decoder for start_match reducer arguments
class StartMatchArgsDecoder implements ReducerArgDecoder<StartMatchArgs> {
  @override
  StartMatchArgs? decode(BsatnDecoder decoder) {
    try {
      return StartMatchArgs();
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the submit_input reducer
class SubmitInputArgs {
  final Int64 roomid;
  final Int64 generation;
  final Int64 seq;
  final double movex;
  final double movey;
  final double aimx;
  final double aimy;
  final Int64 dashseq;
  SubmitInputArgs({
    required this.roomid,
    required this.generation,
    required this.seq,
    required this.movex,
    required this.movey,
    required this.aimx,
    required this.aimy,
    required this.dashseq,
  });
}

/// Decoder for submit_input reducer arguments
class SubmitInputArgsDecoder implements ReducerArgDecoder<SubmitInputArgs> {
  @override
  SubmitInputArgs? decode(BsatnDecoder decoder) {
    try {
      final roomid = decoder.readU64();
      final generation = decoder.readU64();
      final seq = decoder.readU64();
      final movex = decoder.readF64();
      final movey = decoder.readF64();
      final aimx = decoder.readF64();
      final aimy = decoder.readF64();
      final dashseq = decoder.readU64();

      return SubmitInputArgs(
        roomid: roomid,
        generation: generation,
        seq: seq,
        movex: movex,
        movey: movey,
        aimx: aimx,
        aimy: aimy,
        dashseq: dashseq,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}
