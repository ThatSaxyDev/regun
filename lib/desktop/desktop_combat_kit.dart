import 'package:flutter/material.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_combat_input.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/pixel_icon.dart';

const _brass = Color(0xffE1BA78);
const _paper = Color(0xffF1E6D5);
const _shadow = [Shadow(color: Colors.black, blurRadius: 5)];

class DesktopCombatKit extends StatelessWidget {
  const DesktopCombatKit({
    super.key,
    required this.weapon,
    required this.ammo,
    required this.capacity,
    required this.dash,
    required this.grenade,
    required this.dashRecharge,
    required this.grenadeRecharge,
    required this.controller,
    required this.reducedMotion,
    this.reload = -1,
    this.refill = -1,
    this.tactical = false,
    this.breachEngine = false,
  });

  final WeaponType weapon;
  final int ammo, capacity, dash;
  final int? grenade;
  final bool controller, reducedMotion, tactical, breachEngine;
  final double reload, refill, dashRecharge, grenadeRecharge;

  @override
  Widget build(BuildContext context) {
    final bindings = DesktopBindings.shared;
    final scale = (MediaQuery.sizeOf(context).height / 880).clamp(.85, 1.28);
    final heat = weapon == WeaponType.prismCutter;
    final amount = heat ? capacity - ammo : ammo;
    final pipCount = capacity.clamp(0, 15);
    final progress = refill >= 0 ? (reducedMotion ? 1.0 : refill) : reload;
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: bindings.revision,
        builder: (context, _) {
          String hint(DesktopAction action, ControllerAction button) {
            if (controller) {
              return desktopControllerButtons[bindings.button(button)];
            }
            return bindings.label(bindings.key(action));
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _ActionReadout(
                  name: 'Dash',
                  count: dash,
                  recharge: dashRecharge,
                  binding: hint(DesktopAction.dash, ControllerAction.dash),
                  icon: PixelIcon(PixelGlyph.dash, size: 30 * scale),
                ),
              ),
              Flexible(
                flex: 2,
                child: SizedBox(
                  width: 296 * scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        refill >= 0
                            ? 'MAG READY'
                            : reload >= 0
                            ? (heat ? 'VENTING' : 'RELOADING')
                            : breachEngine
                            ? 'BREACH ENGINE'
                            : weapon.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: FontFam.pressStart,
                          fontSize: 11 * scale,
                          color: _paper,
                          shadows: _shadow,
                        ),
                      ),
                      SizedBox(
                        height: 74 * scale,
                        child: FittedBox(
                          child: WeaponReloadDisplay(
                            weapon: weapon,
                            progress: progress,
                            shells: refill >= 0 ? 1 : capacity - ammo,
                            tactical: tactical,
                            reducedMotion: reducedMotion,
                            showChrome: false,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                          width: 144 * scale,
                          child: progress < 0
                              ? const SizedBox(height: 3)
                              : LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  color: _brass,
                                  backgroundColor: const Color(0xff4F404D),
                                ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4 * scale,
                        runSpacing: 4,
                        children: List.generate(pipCount, (index) {
                          final loaded = index * capacity < amount * pipCount;
                          return Container(
                            width: 8 * scale,
                            height: 19 * scale,
                            decoration: BoxDecoration(
                              color: loaded ? _brass : const Color(0xd9393036),
                              border: Border.all(
                                color: const Color(0xb31c1816),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${heat ? 'HEAT  ' : ''}$amount / $capacity',
                        style: TextStyle(
                          fontFamily: FontFam.orbitron,
                          fontWeight: FontWeight.w800,
                          fontSize: 20 * scale,
                          color: _paper,
                          shadows: _shadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (grenade case final count?)
                Flexible(
                  child: _ActionReadout(
                    name: 'Grenade',
                    count: count,
                    recharge: grenadeRecharge,
                    binding: hint(
                      DesktopAction.grenade,
                      ControllerAction.grenade,
                    ),
                    icon: CustomPaint(
                      size: Size.square(34 * scale),
                      painter: const _GrenadeIcon(),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          );
        },
      ),
    );
  }
}

class _ActionReadout extends StatelessWidget {
  const _ActionReadout({
    required this.name,
    required this.count,
    required this.recharge,
    required this.binding,
    required this.icon,
  });

  final String name, binding;
  final int count;
  final double recharge;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: count > 0 ? 1 : .45, child: icon),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: _paper,
                shadows: _shadow,
              ),
            ),
          ],
        ),
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: _paper,
            shadows: _shadow,
          ),
        ),
        Text(
          binding,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: _brass,
            shadows: _shadow,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          child: LinearProgressIndicator(
            semanticsLabel: '$name recharge',
            value: recharge.clamp(0.0, 1.0),
            minHeight: 4,
            color: recharge >= 1 ? const Color(0xff877450) : _brass,
            backgroundColor: const Color(0xff4F404D),
          ),
        ),
      ],
    ),
  );
}

class _GrenadeIcon extends CustomPainter {
  const _GrenadeIcon();

  @override
  void paint(Canvas canvas, Size size) =>
      paintGrenade(canvas, size.center(Offset.zero), size.height);

  @override
  bool shouldRepaint(_GrenadeIcon oldDelegate) => false;
}
