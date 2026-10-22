import 'package:flutter/material.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// Shared safe edges and pinned navigation for the game's menu pages.
class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.title,
    required this.body,
    this.navigation,
    this.footer,
    this.maxWidth = 1100,
    this.hideHeader = false,
  });
  final String title;
  final Widget body;
  final Widget? navigation, footer;
  final double maxWidth;
  final bool hideHeader;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff141117),
    body: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hideHeader)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                title,
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
                  ),
                if (navigation != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 12),
                    child: navigation!,
                  ),
                Expanded(child: body),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8),
                    child: footer!,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Inset scroll viewport: the scrollbar and soft edges explain continuation.
class MenuScrollBody extends StatefulWidget {
  const MenuScrollBody({
    super.key,
    required this.child,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });
  final Widget child;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  @override
  State<MenuScrollBody> createState() => _MenuScrollBodyState();
}

class _MenuScrollBodyState extends State<MenuScrollBody> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawScrollbar(
    controller: _controller,
    thumbVisibility: true,
    thumbColor: const Color(0xffAD9162),
    thickness: 3,
    minThumbLength: 28,
    mainAxisMargin: 8,
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .025, .93, 1],
        ).createShader(rect),
        child: SingleChildScrollView(
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          controller: _controller,
          primary: false,
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          child: widget.child,
        ),
      ),
    ),
  );
}

/// Content-driven row heights; cards in each row share both top and bottom edges.
class MenuCardGrid extends StatelessWidget {
  const MenuCardGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 240,
    this.maxColumns = 3,
  });
  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final columns = ((box.maxWidth + 12) / (minColumnWidth * scale + 12))
          .floor()
          .clamp(1, maxColumns);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    Expanded(
                      child: start + col < children.length
                          ? children[start + col]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
