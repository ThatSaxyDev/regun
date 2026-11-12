import 'package:regun/desktop/controller_menu.dart';
import 'package:regun/widgets/game_notice.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/services/availability_focus.dart';
import 'package:regun/services/push/push_service.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// Lives on the home route: never interrupts a live run or an upgrade choice.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.onBusyChanged,
    this.onBlockingChanged,
  });
  final Widget child;
  final ValueChanged<bool>? onBusyChanged, onBlockingChanged;
  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  VersionCheckResult? _prompt;
  bool _checking = false, _opening = false, _webConfirmed = false;
  bool _requestRunning = false, _homeCurrent = false, _foreground = true;
  bool _announcementPending = false, _cacheRestored = false;
  String? _error, _maintenance;
  Timer? _poll;
  late final AppUpdates _service;
  void Function()? _stopWatchingFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = _service = ref.read(appUpdatesProvider);
    _checking = service.enabled;
    PushService.shared.router.availabilityRefresh.addListener(_announcement);
    if (!service.enabled) {
      _cacheRestored = true;
      return;
    }
    _stopWatchingFocus = watchAvailabilityFocus(_checkAtHome);
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _checkAtHome());
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndCheck());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isHome = ModalRoute.isCurrentOf(context) ?? true;
    if (isHome && !_homeCurrent && !_checking) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAtHome());
    }
    _homeCurrent = isHome;
  }

  Future<void> _restoreAndCheck() async {
    if (!mounted) return;
    String? cached;
    try {
      cached = await ref.read(appUpdatesProvider).cachedMaintenance();
    } catch (_) {
      // A failed cache read leaves the fresh network check available.
    }
    if (!mounted) return;
    setState(() {
      _cacheRestored = true;
      _maintenance = cached;
    });
    widget.onBlockingChanged?.call(_blocking);
    _checkAtHome();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _service.cancelCheck();
    _stopWatchingFocus?.call();
    PushService.shared.router.availabilityRefresh.removeListener(_announcement);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _checkAtHome();
  }

  void _announcement() {
    _announcementPending = true;
    _checkAtHome();
  }

  void _checkAtHome() {
    if (mounted && _foreground && _homeCurrent && _cacheRestored) {
      unawaited(_check());
    }
  }

  bool get _blocking =>
      _maintenance != null ||
      _prompt != null ||
      (ref.read(appUpdatesProvider).web && !_webConfirmed);

  Future<void> _check() async {
    if (!mounted || !_homeCurrent || !_cacheRestored) return;
    final service = ref.read(appUpdatesProvider);
    if (!service.enabled || _requestRunning) return;
    _requestRunning = true;
    if (_announcementPending) {
      _announcementPending = false;
      service.reviewAnnouncement();
    }
    widget.onBusyChanged?.call(true);
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await service.check();
      if (!mounted) return;
      setState(() {
        _webConfirmed = true;
        _maintenance = result.maintenance;
        _prompt = result.requiresUpdate ? result : null;
      });
    } catch (_) {
      if (mounted && _blocking) {
        setState(() {
          _error = _maintenance != null
              ? 'Regun will keep checking for you.'
              : 'Regun will refresh when it can connect.';
        });
      }
    } finally {
      _requestRunning = false;
      if (mounted) {
        setState(() => _checking = false);
        widget.onBusyChanged?.call(_blocking);
        widget.onBlockingChanged?.call(_blocking);
        if (_announcementPending) _checkAtHome();
      }
    }
  }

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
      widget.onBlockingChanged?.call(_blocking);
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
    canPop: !_blocking && _cacheRestored,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _blocking || !_cacheRestored,
          child: ExcludeSemantics(
            excluding: _blocking || !_cacheRestored,
            child: IgnorePointer(
              ignoring: _blocking || !_cacheRestored,
              child: widget.child,
            ),
          ),
        ),
        if (!_blocking && _checking)
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
        if (_blocking) ...[
          const ModalBarrier(dismissible: false, color: Color(0xD9100D14)),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Center(
              child: ControllerMenuScope(
                onBack: _maintenance == null && _prompt?.isRequired == false
                    ? _later
                    : null,
                child:
                    _maintenance != null ||
                        (ref.read(appUpdatesProvider).web && !_webConfirmed)
                    ? _availabilityNotice()
                    : UpdateNotice(
                        result: _prompt!,
                        storeAvailable:
                            ref
                                .read(appUpdatesProvider)
                                .storeUri(_prompt!.storeUrl) !=
                            null,
                        checking: _checking,
                        opening: _opening,
                        error: _error,
                        onLater: _later,
                        onUpdate: _update,
                      ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _availabilityNotice() {
    final maintenance = _maintenance;
    return GameNotice(
      eyebrow: 'RE-GUN / AVAILABILITY',
      title: maintenance != null
          ? 'Maintenance in progress'
          : _checking
          ? 'Checking game availability'
          : 'Can’t check game availability',
      message:
          maintenance ??
          (_checking
              ? 'Checking whether Regun is available.'
              : 'Regun couldn’t check availability. Please try again shortly.'),
      detail: maintenance != null && _error != null
          ? Semantics(liveRegion: true, child: Text(_error!))
          : null,
      actions: maintenance == null && !_checking
          ? ClickButton(
              text: 'Try again',
              glyph: PixelGlyph.reload,
              height: 48,
              onTap: _check,
            )
          : null,
    );
  }
}

class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    super.key,
    required this.result,
    required this.onUpdate,
    required this.onLater,
    this.checking = false,
    this.opening = false,
    this.storeAvailable = true,
    this.error,
  });
  final VersionCheckResult result;
  final VoidCallback onUpdate, onLater;
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
              error ?? 'The update link isn’t ready yet. Regun will refresh automatically.',
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
      secondary: result.isRequired
          ? null
          : ClickButton(
              text: 'Later',
              buttonColor: const Color(0xffA79AA9),
              height: 48,
              onTap: checking || opening ? null : onLater,
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
