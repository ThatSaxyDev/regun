import 'package:flutter/material.dart';

import 'package:regun/desktop/desktop_platform.dart';
import 'package:regun/services/push/push_service.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/game_notice.dart';

/// One-time notification offer shown on Home while permission is still
/// undecided. It occupies the leaderboards slot so the menu does not grow, and
/// the OS sheet is only raised from the Enable tap. Either answer retires it.
class PushPrompt extends StatefulWidget {
  const PushPrompt({super.key, required this.onSettled});
  final VoidCallback onSettled;

  @override
  State<PushPrompt> createState() => _PushPromptState();
}

class _PushPromptState extends State<PushPrompt> {
  bool _busy = false;

  Future<void> _answer(Future<void> Function() record) async {
    if (_busy) return;
    setState(() => _busy = true);
    await record();
    await PushService.shared.markPrompted();
    if (mounted) widget.onSettled();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = desktopInputAvailable;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Semantics(
      container: true,
      label: 'Enable notifications',
      child: CustomPaint(
        painter: const GameNoticeFrame(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, desktop ? 7 : 8, 12, desktop ? 7 : 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STAY IN THE LOOP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        inherit: false,
                        decoration: TextDecoration.none,
                        fontFamily: FontFam.pressStart,
                        fontSize: scale > 1.3 ? 7 : 8,
                        height: 1.5,
                        letterSpacing: .4,
                        color: const Color(0xffE1BA78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wide
                          ? 'Rewards, drops and account alerts.'
                          : 'Reward and account alerts.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        inherit: false,
                        decoration: TextDecoration.none,
                        fontFamily: FontFam.orbitron,
                        fontSize: scale > 1.2 ? 10 : 11,
                        height: 1.35,
                        color: const Color(0xffDED4C5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PromptAction(
                label: _busy ? '…' : 'ENABLE',
                primary: true,
                onTap: _busy
                    ? null
                    : () => _answer(PushService.shared.requestPermission),
              ),
              const SizedBox(width: 6),
              _PromptAction(
                label: 'LATER',
                onTap: _busy ? null : () => _answer(() async {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptAction extends StatelessWidget {
  const _PromptAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: desktopInputAvailable ? 28 : 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: primary ? const Color(0xffD9AC68) : const Color(0xff2A222E),
            border: Border.all(
              color: primary
                  ? const Color(0xffF0D8A8)
                  : const Color(0xff51454C),
              width: 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              inherit: false,
              decoration: TextDecoration.none,
              fontFamily: FontFam.pressStart,
              fontSize: 8,
              height: 1.3,
              letterSpacing: .4,
              color: primary
                  ? const Color(0xff2A2118)
                  : const Color(0xffd4c9b7),
            ),
          ),
        ),
      ),
    ),
  );
}
