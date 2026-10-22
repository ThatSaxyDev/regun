import 'package:regun/widgets/game_notice.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/generated/member.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/online_arena.dart';
import 'package:regun/widgets/online_lobby_roster.dart';
import 'package:regun/widgets/online_preparation.dart';
import 'package:regun/widgets/survivor_portrait.dart';

enum _EntryPath { create, join }

class OnlineView extends StatefulWidget {
  const OnlineView({super.key, this.session});
  final OnlineSession? session;
  @override
  State<OnlineView> createState() => _OnlineViewState();
}

class _OnlineViewState extends State<OnlineView> with WidgetsBindingObserver {
  late final session = widget.session ?? OnlineSession();
  late final name = TextEditingController(
    text: LocalPreferences.shared.onlineName,
  );
  final code = TextEditingController();
  final nameFocus = FocusNode(), codeFocus = FocusNode();
  StreamSubscription<void>? listener;
  Timer? _noticeTimer;
  _EntryPath path = _EntryPath.create;
  String mode = 'coop', map = 'breach', versusMap = 'ossuary_cross';
  int teamSize = 1;
  String notice = '', _inputError = '';
  bool _copied = false, _editingKit = false, _rosterSynced = false;
  bool _leaving = false;
  String? _roomKey;
  Map<String, Member> _previousMembers = {};

