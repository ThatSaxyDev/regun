import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

const onlineInk = Color(0xffE5DDD1);
const onlineMuted = Color(0xffB8AFA6);
const onlineBrass = Color(0xffC6A66F);
const onlineGreen = Color(0xffA9C990);
const onlineError = Color(0xffED9E8C);

/// Keep one native editor: selection, paste, accessibility and IME composition
/// remain platform behavior even though the surrounding plate is authored.
class OnlineInput extends StatelessWidget {
  const OnlineInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.code = false,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final int maxLength;
  final bool code;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: focusNode,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnlineCaption(label),
        const SizedBox(height: 8),
        CustomPaint(
          painter: OnlinePlate(focused: focusNode.hasFocus),
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: maxLength,
              autocorrect: false,
              enableSuggestions: !code,
              keyboardType: code
                  ? TextInputType.visiblePassword
                  : TextInputType.name,
              textCapitalization: code
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              textInputAction: code
                  ? TextInputAction.join
                  : TextInputAction.done,
              inputFormatters: code ? [const RoomCodeFormatter()] : null,
              onTapOutside: (_) => focusNode.unfocus(),
              onSubmitted: onSubmitted ?? (_) => focusNode.unfocus(),
              cursorColor: onlineBrass,
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: code ? 19 : 16,
                letterSpacing: code ? 2 : .3,
                color: onlineInk,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xff80766F)),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Strip formatting separators, but leave invalid letters visible so the user
/// can correct them rather than silently changing the invitation code.
class RoomCodeFormatter extends TextInputFormatter {
  const RoomCodeFormatter();
  static String normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  static bool valid(String value) =>
      RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{10}$').hasMatch(value);
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = normalize(newValue.text);
    final offset = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final before = normalize(newValue.text.substring(0, offset));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: before.length.clamp(0, text.length),
      ),
    );
  }
}

class OnlineCaption extends StatelessWidget {
  const OnlineCaption(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontFamily: FontFam.pressStart,
      fontSize: 9,
      height: 1.6,
      color: onlineBrass,
    ),
  );
}

class OnlinePlate extends CustomPainter {
  const OnlinePlate({this.focused = false, this.filled = true});
  final bool focused, filled;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final path = controlPlate(rect);
    canvas.drawPath(
      path,
      Paint()
        ..color = filled ? const Color(0xff211D25) : const Color(0xff19161D),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = focused ? onlineBrass : const Color(0xff51454C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 2 : 1,
    );
    canvas.drawLine(
      Offset(12, size.height - 5),
      Offset(size.width - 12, size.height - 5),
      Paint()..color = const Color(0xff302A32),
    );
    for (final x in [7.0, size.width - 9]) {
      canvas.drawRect(
        Rect.fromLTWH(x, size.height / 2 - 1, 2, 2),
        Paint()..color = focused ? onlineBrass : const Color(0xff6F604B),
      );
    }
  }

  @override
  bool shouldRepaint(OnlinePlate oldDelegate) =>
      focused != oldDelegate.focused || filled != oldDelegate.filled;
}

/// Selected options carry both a physical marker and accessible selected state.
class OnlineOption extends StatelessWidget {
  const OnlineOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: CustomPaint(
        painter: OnlinePlate(focused: selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? onlineBrass : Colors.transparent,
                    border: Border.all(color: onlineBrass),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: FontFam.orbitron,
                    color: onTap == null ? onlineMuted : onlineInk,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
