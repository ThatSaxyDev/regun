import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/survivor_portrait.dart';
import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

class LoadoutView extends StatefulWidget {
  const LoadoutView({super.key, this.training = false});
  final bool training;
  @override
  State<LoadoutView> createState() => _LoadoutViewState();
}

class _LoadoutViewState extends State<LoadoutView> {
  WeaponType weapon = WeaponType.shotgun;
  CharacterType character = CharacterType.rook;
  ArenaType arena = ArenaType.breach;
  bool _starting = false;
  PlayerProfile get profile => LocalPreferences.shared.profile;
  @override
  Widget build(BuildContext context) => MenuPage(
        title: widget.training ? 'TRAINING' : 'LOADOUT',
        body: MenuScrollBody(
            child: LayoutBuilder(builder: (context, constraints) {
          final columns = [
            _section(
                'SURVIVOR',
                CharacterType.values
                    .map((c) => _option(c.title, c.description,
                        selected: character == c,
                        unlocked:
                            widget.training || profile.characterUnlocked(c),
                        lock: c == CharacterType.scrapper
                            ? '500 kills'
                            : 'Survive 8 minutes',
                        survivor: c,
                        onTap: () => setState(() => character = c)))
                    .toList()),
            _section(
                'WEAPON',
                WeaponType.values
                    .map((w) => _option(w.title, w.description,
                        selected: weapon == w,
                        unlocked: widget.training || profile.weaponUnlocked(w),
                        lock: switch (w) {
                          WeaponType.carbine => 'Complete training',
                          WeaponType.revolver => 'Defeat Shadow',
                          _ => 'Defeat Demon'
                        },
                        onTap: () => setState(() => weapon = w)))
                    .toList()),
            _section(
                'ARENA',
                ArenaType.values
                    .map((a) => _option(a.title, a.description,
                        selected: arena == a,
                        unlocked: widget.training || profile.arenaUnlocked(a),
                        lock: 'Complete a cycle',
                        onTap: () => setState(() => arena = a)))
                    .toList()),
          ];
          return MenuCardGrid(children: columns);
        })),
        footer: _footer(),
      );

  Widget _footer() => Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xff211B25),
      child: LayoutBuilder(builder: (context, box) {
        final summary = Row(children: [
          CustomPaint(
              size: const Size(72, 40), painter: _WeaponPreview(weapon)),
          const SizedBox(width: 12),
          Expanded(
              child: Text('${character.title} / ${weapon.title}',
                  style: const TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 13,
                      color: Color(0xffD7CABC)))),
        ]);
        final start = ClickButton(
            text: _starting ? 'Loading' : 'Start',
            width: 140,
            height: 48,
            onTap: _starting
                ? null
                : () async {
                    setState(() => _starting = true);
                    if (!widget.training) await RunStore.shared.clear();
                    if (!context.mounted) return;
                    await Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => BaseView(
                                loadout: Loadout(
                                    weapon: weapon,
                                    character: character,
                                    arena: arena,
                                    training: widget.training))));
                  });
        if (box.maxWidth < 480) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [summary, const SizedBox(height: 8), start]);
        }
        return Row(children: [
          Expanded(child: summary),
          const SizedBox(width: 16),
          start
        ]);
      }));

  Widget _section(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title,
                style: const TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 10,
                    color: Color(0xffDDB77A)))),
        ...children,
        const SizedBox(height: 16),
      ]);
  Widget _option(String title, String description,
          {CharacterType? survivor,
          required bool selected,
          required bool unlocked,
          required String lock,
          required VoidCallback onTap}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
              selected: selected,
              child: InkWell(
                  onTap: unlocked ? onTap : null,
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(minHeight: 72),
                      decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xff3A2E28)
                              : const Color(0xff211C26),
                          border: Border.all(
                              color: selected
                                  ? const Color(0xffE1BA78)
                                  : const Color(0xff4D414F))),
                      child: Row(children: [
                        if (survivor != null) ...[
                          SizedBox(
                              width: 48,
                              height: 66,
                              child: SurvivorPortrait(character: survivor)),
                          const SizedBox(width: 12)
                        ],
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${selected ? '▸ ' : ''}$title',
                                  style: TextStyle(
                                      fontFamily: FontFam.orbitron,
                                      fontSize: 14,
                                      color: unlocked
                                          ? const Color(0xffE5DDD1)
                                          : const Color(0xff897F8C))),
                              const SizedBox(height: 5),
                              Text(unlocked ? description : lock,
                                  style: const TextStyle(
                                      fontFamily: FontFam.orbitron,
                                      fontSize: 10,
                                      height: 1.5,
                                      color: Color(0xffB2A8B4))),
                            ]))
                      ])))));
}

class _WeaponPreview extends CustomPainter {
  const _WeaponPreview(this.weapon);
  final WeaponType weapon;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(36, 22);
    canvas.scale(1.5);
    paintWeapon(canvas, weapon);
  }

  @override
  bool shouldRepaint(_WeaponPreview oldDelegate) =>
      oldDelegate.weapon != weapon;
}
