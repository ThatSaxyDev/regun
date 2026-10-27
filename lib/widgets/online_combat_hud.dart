import 'package:regun/utils/format_number.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/online_upgrade_picker.dart';
import 'package:regun/notifiers/game_notifier.dart';

class OnlineCombatHud extends StatelessWidget {
  const OnlineCombatHud({super.key, required this.session});
  final OnlineSession session;
  @override
  Widget build(BuildContext context) {
    final gun = session.gun, match = session.match;
    if (gun == null || match == null) return const SizedBox();
    final weapon = WeaponType.values.firstWhere((w) => w.name == gun.weapon);
    final coop = session.room?.mode == 'coop';
    if (match.phase == 'choice') return OnlineUpgradePicker(session: session);
    if (match.phase == 'finished') {
      return Center(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xf0141117),
              border: Border.all(color: const Color(0xffAD9162), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.data['endReason'] == 'server_interrupted'
                      ? 'Match interrupted'
                      : coop
                      ? 'Run complete'
                      : match.winner < 0
                      ? 'Draw'
                      : 'Team ${match.winner + 1} wins',
                  style: const TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 16,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  coop
                      ? '${match.seconds ~/ 60}:${(match.seconds.toInt() % 60).toString().padLeft(2, '0')} | Score ${formatMetric(gun.progress['score'] ?? 0)}'
                      : '${match.wins[0]} - ${match.wins[1]}',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 24,
                    color: Color(0xffE5DDD1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatNumber(gun.kills)} kills | ${formatNumber(gun.deaths)} downed${session.result == null ? ' | Saving…' : ' | +${formatMetric(combatObject(session.result!.data)['scrap'])} online scrap'}',
                  style: const TextStyle(
                    color: Color(0xffB9B7AF),
                    fontFamily: FontFam.orbitron,
                  ),
                ),
                const SizedBox(height: 16),
                if (session.owner)
                  ClickButton(
                    text: 'Play again',
                    onTap: session.busy
                        ? null
                        : () => unawaited(session.rematch()),
                  ),
                if (!session.owner)
                  const Text(
                    'Waiting for the host',
                    style: TextStyle(color: Color(0xffE5DDD1)),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final locked = match.phase != 'active';
    return Stack(
      children: [
        if (locked && ['countdown', 'round_break'].contains(match.phase))
          Center(
            child: Text(
              match.phase == 'countdown'
                  ? 'Ready in ${match.phaseSeconds.ceil()}'
                  : '${match.winner < 0 ? 'Draw' : 'Team ${match.winner + 1} takes the round'}\n${match.phaseSeconds.ceil()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: FontFam.pressStart,
                fontSize: 16,
                color: Color(0xffE5DDD1),
              ),
            ),
          ),
        if (!locked && gun.health <= 0)
          Center(
            child: Text(
              coop
                  ? gun.progress['bledOut'] == true
                        ? 'Watching | Return at the next boss break'
                        : 'Downed | ${(gun.progress['downedRemaining'] as num? ?? 0).ceil()}s | Revive ${(gun.progress['reviveProgress'] as num? ?? 0).toStringAsFixed(1)}/3s'
                  : 'Eliminated | Watching a teammate',
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                color: Color(0xffE5DDD1),
              ),
            ),
          ),
        if (coop && !locked)
          Positioned(
            top: 100,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lv ${gun.progress['level'] ?? 1} | XP ${formatMetric(gun.progress['xp'] ?? 0)} | Cores ${gun.progress['cores'] ?? 0}${gun.progress['guard'] == true ? ' | Guard' : ''}',
                  style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: Color(0xffE5DDD1),
                    fontSize: 12,
                  ),
                ),
                if ((gun.progress['cores'] as num? ?? 0) > 0 &&
                    fusionRecipes.any(
                      (r) =>
                          gun.rank(r.first.name) >= 3 &&
                          gun.rank(r.second.name) >= 2 &&
                          !(gun.data['fusions'] as List? ?? []).contains(r.id),
                    ))
                  SizedBox(
                    width: 140,
                    child: ClickButton(
                      text: 'Fuse core',
                      height: 44,
                      onTap: session.busy
                          ? null
                          : () => unawaited(session.openFusion()),
                    ),
                  ),
                for (final m in session.members.where(
                  (m) =>
                      m.identity.toHexString != session.identity &&
                      session.fighters[m.identity.toHexString]?.health == 0 &&
                      session
                              .fighters[m.identity.toHexString]
                              ?.progress['bledOut'] !=
                          true,
                ))
                  if (session.me != null &&
                      ((m.x - session.me!.x) * (m.x - session.me!.x) +
                              (m.y - session.me!.y) * (m.y - session.me!.y)) <=
                          105 * 105)
                    Listener(
                      onPointerDown: (_) {
                        session.neutral();
                        session.reviveTarget = m.identity.toHexString;
                      },
                      onPointerUp: (_) => session.reviveTarget = '',
                      onPointerCancel: (_) => session.reviveTarget = '',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xff393B2C),
                        child: Text(
                          'Hold to revive ${m.name}',
                          style: const TextStyle(
                            color: Color(0xffE5DDD1),
                            fontFamily: FontFam.orbitron,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        Positioned(
          bottom: 64,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xbb141117),
                  border: Border.all(color: const Color(0xff6F604B)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${gun.health.toStringAsFixed(1)} / ${gun.maxHealth.toStringAsFixed(0)} HP | ${gun.ammo}/${gun.capacity}',
                      style: const TextStyle(
                        fontFamily: FontFam.orbitron,
                        fontSize: 13,
                        color: Color(0xffE5DDD1),
                      ),
                    ),
                    if (gun.reloading)
                      SizedBox(
                        width: 150,
                        height: 80,
                        child: WeaponReloadDisplay(
                          weapon: weapon,
                          progress: gun.reloadProgress,
                          shells: gun.capacity - gun.ammo,
                          tactical: gun.data['reloadTactical'] == true,
                          reducedMotion: LocalPreferences.shared.reducedMotion,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
