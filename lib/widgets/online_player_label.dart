import 'package:flutter/material.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/multiplayer/generated/member.dart';
import 'package:regun/utils/constants.dart';

class OnlinePlayerLabel extends StatelessWidget {
  const OnlinePlayerLabel({
    super.key,
    required this.member,
    required this.online,
    this.suffix = '',
    this.compact = false,
    this.age,
  });
  final Member member;
  final bool online;
  final String suffix;
  final bool compact;
  final Duration? age;
  @override
  Widget build(BuildContext context) {
    final label = pingLabel(member, DateTime.now(), online: online, age: age);
    final color = label.contains('Good')
        ? const Color(0xffA9C990)
        : label.contains('Fair')
        ? const Color(0xffE0BD74)
        : label.contains('Poor')
        ? const Color(0xffED9E8C)
        : const Color(0xffB5ADA5);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${member.name}$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 12,
              color: Color(0xffE5DDD1),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      );
    }
    return Text(
      '${member.name}$suffix | $label',
      style: TextStyle(
        fontFamily: FontFam.orbitron,
        fontSize: 13,
        color: color,
      ),
    );
  }
}
