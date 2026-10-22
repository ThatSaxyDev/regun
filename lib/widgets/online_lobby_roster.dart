import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/generated/member.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/online_preparation.dart';
import 'package:regun/widgets/survivor_portrait.dart';

class OnlineLobbyRoster extends StatelessWidget {
  const OnlineLobbyRoster({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final versus = session.room!.mode == 'versus';
    final scale = MediaQuery.textScalerOf(context).scale(1);
    Widget group(int team) => LayoutBuilder(
      builder: (context, box) {
        final members = session.members
            .where((m) => !versus || m.team == team)
            .toList();
        final count = versus ? session.room!.teamSize : session.room!.capacity;
        final horizontal = !versus && box.maxWidth >= 400 && scale < 1.4;
        final slots = [
          for (var i = 0; i < count; i++)
            i < members.length
                ? _slot(members[i], upright: horizontal)
                : _empty(),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnlineCaption(
              '${versus ? 'Team ${team + 1}' : 'Squad'} / ${members.length}/$count',
            ),
            const SizedBox(height: 8),
            if (horizontal)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: slots[i]),
                    ],
                  ],
                ),
              )
            else
              for (final slot in slots)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: slot),
          ],
        );
      },
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (versus && box.maxWidth >= 450 && scale < 1.5) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: group(0)),
              const SizedBox(width: 12),
              Expanded(child: group(1)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            group(0),
            if (versus) ...[const SizedBox(height: 12), group(1)],
          ],
        );
      },
    );
  }

  Widget _empty() => const CustomPaint(
    painter: OnlinePlate(filled: false),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Center(
        child: Text(
          'Waiting for player',
          style: TextStyle(color: onlineMuted, fontSize: 12),
        ),
      ),
    ),
  );

  Widget _slot(Member member, {bool upright = false}) {
    final id = member.identity.toHexString;
    final gun = session.fighters[id];
    final character =
        CharacterType.values
            .where((c) => c.name == gun?.survivor)
            .firstOrNull ??
        CharacterType.rook;
    final weapon = WeaponType.values
        .where((w) => w.name == gun?.weapon)
        .firstOrNull;
    final connected = session.connected && member.connected && !member.expired;
    final state = !connected
        ? (member.expired ? 'Disconnected' : 'Reconnecting')
        : member.ready
        ? 'Ready'
        : 'Choosing';
    final tags = [
      if (id == session.identity) 'You',
      if (id == session.room!.owner.toHexString) 'Host',
    ].join(' / ');
    final portrait = ExcludeSemantics(
      child: SizedBox(
        width: upright ? 50 : 36,
        height: 42,
        child: SurvivorPortrait(character: character),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: onlineInk, fontSize: 14),
        ),
        if (tags.isNotEmpty)
          Text(tags, style: const TextStyle(color: onlineBrass, fontSize: 10)),
        if (weapon != null)
          Text(
            weapon.title,
            style: const TextStyle(color: onlineMuted, fontSize: 10),
          ),
        Text(
          state,
          style: TextStyle(
            color: connected && member.ready ? onlineGreen : onlineBrass,
            fontSize: 11,
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      child: CustomPaint(
        painter: const OnlinePlate(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: upright
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [portrait, const SizedBox(height: 2), details],
                )
              : Row(
                  children: [
                    portrait,
                    const SizedBox(width: 8),
                    Expanded(child: details),
                  ],
                ),
        ),
      ),
    );
  }
}
