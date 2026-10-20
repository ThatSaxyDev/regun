import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/survivor_portrait.dart';
import 'package:flutter/material.dart';
import 'package:regun/data/challenges.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({super.key});
  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  int tab = 0;
  final tabs = [
    'Upgrades',
    'Fusions',
    'Enemies',
    'Challenges',
    'Style',
    'Credits'
  ];
  PlayerProfile get profile => LocalPreferences.shared.profile;
  @override
  Widget build(BuildContext context) => MenuPage(
      title: 'COLLECTION',
      navigation: LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final columns = constraints.maxWidth >= 660 * scale
            ? 6
            : constraints.maxWidth >= 420 * scale
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < tabs.length; i++)
            Semantics(
                selected: tab == i,
                child: ClickButton(
                    text: tabs[i],
                    width: width,
                    height: 44,
                    fontSize: 8,
                    buttonColor: tab == i
                        ? const Color(0xffE1BA78)
                        : const Color(0xff746878),
                    onTap: () => setState(() => tab = i))),
        ]);
      }),
      body: MenuScrollBody(
          key: ValueKey(tab),
          child: LayoutBuilder(builder: (context, constraints) {
            const width = double.infinity;
            final cards = switch (tab) {
              0 => powerUps
                  .map((p) => _card(
                      p.title,
                      '${p.group.name.toUpperCase()} / ${p.maxRank} RANKS\n${p.description}',
                      width))
                  .toList(),
              1 => fusionRecipes
                  .map((r) => _card(
                      r.title,
                      '${r.first.title} 3 + ${r.second.title} 2\n${r.description}',
                      width,
                      badge: profile.fusions.contains(r.id)
                          ? 'DISCOVERED'
                          : 'BOSS CORE'))
                  .toList(),
              2 => [
                  ...EnemyKind.values.map((e) => _card(
                      e.title, e.description, width,
                      badge: profile.discoveredEnemies.contains(e.name)
                          ? 'ENCOUNTERED'
                          : 'FIELD GUIDE')),
                  ...BossKind.values.map((e) =>
                      _card(e.title, e.description, width, badge: 'BOSS')),
                ],
              3 => challenges
                  .map((c) => _card(
                      c.title, '${c.requirement}\nReward: ${c.reward}', width,
                      badge: profile.challenges.contains(c.id)
                          ? 'COMPLETE'
                          : _progress(c.id)))
                  .toList(),
              4 => [
                  for (final id in [...cosmeticIds, ...shopCosmetics.keys])
                    _cosmetic(id, width)
                ],
              _ => [
                  _card(
                      'REGUN',
                      'Created with Flutter and Flame.\nGameplay code, pixel UI, AI-assisted artwork and synthesized audio are part of this project.\nNo accounts, ads, or online services are required.\nVersion 1.0.0',
                      constraints.maxWidth)
                ],
            };
            return MenuCardGrid(maxColumns: tab == 5 ? 1 : 3, children: cards);
          })));
  String _progress(String id) => switch (id) {
        'scrapper' => '${profile.totalKills} / 500 KILLS',
        'scorpionCharm' => '${profile.scorpionKills} / 1000',
        'eliteHunter' => '${profile.eliteKills} / 100 ELITES',
        'engineer' => '${profile.fusions.length} / 6 FUSIONS',
        'survivor' => '${profile.cycleCharacters.length} / 3 SURVIVORS',
        _ => 'IN PROGRESS',
      };
  Widget _card(String title, String body, double width,
          {String? badge, Widget? action}) =>
      Container(
          key: ValueKey('collection-card-$title'),
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xff211B26),
              border: Border.all(color: const Color(0xff51424F))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (badge != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(badge,
                      style: const TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontSize: 9,
                          color: Color(0xffDEB97B)))),
            Text(title,
                style: const TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 11,
                    height: 1.6,
                    color: Color(0xffE5DDD1))),
            const SizedBox(height: 12),
            Text(body,
                style: const TextStyle(
                    fontFamily: FontFam.orbitron,
                    fontSize: 11,
                    height: 1.7,
                    color: Color(0xffB9ADB9))),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: action),
          ]));
  Widget _cosmetic(String id, double width) {
    final owned = profile.owned.contains(id), selected = profile.cosmetic == id;
    final price = shopCosmetics[id];
    return _card(
        _name(id),
        price == null
            ? 'Challenge reward'
            : '$price scrap / ${profile.scrap} available',
        width,
        badge: selected
            ? 'EQUIPPED'
            : owned
                ? 'OWNED'
                : 'LOCKED',
        action: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: double.infinity,
              height: 88,
              child: SurvivorPortrait(style: id)),
          const SizedBox(height: 12),
          ClickButton(
              text: selected
                  ? 'Equipped'
                  : owned
                      ? 'Equip'
                      : price != null
                          ? 'Buy'
                          : 'Locked',
              width: 120,
              height: 44,
              onTap: selected ||
                      (!owned && (price == null || profile.scrap < price))
                  ? null
                  : () async {
                      if (!owned && price != null) {
                        profile.scrap -= price;
                        profile.owned.add(id);
                      }
                      profile.cosmetic = id;
                      await LocalPreferences.shared.saveProfile();
                      if (mounted) setState(() {});
                    })
        ]));
  }

  String _name(String id) =>
      id.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}').toUpperCase();
}
