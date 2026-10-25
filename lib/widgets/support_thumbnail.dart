import 'package:flutter/material.dart';
import 'package:regun/systems/support_rewards.dart';

class SupportThumbnail extends StatelessWidget {
  const SupportThumbnail({
    super.key,
    required this.card,
    this.width = 64,
    this.height = 48,
  });
  final SupportCard card;
  final double width, height;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${card.title} ${card.family == SupportFamily.sentry ? card.mount : ''}',
    child: Image.asset(
      'assets/art/support/${card.family == SupportFamily.aura ? 'aura' : 'card_${card.mount}'}.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    ),
  );
}
