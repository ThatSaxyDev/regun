import 'package:flutter/material.dart';
import 'package:regun/utils/constants.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: FontFam.pressStart,
          fontSize: 10,
          height: 1.6,
          color: Color(0xffE1BA78),
        ),
      ),
      const SizedBox(height: 12),
      const Divider(height: 1, color: Color(0xff403644)),
      const SizedBox(height: 16),
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        children[i],
      ],
    ],
  );
}
