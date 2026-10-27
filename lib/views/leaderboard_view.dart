import 'package:regun/widgets/player_record_panel.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/utils/format_number.dart';
import 'package:regun/utils/constants.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/services/leaderboards.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/survivor_portrait.dart';

const _ink = Color(0xffeee5d4),
    _quiet = Color(0xffb5aa96),
    _brass = Color(0xffedd2a1);
CharacterType _survivor(String id) =>
    CharacterType.values.where((s) => s.name == id).firstOrNull ??
    CharacterType.rook;

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key, this.service});
  final Leaderboards? service;
  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  late final service = widget.service ?? Leaderboards.shared;
  Map<String, dynamic>? config, mine;
  List<Map<String, dynamic>> rows = [];
  String? error, cursor;
  bool busy = false, loaded = false;
  int generation = 0;
  String? owner;
  String get board => 'global';
  @override
  void initState() {
    super.initState();
    owner = service.account.session?.accountId;
    service.account.addListener(_accountChanged);
    final cached = service.cachedBoard;
    if (cached != null) {
      config = Map<String, dynamic>.from(cached['config'] as Map);
      rows = (cached['rows'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      cursor = cached['cursor'] as String?;
      loaded = true;
    }
    unawaited(load(silent: loaded));
  }

  void _accountChanged() {
    final next = service.account.session?.accountId;
    if (owner == next) return;
    owner = next;
    mine = null;
    generation++;
    if (mounted) unawaited(load(silent: loaded));
  }

  @override
  void dispose() {
    generation++;
    service.account.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> load({bool more = false, bool silent = false}) async {
    final ticket = ++generation;
    setState(() => busy = true);
    try {
      if (!more) await service.publishProfile();
      final next = await service.request('/leaderboards/v1/config');
      if (!mounted || ticket != generation) return;
      config = next;
      if (next['enabled'] != true) {
        service.clearPublicCache();
        rows = [];
        cursor = null;
        setState(() {
          busy = false;
          loaded = false;
          error = 'Leaderboards unavailable.';
        });
        return;
      }
      final page = await service.request(
        '/leaderboards/v1/players${more && cursor != null ? '?after=${Uri.encodeQueryComponent(cursor!)}' : ''}',
      );
      if (!mounted || ticket != generation) return;
      final entries = (page['entries'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        rows = more ? [...rows, ...entries] : entries;
        cursor = page['nextCursor'] as String?;
        loaded = true;
        busy = false;
        error = null;
        service.cachedBoard = {
          'config': Map<String, dynamic>.from(next),
          'rows': rows.map((row) => Map<String, dynamic>.from(row)).toList(),
          'cursor': cursor,
        };
      });
      try {
        final entry = await service.myEntry();
        if (mounted && ticket == generation) {
          setState(() => mine = entry == null ? null : {'entry': entry});
        }
      } catch (_) {
        /* The public list never depends on identifying this viewer. */
      }
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          busy = false;
          if (!silent || !loaded) error = e.toString();
        });
      }
    }
  }

  void open(Map<String, dynamic> row) => Navigator.of(context).push<void>(
    GamePageRoute(
      builder: (_) => PublicPlayerView(
        service: service,
        publicId: row['publicId'] as String,
        board: board,
      ),
    ),
  );
  String get localStatus {
    final preferences = service.account.preferences;
    if (preferences.profile.recordQueueFull) {
      return 'Record queue full / retry online';
    }
    final rows = preferences.profile.runRecords.values.where(
      (r) => r['owner'] == preferences.profileOwner,
    );
    final queued = rows.where((r) => r['status'] == 'local').length;
    if (queued > 0) return '$queued scores pending';
    if (rows.any((r) => r['status'] == 'pending_review')) {
      return 'Under review';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => _RecordPage(
    title: 'Leaderboards',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ClickButtonM(
                text: 'Refresh',
                width: 100,
                height: 48,
                onTap: busy ? null : () => unawaited(load()),
              ),
            ],
          ),
        ),
        if (error != null)
          Flexible(
            child: SingleChildScrollView(
              child: Text(error!, style: const TextStyle(color: _brass)),
            ),
          ),
        if (busy && !loaded)
          const LinearProgressIndicator(minHeight: 2, color: _brass),
        Expanded(
          child: loaded && rows.isEmpty
              ? const Center(
                  child: Text('No players yet.', style: TextStyle(color: _ink)),
                )
              : ListView.builder(
                  key: const ValueKey('all-players'),
                  itemCount: rows.length + (cursor != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == rows.length) {
                      return ClickButtonM(
                        text: 'Load more',
                        height: 48,
                        onTap: busy ? null : () => unawaited(load(more: true)),
                      );
                    }
                    final row = rows[index];
                    return Semantics(
                      button: true,
                      label:
                          'Rank ${formatMetric(row['rank'])}, ${row['name']}, ${formatMetric(row['score'])} points',
                      child: InkWell(
                        onTap: () => open(row),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 64),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xff40363d)),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: Text(
                                  formatMetric(row['rank']),
                                  style: const TextStyle(color: _brass),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: SurvivorPortrait(
                                  character: _survivor(
                                    row['survivor'] as String? ?? 'rook',
                                  ),
                                  maxArtSize: 42,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: _ink),
                                    ),
                                    Text(
                                      row['online'] == true
                                          ? 'Playing'
                                          : '${formatMetric(row['runs'] ?? 0)} runs',
                                      style: const TextStyle(
                                        color: _quiet,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formatMetric(row['score']),
                                style: const TextStyle(
                                  color: _brass,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
    footer: Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (localStatus.isNotEmpty)
          Text(
            localStatus,
            style: const TextStyle(color: _quiet, fontSize: 11),
          ),
        Text(
          mine?['entry'] != null
              ? 'YOU / #${formatMetric(mine!['entry']['rank'])} / ${formatMetric(mine!['entry']['score'])}'
              : '',
          style: const TextStyle(color: _quiet, fontSize: 11),
        ),
        if (mine?['entry'] != null)
          ClickButtonM(
            text: 'My profile',
            width: 130,
            height: 48,
            onTap: () => open(Map<String, dynamic>.from(mine!['entry'] as Map)),
          ),
      ],
    ),
  );
}

