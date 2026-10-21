import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/online_player_label.dart';

class OnlineRoster extends StatelessWidget {
  const OnlineRoster({super.key, required this.session});
  final OnlineSession session;
  @override
  Widget build(BuildContext context) {
    final teams =
        session.room?.mode == 'versus' && (session.room?.teamSize ?? 1) > 1;
    final rows = teams
        ? [
            session.members.where((m) => m.team == 0).toList(),
            session.members.where((m) => m.team == 1).toList(),
          ]
        : [session.members];
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (final member in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: OnlinePlayerLabel(
                          compact: true,
                          member: member,
                          age: session.pingAge(member),
                          online: session.connected,
                          suffix:
                              '${teams ? ' | T${member.team + 1}' : ''}${member.identity.toHexString == session.identity ? ' | You' : ''}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
