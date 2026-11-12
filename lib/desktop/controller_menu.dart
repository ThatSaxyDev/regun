import 'package:flutter/widgets.dart';

class ControllerMenuMode extends InheritedNotifier<ValueNotifier<bool>> {
  const ControllerMenuMode({
    super.key,
    required ValueNotifier<bool> active,
    required super.child,
  }) : super(notifier: active);

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ControllerMenuMode>()
          ?.notifier
          ?.value ??
      false;
}

class ControllerBackIntent extends Intent {
  const ControllerBackIntent();
}

class ControllerResumeIntent extends Intent {
  const ControllerResumeIntent();
}

class ControllerAdjustIntent extends Intent {
  const ControllerAdjustIntent(this.step);
  final int step;
}

/// Focus and Back ownership for in-route panels such as Pause and the picker.
class ControllerMenuScope extends StatefulWidget {
  const ControllerMenuScope({
    super.key,
    this.onBack,
    this.onResume,
    required this.child,
  });

  final VoidCallback? onBack, onResume;
  final Widget child;

  @override
  State<ControllerMenuScope> createState() => _ControllerMenuScopeState();
}

class _ControllerMenuScopeState extends State<ControllerMenuScope> {
  final _scope = FocusScopeNode(debugLabel: 'Regun menu panel');
  bool _controller = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ControllerMenuMode.of(context);
    if (controller && !_controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _controller &&
            ModalRoute.of(context)?.isCurrent == true &&
            !_scope.hasFocus) {
          _scope.requestFocus();
        }
      });
    }
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      ControllerBackIntent: CallbackAction<ControllerBackIntent>(
        onInvoke: (_) {
          widget.onBack?.call();
          return widget.onBack != null;
        },
      ),
      if (widget.onResume != null)
        ControllerResumeIntent: CallbackAction<ControllerResumeIntent>(
          onInvoke: (_) {
            widget.onResume!();
            return true;
          },
        ),
    },
    child: FocusScope(node: _scope, child: widget.child),
  );

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }
}
