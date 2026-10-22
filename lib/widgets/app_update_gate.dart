import 'package:regun/widgets/game_notice.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// Lives on the home route: never interrupts a live run or an upgrade choice.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.onBusyChanged});
  final Widget child;
  final ValueChanged<bool>? onBusyChanged;
  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  VersionCheckResult? _prompt;
  bool _checking = false, _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checking = ref.read(appUpdatesProvider).enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;
    final service = ref.read(appUpdatesProvider);
    if (!service.enabled || _requestRunning) return;
    _requestRunning = true;
    widget.onBusyChanged?.call(true);
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await service.check();
      if (!mounted) return;
      setState(() => _prompt = result.requiresUpdate ? result : null);
    } catch (_) {
      // Offline first launch still plays. A known required update remains visible
      // until a successful response explicitly lifts it or the app is updated.
      if (mounted && _prompt != null) {
        setState(
          () => _error = 'Couldn’t check. Try again when you’re online.',
        );
      }
    } finally {
      _requestRunning = false;
      if (mounted) {
        setState(() => _checking = false);
        widget.onBusyChanged?.call(_prompt != null);
      }
    }
  }

  bool _requestRunning = false;

  Future<void> _later() async {
    final prompt = _prompt;
    if (prompt == null || prompt.isRequired) return;
    try {
      await ref.read(appUpdatesProvider).later(prompt);
    } catch (_) {
      /* Next launch can ask again. */
    }
    if (mounted && identical(_prompt, prompt)) {
      setState(() => _prompt = null);
      widget.onBusyChanged?.call(false);
    }
  }

  Future<void> _update() async {
    if (_prompt == null || _opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    final opened = await ref.read(appUpdatesProvider).openStore(_prompt!);
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) _error = 'Couldn’t open the store. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _prompt == null,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _prompt != null,
          child: ExcludeSemantics(
            excluding: _prompt != null,
            child: IgnorePointer(
              ignoring: _prompt != null,
              child: widget.child,
            ),
          ),
        ),
        if (_prompt == null && _checking)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: IgnorePointer(
              child: SafeArea(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    'Checking for updates…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      decoration: TextDecoration.none,
                      height: 1.3,
                      fontFamily: FontFam.orbitron,
                      fontSize: 10,
                      color: Color(0xffB8A78F),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_prompt != null) ...[
          const ModalBarrier(dismissible: false, color: Color(0xD9100D14)),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Center(
              child: UpdateNotice(
                result: _prompt!,
                storeAvailable:
                    ref.read(appUpdatesProvider).storeUri(_prompt!.storeUrl) !=
                    null,
                checking: _checking,
                opening: _opening,
                error: _error,
                onLater: _later,
                onUpdate: _update,
                onRetry: _check,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    super.key,
    required this.result,
    required this.onUpdate,
    required this.onLater,
    required this.onRetry,
    this.checking = false,
    this.opening = false,
    this.storeAvailable = true,
    this.error,
  });
  final VersionCheckResult result;
  final VoidCallback onUpdate, onLater, onRetry;
  final bool checking, opening, storeAvailable;
  final String? error;
  @override
  Widget build(BuildContext context) => GameNotice(
    eyebrow: 'RE-GUN / LATEST RELEASE',
    title: result.isRequired ? 'UPDATE REQUIRED' : 'NEW UPDATE',
    message: _message,
    detail: error != null || !storeAvailable
        ? Semantics(
            liveRegion: true,
            child: Text(
              error ?? 'The update link isn’t ready yet. Please check again shortly.',
              style: const TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                height: 1.5,
                color: Color(0xffE1BA78),
              ),
            ),
          )
        : null,
    actions: GameNoticeActions(
      primaryFirstWhenStacked: true,
      primary: ClickButton(
        text: opening ? 'Opening…' : 'Update',
        glyph: PixelGlyph.reload,
        height: 48,
        onTap: opening || !storeAvailable ? null : onUpdate,
      ),
      secondary: ClickButton(
        text: result.isRequired
            ? (checking ? 'Checking…' : 'Check again')
            : 'Later',
        buttonColor: const Color(0xffA79AA9),
        height: 48,
        onTap: checking || opening
            ? null
            : result.isRequired
            ? onRetry
            : onLater,
      ),
    ),
  );

  String get _message {
    final custom = result.message?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    return result.isRequired
        ? 'Update Regun to keep playing.'
        : 'The latest Regun is ready. Get the new improvements.';
  }
}
