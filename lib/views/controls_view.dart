import 'dart:async';

import 'package:flutter/material.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/widgets/control_arranger.dart';
import 'package:regun/widgets/controls_editor.dart';
import 'package:regun/widgets/menu_layout.dart';

/// Control setup needs no active run or gameplay resources.
class ControlsView extends StatefulWidget {
  const ControlsView({super.key, this.onChanged});
  final ValueChanged<ControlLayout>? onChanged;
  @override
  State<ControlsView> createState() => _ControlsViewState();
}

class _ControlsViewState extends State<ControlsView> {
  bool _arranging = false;
  ControlLayout get _layout => LocalPreferences.shared.controls;

  void _change(ControlLayout layout) {
    setState(() => unawaited(LocalPreferences.shared.saveControls(layout)));
    widget.onChanged?.call(layout);
  }

  @override
  Widget build(BuildContext context) {
    if (_arranging) {
      final safe = MediaQuery.paddingOf(context);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _arranging = false);
        },
        child: Scaffold(
          backgroundColor: const Color(0xff141117),
          body: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                ControlArranger(
                  layout: _layout,
                  available: Rect.fromLTRB(
                    safe.left,
                    safe.top,
                    box.maxWidth - safe.right,
                    box.maxHeight - safe.bottom,
                  ),
                  onChanged: _change,
                  onDone: () => setState(() => _arranging = false),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return MenuPage(
      title: 'CONTROLS',
      maxWidth: 700,
      body: MenuScrollBody(
        child: ControlsEditor(
          showTitle: false,
          layout: _layout,
          onChanged: _change,
          onDone: () => Navigator.of(context).pop(),
          onArrange: () => setState(() => _arranging = true),
        ),
      ),
    );
  }
}
