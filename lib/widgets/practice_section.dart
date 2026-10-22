import 'package:flutter/material.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';

/// Closed sections own no practice art. Outgoing content releases after collapse.
class PracticeSection extends StatefulWidget {
  const PracticeSection({
    super.key,
    required this.title,
    required this.summary,
    required this.builder,
  });
  final String title, summary;
  final WidgetBuilder builder;
  @override
  State<PracticeSection> createState() => _PracticeSectionState();
}

class _PracticeSectionState extends State<PracticeSection>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && mounted) setState(() {});
      });
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _open = false;
  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final reduced =
        LocalPreferences.shared.reducedMotion ||
        MediaQuery.disableAnimationsOf(context);
    setState(() => _open = !_open);
    if (reduced) {
      _controller.value = _open ? 1 : 0;
    } else if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xf51D1821),
      border: Border(
        top: BorderSide(color: Color(0xff665A68)),
        bottom: BorderSide(color: Color(0xff352D39)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: '${widget.title}. ${widget.summary}',
          excludeSemantics: true,
          onTap: _toggle,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: FontFam.pressStart,
                            fontSize: 10,
                            height: 1.6,
                            color: Color(0xffE1BA78),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.summary,
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xffB2A8B4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _open ? '-' : '+',
                    style: const TextStyle(
                      fontFamily: FontFam.pressStart,
                      fontSize: 18,
                      color: Color(0xffE1BA78),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open || !_controller.isDismissed)
          ClipRect(
            child: SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _curve,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: ExcludeSemantics(
                    excluding: !_open,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: widget.builder(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
