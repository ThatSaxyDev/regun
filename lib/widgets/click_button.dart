import 'package:regun/desktop/desktop_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/theme/palette.dart';
import 'package:regun/theme/menu_focus.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/utils/soloud_play.dart';

class ClickButton extends ConsumerStatefulWidget {
  const ClickButton({
    super.key,
    this.onTap,
    this.width,
    this.height,
    this.fontSize,
    this.buttonColor,
    this.buttonShadow,
    required this.text,
    this.isActive = true,
    this.glyph,
    this.iconOnly = false,
    this.autofocus = false,
    this.content,
  });

  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? buttonColor;
  final Color? buttonShadow;
  final String text;
  final bool? isActive;
  final PixelGlyph? glyph;
  final bool iconOnly;
  final bool autofocus;
  final Widget? content;

  @override
  ConsumerState<ClickButton> createState() => _ClickButtonState();
}

class _ClickButtonState extends ConsumerState<ClickButton> {
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isActive == true && widget.onTap != null;
    final accent = enabled
        ? widget.buttonColor ?? Palette.buttonBlue
        : Palette.textHintGrey;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.text,
      child: SizedBox(
        width: widget.width,
        height: widget.height ?? (widget.content == null ? 52 : null),
        child: InkWell(
          canRequestFocus: enabled,
          autofocus: widget.autofocus,
          onHover: desktopInputAvailable
              ? (value) => setState(() => _hovered = value)
              : null,
          onFocusChange: desktopInputAvailable
              ? (focused) => setState(() => _focused = focused)
              : null,
          onTap: enabled
              ? () {
                  ref.read(soloudPlayProvider).play('click.mp3');
                  widget.onTap?.call();
                }
              : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: CustomPaint(
            painter: _ButtonPlate(
              accent: accent,
              pressed: _pressed,
              enabled: enabled,
              focused: _focused,
              hovered: _hovered && enabled,
            ),
            child: widget.content != null
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Opacity(
                        opacity: enabled ? 1 : .55,
                        child: ExcludeSemantics(child: widget.content!),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      _pressed ? 5 : 2,
                      14,
                      _pressed ? 2 : 5,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.glyph != null) ...[
                            CustomPaint(
                              size: Size.square(widget.iconOnly ? 24 : 16),
                              painter: _GlyphPainter(widget.glyph!, accent),
                            ),
                            if (!widget.iconOnly) const SizedBox(width: 12),
                          ],
                          if (!widget.iconOnly)
                            Text(
                              widget.text.toUpperCase(),
                              style: TextStyle(
                                fontFamily: FontFam.pressStart,
                                fontSize: widget.fontSize ?? 10,
                                height: 1.4,
                                color: enabled
                                    ? Palette.textWhite
                                    : Palette.textHintGrey,
                                letterSpacing: 0.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class ClickButtonM extends StatelessWidget {
  const ClickButtonM({
    super.key,
    this.onTap,
    this.width,
    this.height,
    this.fontSize,
    this.buttonColor,
    this.buttonShadow,
    required this.text,
    this.isActive = true,
  });
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? buttonColor;
  final Color? buttonShadow;
  final String text;
  final bool? isActive;

  @override
  Widget build(BuildContext context) => ClickButton(
    onTap: onTap,
    width: width,
    height: height,
    fontSize: fontSize,
    buttonColor: buttonColor,
    text: text,
    isActive: isActive,
    glyph: PixelGlyph.menu,
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);
  final PixelGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      paintPixelGlyph(canvas, Offset.zero & size, glyph, color);
  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glyph != glyph;
}

class _ButtonPlate extends CustomPainter {
  const _ButtonPlate({
    required this.accent,
    required this.pressed,
    required this.enabled,
    required this.focused,
    required this.hovered,
  });
  final Color accent;
  final bool pressed;
  final bool enabled;
  final bool focused, hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      1,
      pressed ? 3 : 0,
      size.width - 2,
      size.height - 4,
    );
    canvas.drawPath(
      controlPlate(rect.shift(const Offset(0, 3))),
      Paint()..color = const Color(0xff100e14),
    );
    canvas.drawPath(
      controlPlate(rect),
      Paint()
        ..color = pressed
            ? const Color(0xff3a3031)
            : hovered
            ? const Color(0xff514034)
            : const Color(0xff252129),
    );
    canvas.drawPath(
      controlPlate(rect.deflate(0.75)),
      Paint()
        ..color = (hovered ? const Color(0xffe1ba78) : accent).withValues(
          alpha: pressed || hovered
              ? 0.9
              : enabled
              ? 0.5
              : 0.22,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(rect.left + 9, rect.top + 4),
      Offset(rect.right - 9, rect.top + 4),
      Paint()
        ..color = const Color(0xff51454c)
        ..strokeWidth = 1,
    );
    if (focused && enabled) {
      paintMenuFocus(canvas, rect);
    }
    final rivet = Paint()
      ..color = accent.withValues(alpha: enabled ? 0.8 : 0.2)
      ..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 5, rect.center.dy - 1.5, 3, 3),
      rivet,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - 8, rect.center.dy - 1.5, 3, 3),
      rivet,
    );
  }

  @override
  bool shouldRepaint(_ButtonPlate oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.pressed != pressed ||
      oldDelegate.enabled != enabled ||
      oldDelegate.focused != focused ||
      oldDelegate.hovered != hovered;
}