  bool get enabled => session.connected && !session.busy;
  bool get validName => name.text.trim().isNotEmpty;
  bool get validCode => RoomCodeFormatter.valid(code.text);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    name.addListener(_inputChanged);
    code.addListener(_inputChanged);
    listener = session.changes.stream.listen((_) {
      if (!mounted) return;
      _membershipChanged();
      setState(() {});
    });
    _membershipChanged();
    unawaited(session.connect());
  }

  void _inputChanged() {
    if (mounted) setState(() => _inputError = '');
  }

  void _membershipChanged() {
    final nextRoom = session.room?.code;
    final current = {
      for (final m in session.members) m.identity.toHexString: m,
    };
    if (!session.connected) {
      _rosterSynced = false;
    } else if (_roomKey == nextRoom && nextRoom != null && _rosterSynced) {
      final joined = current.keys.where(
        (id) => !_previousMembers.containsKey(id),
      );
      final left = _previousMembers.keys.where(
        (id) => !current.containsKey(id),
      );
      final returned = current.keys.where(
        (id) =>
            _previousMembers[id]?.connected == false && current[id]!.connected,
      );
      final lost = current.keys.where(
        (id) =>
            _previousMembers[id]?.connected == true && !current[id]!.connected,
      );
      if (joined.isNotEmpty) {
        _showNotice('${current[joined.first]!.name} joined');
      } else if (left.isNotEmpty) {
        _showNotice('${_previousMembers[left.first]!.name} left');
      } else if (returned.isNotEmpty) {
        _showNotice('${current[returned.first]!.name} reconnected');
      } else if (lost.isNotEmpty) {
        _showNotice('${current[lost.first]!.name} is reconnecting');
      }
    }
    if (_roomKey != nextRoom) {
      _noticeTimer?.cancel();
      notice = '';
      if (_roomKey != null && nextRoom == null) {
        _showNotice(
          _leaving ? 'Left room' : 'This room is no longer available',
        );
      }
      _leaving = false;
      _editingKit = false;
      _copied = false;
    }
    _roomKey = nextRoom;
    _previousMembers = current;
    if (session.connected) _rosterSynced = true;
  }

  void _showNotice(String value) {
    _noticeTimer?.cancel();
    notice = value;
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          notice = '';
          _copied = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(session.resume());
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(session.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noticeTimer?.cancel();
    listener?.cancel();
    unawaited(session.close());
    name.dispose();
    code.dispose();
    nameFocus.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  Widget button(String label, VoidCallback? action, {double? width}) =>
      ClickButton(
        text: label,
        height: 44,
        width: width,
        fontSize: 10,
        onTap: session.busy ? null : action,
      );

  Widget options<T>(
    List<T> values,
    T selected,
    String Function(T) label,
    void Function(T) select, {
    bool available = true,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        OnlineOption(
          label: label(value),
          selected: value == selected,
          onTap: available ? () => select(value) : null,
        ),
    ],
  );

  void _submit() {
    if (!enabled || !validName || (path == _EntryPath.join && !validCode)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(LocalPreferences.shared.saveOnlineName(name.text));
    if (path == _EntryPath.join) {
      unawaited(session.join(code.text, name.text));
    } else {
      unawaited(
        session.create(
          name: name.text,
          mode: mode,
          teamSize: mode == 'coop' ? 0 : teamSize,
          map: mode == 'coop'
              ? map
              : session.combatAvailable
              ? '${versusMap}_${teamSize}v$teamSize'
              : 'network_lab',
        ),
      );
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final value = RoomCodeFormatter.normalize(data?.text ?? '');
      if (value.length > 10 || value.isEmpty) {
        setState(() => _inputError = 'Copy a ten-character room code first.');
        return;
      }
      code.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      codeFocus.requestFocus();
    } on PlatformException {
      if (mounted) {
        setState(
          () => _inputError = 'Paste is unavailable. Enter the code instead.',
        );
      }
    }
  }

  Future<void> _copy() async {
    final value = session.room?.code;
    if (value == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted || session.room?.code != value) return;
      setState(() {
        _copied = true;
        _showNotice('Room code copied');
      });
    } on PlatformException {
      if (mounted) {
        setState(
          () => _showNotice('Could not copy. Select the room code instead.'),
        );
      }
    }
  }

  Future<void> _leave() async {
    _leaving = true;
    await session.leave();
    if (session.room != null) _leaving = false;
  }

  Widget _connection() {
    final connecting = session.connecting;
    final retrying = session.retryScheduled;
    final label = session.connected
        ? 'Connected'
        : connecting
        ? session.status
        : retrying
        ? 'Reconnecting shortly…'
        : session.status;
    return Semantics(
      liveRegion: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                color: session.connected ? onlineGreen : onlineBrass,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: session.connected ? onlineGreen : onlineBrass,
                ),
              ),
            ],
          ),
          if (session.guestRejected)
            button(
              'Start new guest',
              () => unawaited(session.recoverGuest()),
              width: 195,
            ),
          if (!session.connected &&
              !connecting &&
              !retrying &&
              !session.guestRejected)
            button(
              'Retry connection',
              () => unawaited(session.connect()),
              width: 185,
            ),
        ],
      ),
    );
  }

  Widget _error() => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        session.error,
        style: const TextStyle(fontSize: 12, color: onlineError),
      ),
    ),
  );

  Widget _entry() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 20,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          options(
            _EntryPath.values,
            path,
            (p) => p == _EntryPath.create ? 'Create room' : 'Join room',
            (p) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                path = p;
                _inputError = '';
              });
            },
          ),
          _connection(),
        ],
      ),
      if (session.error.isNotEmpty) _error(),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: LayoutBuilder(
          builder: (context, box) {
            final twoColumns =
                box.maxWidth >= 520 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.4;
            final player = OnlineInput(
              controller: name,
              focusNode: nameFocus,
              label: 'Player name',
              hint: 'Your name',
              maxLength: 20,
            );
            final invitation = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnlineInput(
                  controller: code,
                  focusNode: codeFocus,
                  label: 'Room code',
                  hint: 'ABCDE23456',
                  maxLength: 10,
                  code: true,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _paste,
                      child: const Text(
                        'Paste code',
                        style: TextStyle(color: onlineBrass),
                      ),
                    ),
                    Text(
                      validCode
                          ? 'Code ready'
                          : code.text.isEmpty
                          ? '10 letters and numbers'
                          : code.text.length < 10
                          ? '${code.text.length}/10 characters'
                          : 'Check the letters and numbers',
                      style: TextStyle(
                        fontSize: 12,
                        color: validCode ? onlineGreen : onlineMuted,
                      ),
                    ),
                  ],
                ),
                if (_inputError.isNotEmpty)
                  Text(
                    _inputError,
                    style: const TextStyle(color: onlineError, fontSize: 12),
                  ),
              ],
            );
            if (path == _EntryPath.join && twoColumns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: player),
                  const SizedBox(width: 24),
                  Expanded(child: invitation),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                player,
                if (path == _EntryPath.join) ...[
                  const SizedBox(height: 20),
                  invitation,
                ],
              ],
            );
          },
        ),
      ),
      if (path == _EntryPath.create) ...[
        const SizedBox(height: 24),
        const OnlineCaption('Game mode'),
        const SizedBox(height: 8),
        options(
          ['coop', 'versus'],
          mode,
          (v) => v == 'coop' ? 'Co-op' : 'Versus',
          (v) => setState(() => mode = v),
        ),
        const SizedBox(height: 12),
        Text(
          mode == 'coop'
              ? 'Survive together. 2–3 players.'
              : 'First to three rounds. Enemies on by default.',
          style: const TextStyle(fontSize: 12, color: onlineMuted),
        ),
        const SizedBox(height: 20),
        if (mode == 'coop') ...[
          const OnlineCaption('Arena'),
          const SizedBox(height: 8),
          options(
            ['breach', 'foundry'],
            map,
            _mapTitle,
            (v) => setState(() => map = v),
          ),
        ] else ...[
          const OnlineCaption('Teams'),
          const SizedBox(height: 8),
          options(
            [1, 2, 3],
            teamSize,
            (v) => '$v v $v',
            (v) => setState(() => teamSize = v),
          ),
          if (session.combatAvailable) ...[
            const SizedBox(height: 20),
            const OnlineCaption('Arena'),
            const SizedBox(height: 8),
            options(
              ['ossuary_cross', 'ironworks_relay'],
              versusMap,
              _mapTitle,
              (v) => setState(() => versusMap = v),
            ),
          ],
        ],
      ],
    ],
  );

  String _startReason() {
    if (!session.connected) {
      return session.connecting ? 'Reconnecting…' : 'Waiting for connection';
    }
    if (!session.compatible ||
        session.match != null && session.match!.version != 1) {
      return 'This room needs a newer game build';
    }
    if (session.members.any((m) => !m.connected || m.expired)) {
      return 'Waiting for players to reconnect';
    }
    final room = session.room!;
    if (room.mode == 'coop' && session.members.length < 2) {
      return 'Waiting for one more player';
    }
    if (room.mode == 'versus') {
      final missing = room.capacity - session.members.length;
      if (missing > 0) {
        return 'Waiting for $missing more ${missing == 1 ? 'player' : 'players'}';
      }
      if (session.members.where((m) => m.team == 0).length != room.teamSize) {
        return 'Balance the teams to start';
      }
    }
    if (session.match != null &&
        session.members.any(
          (m) => session.fighters[m.identity.toHexString]?.enabled != true,
        )) {
      return 'Preparing player loadouts…';
    }
    final choosing = session.members.where((m) => !m.ready).toList();
    if (choosing.isNotEmpty) {
      return choosing.first.identity.toHexString == session.identity
          ? 'Mark Ready when your kit is set'
          : '${choosing.first.name} is choosing';
    }
    return session.owner ? 'Everyone is ready' : 'Waiting for host to start';
  }

  Widget _lobby() {
    final room = session.room!;
    final roster = OnlineLobbyRoster(session: session);
    final preparation = _kit();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnlineCaption('Room code'),
                const SizedBox(height: 6),
                SelectableText(
                  room.code,
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontWeight: FontWeight.w700,
                    fontSize: 21,
                    letterSpacing: 2,
                    color: onlineInk,
                  ),
                ),
              ],
            ),
            button(_copied ? 'Copied' : 'Copy code', _copy, width: 145),
            Text(
              '${room.mode == 'coop' ? 'Co-op' : '${room.teamSize} v ${room.teamSize}'} / ${_mapTitle(room.mapId)}',
              style: const TextStyle(color: onlineMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!session.connected) _connection(),
        if (session.error.isNotEmpty) _error(),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 620 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.4) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: roster),
                  const SizedBox(width: 28),
                  Expanded(flex: 2, child: preparation),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [roster, const SizedBox(height: 20), preparation],
            );
          },
        ),
        if (room.mode == 'versus') ...[
          const SizedBox(height: 20),
          const OnlineCaption('Team'),
          const SizedBox(height: 8),
          options(
            [0, 1],
            session.me?.team ?? 0,
            (v) => 'Team ${v + 1}',
            (v) => unawaited(session.team(v)),
            available: enabled,
          ),
          const SizedBox(height: 16),
          const OnlineCaption('Enemies'),
          const SizedBox(height: 8),
          if (session.owner)
            options(
              [true, false],
              room.enemies,
              (v) => v ? 'On' : 'Off',
              (v) => unawaited(session.enemies(v)),
              available: enabled,
            )
          else
            Text(
              '${room.enemies ? 'On' : 'Off'} / Host chooses',
              style: const TextStyle(fontSize: 12, color: onlineMuted),
            ),
        ],
      ],
    );
  }

  Widget _kit() {
    final weapon =
        WeaponType.values
            .where((w) => w.name == session.gun?.weapon)
            .firstOrNull ??
        WeaponType.shotgun;
    final character =
        CharacterType.values
            .where((c) => c.name == session.gun?.survivor)
            .firstOrNull ??
        CharacterType.rook;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnlineCaption('Your kit'),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: SurvivorPortrait(character: character),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.title,
                    style: const TextStyle(fontSize: 16, color: onlineInk),
                  ),
                  Text(
                    weapon.title,
                    style: const TextStyle(fontSize: 13, color: onlineBrass),
                  ),
                ],
              ),
            ),
            if (session.match != null)
              TextButton(
                onPressed: () => setState(() => _editingKit = !_editingKit),
                child: Text(
                  _editingKit ? 'Done' : 'Change',
                  style: const TextStyle(color: onlineBrass),
                ),
              ),
          ],
        ),
        if (_editingKit && session.match != null) ...[
          const SizedBox(height: 12),
          const OnlineCaption('Weapon'),
          const SizedBox(height: 8),
          options(
            WeaponType.values.where((w) => w.availableOnline).toList(),
            weapon,
            (w) => w.title,
            (w) => unawaited(session.chooseLoadout(w.name, character.name)),
            available: enabled,
          ),
          if (session.room?.mode == 'coop') ...[
            const SizedBox(height: 16),
            const OnlineCaption('Survivor'),
            const SizedBox(height: 8),
            options(
              CharacterType.values.where((c) => c.availableOnline).toList(),
              character,
              (c) => c.title,
              (c) => unawaited(session.chooseLoadout(weapon.name, c.name)),
              available: enabled,
            ),
          ],
        ],
      ],
    );
  }

  Widget _footer() {
    final inRoom = session.room != null;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice.isNotEmpty)
          GameNoticeStrip(message: notice)
        else if (inRoom)
          Semantics(
            liveRegion: true,
            child: Text(
              notice.isEmpty ? _startReason() : notice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: notice.isEmpty ? onlineMuted : onlineGreen,
                fontSize: 12,
              ),
            ),
          ),
        if (inRoom || notice.isNotEmpty) const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (inRoom) ...[
              button(
                session.me?.ready == true ? 'Not ready' : 'Ready',
                enabled ? () => unawaited(session.ready()) : null,
                width: 140,
              ),
              if (session.owner)
                button(
                  session.match == null ? 'Start test' : 'Start match',
                  enabled && session.canStart
                      ? () => unawaited(session.start())
                      : null,
                  width: 170,
                ),
              TextButton(
                onPressed: enabled ? () => unawaited(_leave()) : null,
                child: const Text(
                  'Leave room',
                  style: TextStyle(color: onlineMuted),
                ),
              ),
            ] else
              button(
                session.busy
                    ? 'Please wait…'
                    : path == _EntryPath.create
                    ? 'Create room'
                    : 'Join room',
                enabled && validName && (path == _EntryPath.create || validCode)
                    ? _submit
                    : null,
                width: 195,
              ),
            if (keyboard)
              TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: const Text(
                  'Hide keyboard',
                  style: TextStyle(color: onlineBrass),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (session.active) return OnlineArena(session: session);
    const style = TextStyle(
      fontFamily: FontFam.orbitron,
      fontSize: 14,
      height: 1.4,
      color: onlineInk,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 12,
            ),
          ),
        ),
      ),
      child: MenuPage(
        title: 'Online',
        hideHeader: MediaQuery.viewInsetsOf(context).bottom > 0,
        footer: DefaultTextStyle(style: style, child: _footer()),
        body: DefaultTextStyle(
          style: style,
          child: MenuScrollBody(
            key: ValueKey(session.room == null ? path.name : 'lobby'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: session.room == null ? _entry() : _lobby(),
          ),
        ),
      ),
    );
  }
}

String _mapTitle(String value) {
  if (value.startsWith('ossuary_cross')) return 'Ossuary Cross';
  if (value.startsWith('ironworks_relay')) return 'Ironworks Relay';
  return switch (value) {
    'breach' => 'The Breach',
    'foundry' => 'The Foundry',
    'network_lab' => 'Practice arena',
    _ => 'Arena',
  };
}