class PublicPlayerView extends StatefulWidget {
  const PublicPlayerView({
    super.key,
    required this.service,
    required this.publicId,
    required this.board,
  });
  final Leaderboards service;
  final String publicId, board;
  @override
  State<PublicPlayerView> createState() => _PublicPlayerViewState();
}

class _PublicPlayerViewState extends State<PublicPlayerView> {
  Map<String, dynamic>? data;
  String? error;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    data = widget.service.cachedProfile('${widget.board}:${widget.publicId}');
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.service.request(
        '/players/v1/public/${widget.publicId}?board=${Uri.encodeQueryComponent(widget.board)}',
      );
      if (mounted) {
        widget.service.cacheProfile(
          '${widget.board}:${widget.publicId}',
          value,
        );
        setState(() {
          data = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is AccountError && e.status == 404) {
            widget.service.forgetProfile('${widget.board}:${widget.publicId}');
            data = null;
          }
          if (data == null) error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _RecordPage(
    title: 'Player record',
    hideHeader: data != null,
    body: data == null
        ? Center(
            child: error == null
                ? const CircularProgressIndicator(color: _brass)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, style: const TextStyle(color: _quiet)),
                      ClickButtonM(
                        text: 'Retry',
                        onTap: () => unawaited(load()),
                      ),
                    ],
                  ),
          )
        : PlayerRecordPanel(data: data!),
  );
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({
    required this.title,
    required this.body,
    this.footer,
    this.hideHeader = false,
  });
  final String title;
  final Widget body;
  final Widget? footer;
  final bool hideHeader;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme
          .apply(fontFamily: FontFam.orbitron),
    ),
    child: MenuPage(
      title: title,
      body: body,
      footer: footer,
      hideHeader: hideHeader,
    ),
  );
}
