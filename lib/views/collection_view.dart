import 'package:regun/utils/format_number.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/services/economy/armory_repository.dart';
import 'package:regun/widgets/confirm_run_action.dart';

import 'dart:async';

import 'package:regun/models/economy/career_progress.dart';
import 'package:regun/models/economy/shop_catalog.dart';
import 'package:regun/services/economy/shop_repository.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/widgets/account_flow.dart';
import 'package:regun/systems/upgrade_details.dart';
import 'package:regun/data/loadout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show PlatformException;
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
  final _rankPaths = <PowerUp>{};
  String _rankPath(PowerUp p) {
    final weapon = p == PowerUp.exposedSeam
        ? WeaponType.frostShotgun
        : p == PowerUp.sureFoot
        ? WeaponType.beltRepeater
        : WeaponType.values.firstWhere((w) => weaponSupportsPowerUp(w, p));
    final power = WeaponPowerBalance.live(BalanceRepository.shared.current);
    final state = GameState(
      rankCurves: power.rankCurves,
      upgradeStrengths: power.upgradeStrengths,
    );
    return 'Example / ${weapon.title} / Rook\n${List.generate(state.rankLimit(p), (i) => '${i + 1} / ${state.rankValues(p, i + 1, weapon, CharacterType.rook, power).entries.map((e) => '${e.key} ${groupNumberText(e.value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), ''))}').join(' / ')}').join('\n')}';
  }

  int tab = 0;
  bool _savingStyle = false;
  String? _purchaseIssue;
  final tabs = [
    'Upgrades',
    'Fusions',
    'Enemies',
    'Challenges',
    'Style',
    'About',
  ];
  final shop = ShopRepository.shared;
  @override
  void initState() {
    super.initState();
    shop.addListener(_changed);
    LocalPreferences.shared.addListener(_changed);
    unawaited(shop.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    shop.removeListener(_changed);
    LocalPreferences.shared.removeListener(_changed);
    super.dispose();
  }

  PlayerProfile get profile => LocalPreferences.shared.profile;
  @override
  Widget build(BuildContext context) => MenuPage(
    title: 'COLLECTION',
    showWallet: true,
    navigation: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final columns = constraints.maxWidth >= 660 * scale
            ? 6
            : constraints.maxWidth >= 420 * scale
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
                  onTap: () {
                    setState(() => tab = i);
                    if (i == 4) {
                      unawaited(shop.refresh());
                      final account = AccountController.shared;
                      if (account.verified && account.attached) {
                        unawaited(
                          account
                              .accessToken()
                              .then(
                                (token) => account.api.request(
                                  '/shop-visit',
                                  token: token,
                                  body: {},
                                ),
                              )
                              .catchError((Object _) => <String, dynamic>{}),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
    body: MenuScrollBody(
      key: ValueKey(tab),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const width = double.infinity;
          final cards = switch (tab) {
            0 =>
              powerUps
                  .map(
                    (p) => _card(
                      p.title,
                      '${p.group.name.toUpperCase()} / UP TO ${p.maxRank} RANKS\n${upgradeDescription(p)}${_rankPaths.contains(p) ? '\n${_rankPath(p)}' : ''}',
                      width,
                      action: ClickButton(
                        text: _rankPaths.contains(p)
                            ? 'Hide ranks'
                            : 'Rank path',
                        height: 44,
                        width: 160,
                        fontSize: 8,
                        onTap: () => setState(() {
                          if (!_rankPaths.remove(p)) _rankPaths.add(p);
                        }),
                      ),
                    ),
                  )
                  .toList(),
            1 =>
              fusionRecipes
                  .map(
                    (r) => _card(
                      r.title,
                      '${r.first.title} 3 + ${r.second.title} 2\n${r.description}',
                      width,
                      badge: profile.fusions.contains(r.id)
                          ? 'DISCOVERED'
                          : 'BOSS CORE',
                    ),
                  )
                  .toList(),
            2 => [
              ...EnemyKind.values.map(
                (e) => _card(
                  e.title,
                  e.description,
                  width,
                  badge: profile.discoveredEnemies.contains(e.name)
                      ? 'ENCOUNTERED'
                      : 'FIELD GUIDE',
                ),
              ),
              ...BossKind.active.map(
                (e) => _card(e.title, e.description, width, badge: 'BOSS'),
              ),
            ],
            3 => [
              _card(
                'FIELD RECORD',
                '${formatNumber(profile.settledRuns.length)} runs / ${formatNumber(profile.totalBossVictories)} boss victories / ${formatNumber(profile.totalKills)} kills\nCombat upgrades are earned during each run. Scrap buys appearances.',
                width,
              ),
              _card(
                'SCRAP',
                '10 kills = 1 Scrap / Boss = 15 Scrap / Minute survived = 1 Scrap\nSalvage adds to your run total. Training grants no rewards.',
                width,
              ),
              for (final goal in CareerProgress(
                profile,
                armory: ArmoryRepository.shared.catalog,
              ).goals)
                _card(
                  goal.title,
                  goal.detail,
                  width,
                  badge:
                      CareerProgress(
                            profile,
                            armory: ArmoryRepository.shared.catalog,
                          ).next?.id ==
                          goal.id
                      ? 'NEXT GOAL'
                      : 'EARNED UNLOCK',
                  action: ClickButton(
                    text: profile.pinnedGoal == goal.id ? 'Pinned' : 'Pin goal',
                    width: 150,
                    height: 44,
                    onTap: profile.pinnedGoal == goal.id
                        ? null
                        : () async {
                            final next = PlayerProfile.fromJson(
                              profile.toJson(),
                            )..pinnedGoal = goal.id;
                            final saved = await LocalPreferences.shared
                                .saveProfile(next: next);
                            if (mounted) {
                              setState(
                                () => _purchaseIssue = saved
                                    ? 'Goal pinned.'
                                    : 'Could not save your goal. Try again.',
                              );
                            }
                          },
                  ),
                ),
              ...challenges.map(
                (c) => _card(
                  c.title,
                  '${c.requirement}\nReward: ${c.reward}',
                  width,
                  badge: profile.challenges.contains(c.id)
                      ? 'COMPLETE'
                      : _progress(c.id),
                ),
              ),
            ],
            4 => [
              for (final id in {
                profile.cosmetic,
                ...shopCosmetics.keys,
                ...cosmeticIds,
              })
                _cosmetic(id, width),
            ],
            _ => [
              _card(
                'REGUN',
                'Gameplay code, pixel UI, AI-assisted artwork and synthesized audio are part of this project.\nOffline play needs no account. Purchases require email sign-in.\nVersion 1.0.0',
                constraints.maxWidth,
                attribution: Semantics(
                  link: true,
                  child: InkWell(
                    onTap: _openCreatorSite,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Created with Flutter and Flame by Dedeke David',
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 11,
                            height: 1.7,
                            color: Color(0xffDEB97B),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xffDEB97B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tab == 4) ...[
                if (AccountController.shared.pendingPurchaseItem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClickButton(
                      text: 'Cancel pending',
                      width: 200,
                      height: 44,
                      onTap: _savingStyle
                          ? null
                          : () async {
                              setState(() => _savingStyle = true);
                              try {
                                await AccountController.shared
                                    .cancelPendingPurchase();
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _savingStyle = false;
                                    _purchaseIssue =
                                        AccountController.shared.issue;
                                  });
                                }
                              }
                            },
                    ),
                  ),

                _card(
                  'FIELD FINISHES',
                  'Appearance only. Preview, buy with Scrap, then equip. Earned challenge styles stay earned.',
                  double.infinity,
                ),
                if (shop.issue != null)
                  Text(
                    shop.issue!,
                    style: const TextStyle(color: Color(0xffE1BA78)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClickButton(
                    text: shop.loading ? 'Checking' : 'Refresh shop',
                    width: 180,
                    height: 44,
                    onTap: shop.loading
                        ? null
                        : () => unawaited(shop.refresh()),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_purchaseIssue != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _purchaseIssue!,
                    style: const TextStyle(color: Color(0xffE1BA78)),
                  ),
                ),
              MenuCardGrid(maxColumns: tab == 5 ? 1 : 3, children: cards),
            ],
          );
        },
      ),
    ),
  );
  Future<void> _openCreatorSite() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://kiishi.space'),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      // Keep About usable if the device cannot open a browser.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open kiishi.space.')),
      );
    }
  }

  String _progress(String id) {
    final survivor = CharacterType.values
        .where((c) => c.name == id)
        .firstOrNull;
    if (survivor != null) return profile.characterProgress(survivor);
    return switch (id) {
      'burstRifle' =>
        '${LocalPreferences.shared.profile.totalBossVictories} / 3 bosses',
      'scrapper' => '${formatNumber(profile.totalKills)} / 500 KILLS',
      'scorpionCharm' => '${formatNumber(profile.scorpionKills)} / 1,000',
      'eliteHunter' => '${formatNumber(profile.eliteKills)} / 100 ELITES',
      'engineer' =>
        '${profile.fusions.where((f) => !['kilnPact', 'groundWire'].contains(f)).length} / 6 FUSIONS',
      'eightFusions' => '${profile.fusions.length} / 8 FUSIONS',
      'tenSurvivors' => '${profile.cycleCharacters.length} / 10 SURVIVORS',
      'survivor' =>
        '${profile.cycleCharacters.where((c) => ['rook', 'scrapper', 'warden'].contains(c)).length} / 3 SURVIVORS',
      _
          when WeaponType.values.any(
            (w) => w.name == id && w.victoryRequirement > 0,
          ) =>
        '${formatNumber(profile.totalBossVictories)} / ${WeaponType.values.byName(id).victoryRequirement} BOSSES',
      _ => 'IN PROGRESS',
    };
  }

  Widget _card(
    String title,
    String body,
    double width, {
    String? badge,
    Widget? action,
    Widget? attribution,
  }) => Container(
    key: ValueKey('collection-card-$title'),
    width: width,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff211B26),
      border: Border.all(color: const Color(0xff51424F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              badge,
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 9,
                color: Color(0xffDEB97B),
              ),
            ),
          ),
        Text(
          title,
          style: const TextStyle(
            fontFamily: FontFam.pressStart,
            fontSize: 11,
            height: 1.6,
            color: Color(0xffE5DDD1),
          ),
        ),
        const SizedBox(height: 12),
        if (attribution != null) attribution,
        Text(
          body,
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 11,
            height: 1.7,
            color: Color(0xffB9ADB9),
          ),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: action),
      ],
    ),
  );
  Widget _cosmetic(String id, double width) {
    final owned = profile.owned.contains(id), selected = profile.cosmetic == id;
    final shopItem = shopCosmetics.containsKey(id);
    final price = shop.catalog.prices[id];
    final forSale = shop.catalog.available.contains(id);
    return _card(
      _name(id),
      !shopItem
          ? 'Challenge reward'
          : '${shopDescriptions[id]}\n${price == null ? 'Not available' : '${formatNumber(price)} Scrap / ${formatNumber(profile.scrap)} available'}',
      width,
      badge: selected
          ? 'EQUIPPED'
          : owned
          ? 'OWNED'
          : 'LOCKED',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 88,
            child: SurvivorPortrait(style: id),
          ),
          const SizedBox(height: 12),
          ClickButton(
            text: selected
                ? 'Equipped'
                : owned
                ? 'Equip'
                : !forSale && shopItem
                ? 'Unavailable'
                : price != null
                ? LocalPreferences.shared.canSpend
                      ? 'Buy'
                      : 'Sign in'
                : 'Locked',
            width: 120,
            height: 44,
            onTap:
                _savingStyle ||
                    selected ||
                    (!owned &&
                        (price == null ||
                            !forSale ||
                            (LocalPreferences.shared.canSpend &&
                                profile.scrap < price)))
                ? null
                : () => _chooseStyle(id, owned, price),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseStyle(String id, bool owned, int? price) async {
    if (_savingStyle) return;
    setState(() {
      _savingStyle = true;
      _purchaseIssue = null;
    });
    try {
      if (!owned && price != null && !LocalPreferences.shared.canSpend) {
        final account = AccountController.shared;
        await account.initialize();
        if (!mounted) return;
        await showAccountFlow(context, account);
        if (account.verified && account.attached) {
          _purchaseIssue = 'Signed in. Choose Buy to confirm.';
        }
        return;
      }
      if (!owned && price != null) {
        final retry = AccountController.shared.pendingPurchaseItem == id;
        if (!retry) {
          final approved = await confirmRunAction(
            context,
            eyebrow: 'RE-GUN / FIELD FINISH',
            title: _name(id),
            message:
                '${formatNumber(price)} Scrap / Appearance only. Owned finishes remain available offline.',
            action: 'Buy',
            cancel: 'Keep browsing',
          );
          if (!approved || !mounted) return;
        }
        final result = await LocalPreferences.shared.buyCosmetic(
          id,
          price: price,
          catalog: shop.catalog.version,
        );
        if (result != CosmeticPurchase.saved) {
          unawaited(shop.refresh());
          _purchaseIssue = AccountController.shared.issue.isNotEmpty
              ? AccountController.shared.issue
              : result == CosmeticPurchase.saveFailed
              ? 'Could not save. Retry to check your purchase.'
              : result == CosmeticPurchase.pendingConfirmation
              ? 'Retry your earlier purchase to confirm its status.'
              : result == CosmeticPurchase.onlineRequired
              ? 'Connect to purchase. Retry to check its status.'
              : 'Purchase unavailable. Check your wallet.';
        }
      } else {
        profile.cosmetic = id;
        if (!await LocalPreferences.shared.saveProfile()) {
          _purchaseIssue = 'Style not saved. Retry in your wallet.';
        }
      }
    } catch (_) {
      _purchaseIssue = 'Could not complete this action. Try again.';
    } finally {
      if (mounted) setState(() => _savingStyle = false);
    }
  }

  String _name(String id) =>
      id.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}').toUpperCase();
}
