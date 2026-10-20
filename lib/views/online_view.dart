import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/online_player_label.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/online_arena.dart';

class OnlineView extends StatefulWidget {
  const OnlineView({super.key, this.session});
  final OnlineSession? session;
  @override
  State<OnlineView> createState() => _OnlineViewState();
}

class _OnlineViewState extends State<OnlineView> with WidgetsBindingObserver {
  late final session = widget.session ?? OnlineSession();
  final name = TextEditingController(text: 'Rook');
  final code = TextEditingController();
  StreamSubscription<void>? listener;
  String mode = 'coop', map = 'breach';
  int teamSize = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    listener = session.changes.stream.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(session.connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(session.resume());
    } else {
      unawaited(session.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    listener?.cancel();
    unawaited(session.close());
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Widget button(String label, VoidCallback? action) => ClickButton(
    text: label,
    height: 46,
    fontSize: 11,
    onTap: session.busy ? null : action,
  );
  Widget choices(List<(String, VoidCallback)> options) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final option in options)
        SizedBox(width: 180, child: button(option.$1, option.$2)),
    ],
  );
  Widget field(
    TextEditingController controller,
    String label,
    int length, {
    bool uppercase = false,
  }) => SizedBox(
    width: 340,
    child: TextField(
      controller: controller,
      maxLength: length,
      autocorrect: false,
      textCapitalization: uppercase
          ? TextCapitalization.characters
          : TextCapitalization.words,
      inputFormatters: uppercase
          ? [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))]
          : null,
      style: const TextStyle(
        fontFamily: FontFam.orbitron,
        color: Color(0xffE5DDD1),
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xff6F604B)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xffC6A66F)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (session.active) return OnlineArena(session: session);
    final room = session.room;
    final enabled = session.connected && !session.busy;
    return MenuPage(
      title: 'Online | connection test',
      body: MenuScrollBody(
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 15,
            color: Color(0xffE5DDD1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.status,
                style: TextStyle(
                  color: session.connected
                      ? const Color(0xffA9C990)
                      : const Color(0xffD9AD70),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Private rooms and movement only. Shooting, enemies and rewards are still being connected.',
              ),
              if (session.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    session.error,
                    style: const TextStyle(color: Color(0xffED9E8C)),
                  ),
                ),
              if (!session.connected) ...[
                const SizedBox(height: 12),
                button('Retry connection', () => unawaited(session.connect())),
              ],
              const SizedBox(height: 20),
              if (room == null) ...[
                field(name, 'Player name', 20),
                const SizedBox(height: 16),
                choices([
                  (
                    'Co-op${mode == 'coop' ? ' [x]' : ''}',
                    () => setState(() => mode = 'coop'),
                  ),
                  (
                    'Versus${mode == 'versus' ? ' [x]' : ''}',
                    () => setState(() => mode = 'versus'),
                  ),
                ]),
                const SizedBox(height: 14),
                if (mode == 'coop') ...[
                  const Text('2–3 friends | regular survival arenas'),
                  const SizedBox(height: 10),
                  choices([
                    (
                      'Breach${map == 'breach' ? ' [x]' : ''}',
                      () => setState(() => map = 'breach'),
                    ),
                    (
                      'Foundry${map == 'foundry' ? ' [x]' : ''}',
                      () => setState(() => map = 'foundry'),
                    ),
                  ]),
                ] else ...[
                  const Text('Enemies On by default | internal test arena'),
                  const SizedBox(height: 10),
                  choices([
                    for (final size in [1, 2, 3])
                      (
                        '$size v $size${teamSize == size ? ' [x]' : ''}',
                        () => setState(() => teamSize = size),
                      ),
                  ]),
                ],
                const SizedBox(height: 16),
                button(
                  'Create room',
                  enabled && name.text.trim().isNotEmpty
                      ? () => unawaited(
                          session.create(
                            name: name.text,
                            mode: mode,
                            teamSize: mode == 'coop' ? 0 : teamSize,
                            map: mode == 'coop' ? map : 'network_lab',
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 28),
                field(code, 'Room code', 10, uppercase: true),
                const SizedBox(height: 12),
                button(
                  'Join room',
                  enabled
                      ? () => unawaited(session.join(code.text, name.text))
                      : null,
                ),
              ] else ...[
                Row(
                  children: [
                    Flexible(
                      child: SelectableText(
                        'ROOM ${room.code}',
                        style: const TextStyle(
                          fontFamily: FontFam.pressStart,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    button('Copy code', () {
                      unawaited(
                        Clipboard.setData(ClipboardData(text: room.code)),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room code copied')),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${room.mode == 'coop' ? 'Co-op | ${room.mapId}' : '${room.teamSize} v ${room.teamSize}'} | ${session.members.length}/${room.capacity} players',
                ),
                const SizedBox(height: 12),
                for (final member in session.members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OnlinePlayerLabel(
                      member: member,
                      age: session.pingAge(member),
                      online: session.connected,
                      suffix:
                          '${member.identity.toHexString == session.identity ? ' | You' : ''}'
                          '${room.mode == 'versus' ? ' | Team ${member.team + 1}' : ''}'
                          ' | ${member.ready ? 'Ready' : 'Not ready'}',
                    ),
                  ),
                if (room.mode == 'versus') ...[
                  choices([
                    for (final team in [0, 1])
                      ('Team ${team + 1}', () => unawaited(session.team(team))),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'Enemies ${room.enemies ? 'On' : 'Off'}${session.owner ? '' : ' | Host chooses'}',
                  ),
                  if (session.owner)
                    choices([
                      ('Enemies On', () => unawaited(session.enemies(true))),
                      ('Enemies Off', () => unawaited(session.enemies(false))),
                    ]),
                  const SizedBox(height: 12),
                ],
                choices([
                  (
                    (session.me?.ready ?? false) ? 'Not ready' : 'Ready',
                    () => unawaited(session.ready()),
                  ),
                ]),
                const SizedBox(height: 12),
                if (session.owner)
                  button(
                    'Start movement test',
                    enabled && session.canStart
                        ? () => unawaited(session.start())
                        : null,
                  ),
                const SizedBox(height: 12),
                Text(
                  room.mode == 'coop'
                      ? 'Start with 2–3 connected, ready players.'
                      : 'Fill both teams and have everyone ready to start.',
                ),
                const SizedBox(height: 16),
                button(
                  'Leave room',
                  enabled ? () => unawaited(session.leave()) : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
