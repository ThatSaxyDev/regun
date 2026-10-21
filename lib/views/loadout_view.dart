import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/widgets/survivor_portrait.dart';

enum _Catalog { survivor, weapon, arena }

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
  _Catalog _catalog = _Catalog.survivor;
  final _selectedOption = GlobalKey();
  bool _starting = false;
  PlayerProfile get profile => LocalPreferences.shared.profile;

  void _browse(_Catalog catalog) {
    if (_catalog == catalog) return;
    setState(() => _catalog = catalog);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = _selectedOption.currentContext;
      if (mounted && selected != null) {
        Scrollable.ensureVisible(selected, alignment: .15);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff141117),
    body: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.training ? 'TRAINING' : 'LOADOUT',
                            style: const TextStyle(
                              fontFamily: FontFam.pressStart,
                              fontSize: 18,
                              color: Color(0xffE5DDD1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ClickButtonM(
                      text: 'Back',
                      width: 100,
                      height: 44,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final catalog in _Catalog.values) ...[
                        if (catalog.index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _CatalogTab(
                            label: catalog.name.toUpperCase(),
                            selection: switch (catalog) {
                              _Catalog.survivor => character.title,
                              _Catalog.weapon => weapon.title,
                              _Catalog.arena => arena.title,
                            },
                            active: _catalog == catalog,
                            onTap: () => _browse(catalog),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final preview = _KitPreview(
                        key: const Key('loadout-kit-preview'),
                        character: character,
                        weapon: weapon,
                        arena: arena,
                        style: profile.cosmetic,
                      );
                      final catalog = MenuScrollBody(
                        key: ValueKey(_catalog),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _options(),
                        ),
                      );
                      if (box.maxWidth < 480 && box.maxHeight > 300) {
                        return Column(
                          children: [
                            SizedBox(
                              height: math.min(200, box.maxHeight * .38),
                              width: double.infinity,
                              child: preview,
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: catalog),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: preview),
                          const SizedBox(width: 18),
                          Expanded(flex: 6, child: catalog),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _options() => switch (_catalog) {
    _Catalog.survivor =>
      CharacterType.values
          .map(
            (c) => _option(
              id: 'survivor-${c.name}',
              title: c.title,
              description: c.description,
              selected: character == c,
              unlocked: widget.training || profile.characterUnlocked(c),
              lock: c == CharacterType.scrapper
                  ? '500 kills'
                  : 'Survive 8 minutes',
              art: SurvivorPortrait(character: c),
              onTap: () => setState(() => character = c),
            ),
          )
          .toList(),
    _Catalog.weapon =>
      WeaponType.values
          .map(
            (w) => _option(
              id: 'weapon-${w.name}',
              title: w.title,
              description: w.description,
              selected: weapon == w,
              unlocked: widget.training || profile.weaponUnlocked(w),
              lock: switch (w) {
                WeaponType.carbine => 'Complete training',
                WeaponType.revolver => 'Defeat Shadow',
                _ => 'Defeat Demon',
              },
              art: _WeaponArt(w, key: ValueKey('loadout-art-${w.name}')),
              onTap: () => setState(() => weapon = w),
            ),
          )
          .toList(),
    _Catalog.arena =>
      ArenaType.values
          .map(
            (a) => _option(
              id: 'arena-${a.name}',
              title: a.title,
              description: a.description,
              selected: arena == a,
              unlocked: widget.training || profile.arenaUnlocked(a),
              lock: 'Complete a cycle',
              art: ClipRect(
                child: Image.asset(
                  _floor(a),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
              onTap: () => setState(() => arena = a),
            ),
          )
          .toList(),
  };

  Widget _option({
    required String id,
    required String title,
    required String description,
    required bool selected,
    required bool unlocked,
    required String lock,
    required Widget art,
    required VoidCallback onTap,
  }) {
    final option = Padding(
      key: ValueKey('loadout-$id'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        child: _SoundTap(
          onTap: unlocked ? onTap : null,
          child: CustomPaint(
            painter: _SlotPlate(selected: selected),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    height: 48,
                    child: Opacity(opacity: unlocked ? 1 : .4, child: art),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: unlocked
                                ? const Color(0xffe5ddd1)
                                : const Color(0xffa99c9d),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unlocked ? description : 'Locked · $lock',
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 10,
                            height: 1.5,
                            color: Color(0xffb9aaab),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CustomPaint(painter: _EquippedMark()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return selected
        ? KeyedSubtree(key: _selectedOption, child: option)
        : option;
  }

  Widget _footer() => Container(
    padding: const EdgeInsets.only(top: 8),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xff51424f))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${character.title} / ${weapon.title} / ${arena.title}',
            key: const Key('loadout-summary'),
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              height: 1.5,
              color: Color(0xffc7b9a6),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ClickButton(
          text: _starting ? 'Loading' : 'Start',
          width: 120,
          height: 48,
          onTap: _starting
              ? null
              : () async {
                  setState(() => _starting = true);
                  if (!widget.training) await RunStore.shared.clear();
                  if (!mounted) return;
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BaseView(
                        loadout: Loadout(
                          weapon: weapon,
                          character: character,
                          arena: arena,
                          training: widget.training,
                        ),
                      ),
                    ),
                  );
                },
        ),
      ],
    ),
  );
}

String _floor(ArenaType arena) => 'assets/art/arenas/${arena.name}_floor.png';

class _KitPreview extends StatelessWidget {
  const _KitPreview({
    super.key,
    required this.character,
    required this.weapon,
    required this.arena,
    required this.style,
  });
  final CharacterType character;
  final WeaponType weapon;
  final ArenaType arena;
  final String style;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _floor(arena),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          color: const Color(0xff777078),
          colorBlendMode: BlendMode.modulate,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xb3141117), Color(0x10141117), Color(0xc0141117)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: SurvivorPortrait(
            character: character,
            style: style,
            maxArtSize: 270,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 30,
          child: SizedBox(width: 76, height: 36, child: _WeaponArt(weapon)),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: Text(
            arena.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 10,
              letterSpacing: .8,
              color: Color(0xffd7c4a3),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({
    required this.label,
    required this.selection,
    required this.active,
    required this.onTap,
  });
  final String label, selection;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: _SoundTap(
      onTap: onTap,
      child: CustomPaint(
        painter: _SlotPlate(selected: active),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: active
                      ? const Color(0xffdfb574)
                      : const Color(0xffa5959c),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                selection,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xffe5ddd1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SoundTap extends ConsumerWidget {
  const _SoundTap({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: onTap == null
        ? null
        : () {
            ref.read(soloudPlayProvider).play('click.mp3');
            onTap!();
          },
    highlightColor: const Color(0x246f5341),
    splashColor: Colors.transparent,
    child: child,
  );
}

class _SlotPlate extends CustomPainter {
  const _SlotPlate({required this.selected});
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      controlPlate(rect, cut: 4),
      Paint()
        ..color = selected ? const Color(0xff3a2e28) : const Color(0xff211b26),
    );
    canvas.drawPath(
      controlPlate(rect.deflate(.75), cut: 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = selected ? const Color(0xffbf995f) : const Color(0xff51424f),
    );
  }

  @override
  bool shouldRepaint(_SlotPlate oldDelegate) =>
      oldDelegate.selected != selected;
}

class _EquippedMark extends CustomPainter {
  const _EquippedMark();
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xffddb77a)
      ..isAntiAlias = false;
    for (final offset in const [
      Offset(0, 5),
      Offset(3, 8),
      Offset(6, 5),
      Offset(9, 2),
    ]) {
      canvas.drawRect(offset & const Size(3, 3), ink);
    }
  }

  @override
  bool shouldRepaint(_EquippedMark oldDelegate) => false;
}

class _WeaponArt extends StatelessWidget {
  const _WeaponArt(this.weapon, {super.key});
  final WeaponType weapon;
  @override
  Widget build(BuildContext context) {
    if (RegunArt.shared.contains('weapons/arsenal')) {
      return CustomPaint(painter: _WeaponPreview(weapon));
    }
    return FutureBuilder<void>(
      future: RegunArt.shared.load(),
      builder: (context, state) => state.connectionState == ConnectionState.done
          ? CustomPaint(painter: _WeaponPreview(weapon))
          : const SizedBox.expand(),
    );
  }
}

class _WeaponPreview extends CustomPainter {
  const _WeaponPreview(this.weapon);
  final WeaponType weapon;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final feel = WeaponFeel.of(weapon);
    final height = weapon == WeaponType.shotgun ? 22.0 : 26.0;
    final scale = math.min(
      (size.width - 4) / feel.width,
      (size.height - 4) / height,
    );
    canvas.translate(
      size.width / 2 + scale * feel.width * (feel.grip - .5),
      size.height / 2 + scale * height * .05,
    );
    canvas.scale(scale);
    paintWeapon(canvas, weapon);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeaponPreview oldDelegate) =>
      oldDelegate.weapon != weapon;
}
