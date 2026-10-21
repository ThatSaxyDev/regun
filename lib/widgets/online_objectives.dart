import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/utils/constants.dart';

class OnlineObjectives extends StatelessWidget {
  const OnlineObjectives({super.key, required this.session});
  final OnlineSession session;
  @override
  Widget build(BuildContext context) {
    final me = session.me;
    if (me == null || session.room?.mode != 'coop') return const SizedBox();
    final pod = session.scene.where((e) => e.kind == 'supply').firstOrNull;
    final alone = session.members.where((m) => !m.expired).length == 1;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 105, right: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (alone)
                  const Text(
                    'Solo finish | Teammate window ended',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: FontFam.orbitron,
                      fontSize: 11,
                      color: Color(0xffD9AD70),
                    ),
                  ),
                if (pod != null) ...[
                  const Text(
                    'AIR​DROP',
                    style: TextStyle(
                      fontFamily: FontFam.orbitron,
                      color: Color(0xffE0BD74),
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: math.atan2(pod.y - me.y, pod.x - me.x),
                        child: const Icon(
                          Icons.arrow_right_alt,
                          color: Color(0xffE0BD74),
                          size: 24,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          pod.data['phase'] == 'active'
                              ? 'Hold zone ${pod.number('capture').toStringAsFixed(1)}/8s | ${(45 - pod.number('life')).ceil()}s'
                              : pod.data['phase'] == 'opened'
                              ? 'Secured'
                              : pod.data['phase'] == 'breaking'
                              ? 'Leaving'
                              : 'Incoming',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: FontFam.orbitron,
                            color: Color(0xffE5DDD1),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
